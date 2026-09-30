@tool
class_name AnthropicChatStream
extends Node

## Anthropic Messages API 流式聊天客户端（SSE）

@export var api_base: String = "https://api.anthropic.com"
@export var secret_key: String = ""
@export var model_name: String = "claude-sonnet-4-6"
@export var use_thinking: bool = false
@export var max_tokens: int = 8192
@export var tools: Array = []
@export var print_log: bool = false

signal generate_finish(finish_reason: String, total_tokens: float)
signal message(msg: String)
signal think(think_msg: String)
signal use_tool(tool_calls: Array[AgentModelUtils.ToolCallsInfo])
signal response_use_tool
signal error(error_info: Dictionary)

var client := HTTPClient.new()
var generatting: bool = false
var buffer: PackedByteArray = PackedByteArray()
var sse_buffer: String = ""
var chunks: Array[Dictionary] = []
var tool_calls: Array[AgentModelUtils.ToolCallsInfo] = []

var _tool_call_map: Dictionary = {}
var _tool_call_order: Array[int] = []
var _tool_has_full_input: Dictionary = {}
var _stop_reason: String = ""
var _input_tokens: int = 0
var _output_tokens: int = 0
var _finished: bool = false
var _request_start_time: float = 0.0
var _response_code_checked: bool = false

func post_message(messages: Array[Dictionary]):
	close()
	_reset_state()

	var url := _build_messages_url()
	var parsed := _parse_url_for_http_client(url)
	var host: String = parsed.get("host", "")
	var port: int = int(parsed.get("port", 443))
	var use_tls: bool = bool(parsed.get("use_tls", true))
	var path: String = parsed.get("path", "/v1/messages")

	if host.is_empty():
		_emit_error("Anthropic API地址无效", {"api_base": api_base}, "request", false)
		return

	var request_data := _build_request_data(messages)
	var request_body := JSON.stringify(request_data)
	if print_log:
		print("Anthropic 流式请求: ", request_body)

	AgentModelUtils.apply_proxy_to_http_client(client)
	var err := client.connect_to_host(host, port, TLSOptions.client() if use_tls else null)
	if err != OK:
		_emit_error("Anthropic 连接失败", {"error": err}, "network", true)
		return

	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		await get_tree().process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		_emit_error("Anthropic 连接失败", {"status": client.get_status()}, "network", true)
		return

	var headers := PackedStringArray([
		"Accept: text/event-stream",
		"Content-Type: application/json",
		"x-api-key: %s" % secret_key,
		"anthropic-version: 2023-06-01"
	])
	err = client.request(HTTPClient.METHOD_POST, path, headers, request_body)
	if err != OK:
		_emit_error("Anthropic 请求发送失败", {"error": err}, "network", true)
		return

	generatting = true
	_request_start_time = Time.get_ticks_msec()

func _process(_delta):
	if not generatting:
		return

	client.poll()
	var status := client.get_status()

	if status == HTTPClient.STATUS_BODY:
		if not _response_code_checked:
			_response_code_checked = true
			var code := client.get_response_code()
			if code != 200:
				var error_body := PackedByteArray()
				while client.get_status() == HTTPClient.STATUS_BODY:
					client.poll()
					var error_chunk = client.read_response_body_chunk()
					if error_chunk.size() > 0:
						error_body.append_array(error_chunk)
					await get_tree().process_frame
				generatting = false
				_finished = true
				error.emit(AgentModelUtils.map_http_error(code, error_body.get_string_from_utf8()))
				return
		var chunk = client.read_response_body_chunk()
		if chunk.size() > 0:
			buffer += chunk
			_process_buffer()
	elif status == HTTPClient.STATUS_DISCONNECTED:
		if not _finished:
			_finalize()
	elif status == HTTPClient.STATUS_CONNECTED:
		pass
	elif status == HTTPClient.STATUS_REQUESTING:
		pass
	elif status == HTTPClient.STATUS_RESOLVING or status == HTTPClient.STATUS_CONNECTING:
		pass
	else:
		# 检查超时：超过30秒没有收到数据
		var elapsed := Time.get_ticks_msec() - _request_start_time
		if elapsed > 30000 and not _finished:
			_finalize()

func _process_buffer():
	var new_text := buffer.get_string_from_utf8()
	buffer = PackedByteArray()
	if new_text.is_empty():
		return

	sse_buffer += new_text
	var sep := "\n\n"
	var idx := sse_buffer.find(sep)
	while idx != -1:
		var event_block := sse_buffer.substr(0, idx)
		sse_buffer = sse_buffer.substr(idx + sep.length())
		_process_sse_event_block(event_block)
		idx = sse_buffer.find(sep)

func _process_sse_event_block(event_block: String):
	if event_block.is_empty():
		return

	if print_log:
		print("Anthropic SSE Block: ", event_block)

	var event_name := ""
	var data_lines: Array[String] = []
	for line in event_block.split("\n"):
		if line.begins_with("event:"):
			event_name = line.substr(6).strip_edges()
		elif line.begins_with("data:"):
			data_lines.append(line.substr(5).strip_edges())

	if data_lines.is_empty():
		return

	var data_text := "\n".join(data_lines).strip_edges()
	if data_text == "[DONE]":
		_finalize()
		return

	var parsed = _parse_json_safely(data_text)
	if not (parsed is Dictionary):
		return

	var data: Dictionary = parsed
	chunks.append(data)
	_process_chunk(event_name, data)

func _process_chunk(event_name: String, data: Dictionary):
	var data_type := str(data.get("type", ""))
	var event_type := data_type if not data_type.is_empty() else event_name

	if print_log:
		print("Anthropic Chunk: type=", event_type, " data=", JSON.stringify(data))

	match event_type:
		"message_start":
			_update_usage(data.get("message", {}).get("usage", {}))
		"content_block_start":
			_on_content_block_start(data)
		"content_block_delta":
			_on_content_block_delta(data)
		"content_block_stop":
			pass
		"message_delta":
			_on_message_delta(data)
		"message_stop":
			_finalize()
		"error":
			_emit_error("Anthropic 流式错误", data.get("error", data), "server", true)
		_:
			pass

func _on_content_block_start(data: Dictionary):
	var idx := int(data.get("index", -1))
	var block = data.get("content_block", {})
	if not (block is Dictionary):
		return

	var block_type := str(block.get("type", ""))
	if block_type == "tool_use":
		var info := AgentModelUtils.ToolCallsInfo.new()
		info.id = str(block.get("id", ""))
		info.type = "function"
		info.function.name = str(block.get("name", ""))
		info.function.arguments = ""
		_tool_has_full_input[idx] = false

		# 检查 input 是否为非空字典（有些兼容网关会返回 input:{} 空对象）
		var input_val = block.get("input")
		if input_val is Dictionary and not input_val.is_empty():
			info.function.arguments = JSON.stringify(input_val)
			_tool_has_full_input[idx] = true

		_tool_call_map[idx] = info
		if not _tool_call_order.has(idx):
			_tool_call_order.append(idx)
		response_use_tool.emit()

func _on_content_block_delta(data: Dictionary):
	var idx := int(data.get("index", -1))
	var delta = data.get("delta", {})
	if not (delta is Dictionary):
		return

	var delta_type := str(delta.get("type", ""))
	match delta_type:
		"text_delta":
			message.emit(str(delta.get("text", "")))
		"thinking_delta":
			think.emit(str(delta.get("thinking", "")))
		"input_json_delta":
			if _tool_call_map.has(idx):
				var info: AgentModelUtils.ToolCallsInfo = _tool_call_map[idx]
				var partial := str(delta.get("partial_json", ""))
				if not partial.is_empty():
					var has_full := bool(_tool_has_full_input.get(idx, false))
					if has_full:
						var merged := info.function.arguments + partial
						var merged_parsed = _parse_json_safely(merged)
						if merged_parsed is Dictionary:
							info.function.arguments = merged
						else:
							# 某些 Anthropic 兼容网关会同时下发完整 input 和 delta，
							# 这里忽略无法合并的 delta，避免产生无效 JSON。
							pass
					else:
						info.function.arguments += partial
				_tool_call_map[idx] = info
		_:
			pass

func _on_message_delta(data: Dictionary):
	var delta = data.get("delta", {})
	if delta is Dictionary:
		var reason := str(delta.get("stop_reason", ""))
		if not reason.is_empty():
			_stop_reason = reason
	_update_usage(data.get("usage", {}))

func _update_usage(usage):
	if usage is Dictionary:
		if usage.has("input_tokens"):
			_input_tokens = int(usage.get("input_tokens", _input_tokens))
		if usage.has("output_tokens"):
			_output_tokens = int(usage.get("output_tokens", _output_tokens))

func _finalize():
	if _finished:
		return
	_finished = true
	generatting = false

	_build_tool_calls()
	if print_log:
		print("Anthropic Final tool_calls: ", JSON.stringify(tool_calls.map(func(t): return t.to_dict())))

	if not tool_calls.is_empty():
		use_tool.emit(tool_calls)
		if _stop_reason.is_empty():
			_stop_reason = "tool_calls"

	var finish_reason := _normalize_finish_reason(_stop_reason)
	generate_finish.emit(finish_reason, float(_input_tokens + _output_tokens))

func _build_tool_calls():
	tool_calls = []
	if print_log:
		print("Anthropic _build_tool_calls: _tool_call_map=", JSON.stringify(_tool_call_map))
	for idx in _tool_call_order:
		if not _tool_call_map.has(idx):
			continue
		var info: AgentModelUtils.ToolCallsInfo = _tool_call_map[idx]
		if info.function.arguments.is_empty():
			info.function.arguments = "{}"
		elif not (_parse_json_safely(info.function.arguments) is Dictionary):
			info.function.arguments = _extract_first_json_object_or_default(info.function.arguments)
		tool_calls.append(info)

func _normalize_finish_reason(reason: String) -> String:
	var value := reason.strip_edges().to_lower()
	if value == "tool_use":
		return "tool_calls"
	if value.is_empty():
		return "stop"
	return value

func _emit_error(error_msg: String, data, error_type: String = "server", retryable: bool = false, error_code: int = 0):
	generatting = false
	_finished = true
	error.emit({
		"error_msg": error_msg,
		"error_code": error_code,
		"error_type": error_type,
		"data": data,
		"retryable": retryable
	})

func _parse_url_for_http_client(url: String) -> Dictionary:
	var clean := url.strip_edges()
	var use_tls := clean.begins_with("https://")
	clean = clean.replace("https://", "").replace("http://", "")

	var parts := clean.split("/", false, 1)
	var host_port := parts[0] if parts.size() > 0 else ""
	var path := "/" + (parts[1] if parts.size() > 1 else "")
	if path == "/":
		path = "/v1/messages"

	var host := host_port
	var port := 443 if use_tls else 80
	var colon_idx := host_port.find(":")
	if colon_idx != -1:
		host = host_port.substr(0, colon_idx)
		var port_text := host_port.substr(colon_idx + 1)
		if port_text.is_valid_int():
			port = int(port_text)

	return {
		"host": host,
		"port": port,
		"use_tls": use_tls,
		"path": path
	}

func _extract_first_json_object_or_default(text: String) -> String:
	var src := text.strip_edges()
	if src.is_empty():
		return "{}"

	var start := src.find("{")
	if start == -1:
		return "{}"

	var depth := 0
	var in_string := false
	var escaped := false
	for i in range(start, src.length()):
		var ch := src[i]
		if escaped:
			escaped = false
			continue
		if ch == "\\":
			escaped = true
			continue
		if ch == "\"":
			in_string = not in_string
			continue
		if in_string:
			continue
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				var candidate := src.substr(start, i - start + 1)
				if _parse_json_safely(candidate) is Dictionary:
					return candidate
				return "{}"

	return "{}"

func _build_messages_url() -> String:
	var base := api_base.strip_edges()
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	if base.ends_with("/v1/messages"):
		return base
	if base.ends_with("/v1"):
		return base + "/messages"
	return base + "/v1/messages"

func _build_request_data(messages: Array[Dictionary]) -> Dictionary:
	var system_text := _extract_system_text(messages)
	var anthropic_messages := _convert_messages(messages)
	var payload := {
		"model": model_name,
		"max_tokens": max_tokens,
		"messages": anthropic_messages,
		"stream": true
	}

	if not system_text.is_empty():
		payload["system"] = system_text

	if use_thinking and max_tokens > 1024:
		var budget := int(max(1024, max_tokens / 2))
		if budget >= max_tokens:
			budget = max_tokens - 1
		payload["thinking"] = {
			"type": "enabled",
			"budget_tokens": budget
		}

	var anthropic_tools := _convert_tools_for_anthropic(tools)
	if not anthropic_tools.is_empty():
		payload["tools"] = anthropic_tools
		payload["tool_choice"] = {"type": "auto"}

	return payload

func _extract_system_text(messages: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for msg in messages:
		if str(msg.get("role", "")) == "system":
			var text := str(msg.get("content", ""))
			if not text.is_empty():
				parts.append(text)
	return "\n".join(parts)

func _convert_messages(messages: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	for msg in messages:
		var role := str(msg.get("role", ""))
		match role:
			"system":
				continue
			"user":
				out.append({
					"role": "user",
					"content": str(msg.get("content", ""))
				})
			"assistant":
				var blocks: Array = []

				# 添加 thinking block（thinking 模式下 API 要求传回）
				if msg.has("reasoning_content"):
					var reasoning := str(msg.get("reasoning_content", ""))
					if not reasoning.is_empty() and reasoning != "null" and reasoning != "<null>":
						blocks.append({
							"type": "thinking",
							"thinking": reasoning
						})

				# 检查 content 是否为 null 或 "null" 字符串
				var raw_content = msg.get("content")
				if raw_content != null and raw_content != "null" and raw_content != "<null>":
					var text_content := str(raw_content)
					if not text_content.is_empty() and text_content != "null" and text_content != "<null>":
						blocks.append({
							"type": "text",
							"text": text_content
						})

				if msg.has("tool_calls") and msg["tool_calls"] is Array:
					for item in msg["tool_calls"]:
						if not (item is Dictionary):
							continue
						var fn = item.get("function", {})
						if not (fn is Dictionary):
							continue
						var fn_name := str(fn.get("name", ""))
						if fn_name.is_empty():
							continue
						blocks.append({
							"type": "tool_use",
							"id": str(item.get("id", "")),
							"name": fn_name,
							"input": _parse_tool_arguments(str(fn.get("arguments", "")))
						})

				# 确保 assistant 消息至少包含一个 text block
				# 某些兼容网关（如 DeepSeek）要求必须有 text block，即使内容为空
				var has_text_block := false
				for block in blocks:
					if str(block.get("type", "")) == "text":
						has_text_block = true
						break
				if not has_text_block:
					# 找到 thinking block 之后的位置插入（保持 thinking → text → tool_use 顺序）
					var insert_pos := 0
					for bi in range(blocks.size()):
						if str(blocks[bi].get("type", "")) == "thinking":
							insert_pos = bi + 1
					blocks.insert(insert_pos, {
						"type": "text",
						"text": ""
					})

				out.append({
					"role": "assistant",
					"content": blocks
				})
			"tool":
				out.append({
					"role": "user",
					"content": [
						{
							"type": "tool_result",
							"tool_use_id": str(msg.get("tool_call_id", "")),
							"content": str(msg.get("content", ""))
						}
					]
				})
			_:
				if msg.has("content"):
					out.append({
						"role": "user",
						"content": str(msg.get("content", ""))
					})

	return out

func _parse_tool_arguments(args_text: String) -> Dictionary:
	if args_text.is_empty():
		return {}
	var parsed = _parse_json_safely(args_text)
	if parsed is Dictionary:
		return parsed
	return {}

func _parse_json_safely(text: String):
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.get_data()

func _convert_tools_for_anthropic(openai_tools: Array) -> Array:
	var out: Array = []
	for item in openai_tools:
		if not (item is Dictionary):
			continue
		var fn = item.get("function", {})
		if not (fn is Dictionary):
			continue
		var name := str(fn.get("name", ""))
		if name.is_empty():
			continue
		var input_schema = fn.get("parameters", {"type": "object", "properties": {}})
		out.append({
			"name": name,
			"description": str(fn.get("description", "")),
			"input_schema": input_schema
		})
	return out

func _reset_state():
	buffer = PackedByteArray()
	sse_buffer = ""
	chunks = []
	tool_calls = []
	_tool_call_map = {}
	_tool_call_order = []
	_tool_has_full_input = {}
	_stop_reason = ""
	_input_tokens = 0
	_output_tokens = 0
	_finished = false
	_request_start_time = 0.0
	_response_code_checked = false

func close():
	generatting = false
	buffer = PackedByteArray()
	sse_buffer = ""
	_finished = true
	if client:
		client.close()

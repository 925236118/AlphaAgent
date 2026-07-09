@tool
class_name GeminiChatStream
extends Node

## Gemini 流式聊天客户端（streamGenerateContent）

## API基础URL
@export var api_base: String = "https://generativelanguage.googleapis.com/v1beta"
## API密钥
@export var secret_key: String = ""
## 模型名称
@export var model_name: String = "gemini-3-flash-preview"
## 是否使用深度思考（Gemini thinking 模型）
@export var use_thinking: bool = false
## 温度值，越高输出越随机，默认为1
@export_range(0.0, 2.0, 0.1) var temperature: float = 1.0
## 最大输出长度
@export var max_tokens: int = 4096
## 是否输出调试日志
@export var print_log: bool = false
## 可供模型调用的工具（OpenAI function schema，将转换为 Gemini functionDeclarations）
@export var tools: Array = []

## 返回正文
signal message(msg: String)
## 返回思考内容
signal think(msg: String)
## 返回结束
signal generate_finish(finish_reason: String, total_tokens: float)
## 使用工具
signal use_tool(tool_calls: Array[AgentModelUtils.ToolCallsInfo])
## 正在返回使用工具请求
signal response_use_tool
## 失败
signal error(error_info: Dictionary)

## 发送请求的http客户端
@onready var http_client: HTTPClient = HTTPClient.new()

var generatting: bool = false
var tool_calls: Array[AgentModelUtils.ToolCallsInfo] = []

## 发送请求
func post_message(messages: Array[Dictionary]):
	tool_calls = []
	AgentModelUtils.apply_proxy_to_http_client(http_client)
	if print_log: print("Gemini 请求消息列表: ", messages)

	var headers = [
		"Accept: text/event-stream",
		"x-goog-api-key: %s" % secret_key,
		"Content-Type: application/json"
	]

	var request_data = _build_request_data(messages)
	var request_body = JSON.stringify(request_data)

	if print_log: print("Gemini 请求消息数据体: ", request_body)

	var parsed = _parse_api_base(api_base)
	var host = parsed["host"]
	var use_tls = parsed["use_tls"]
	var base_path = parsed["base_path"]
	var path = _build_stream_path(base_path)

	if print_log:
		print("Gemini 请求主机: ", host)
		print("Gemini 请求路径: ", path)
		print("Gemini 连接开始，初始状态: ", http_client.get_status())

	if host.is_empty():
		error.emit({
			"error_msg": "Gemini API地址无效",
			"data": api_base
		})
		return

	var connect_err = http_client.connect_to_host(host, 443 if use_tls else 80,
												  TLSOptions.client() if use_tls else null)
	if connect_err != OK:
		error.emit({
			"error_msg": "连接失败",
			"data": connect_err
		})
		return

	var connect_wait_frames := 0
	while http_client.get_status() == HTTPClient.STATUS_CONNECTING or \
		  http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		http_client.poll()
		connect_wait_frames += 1
		if print_log and connect_wait_frames % 120 == 0:
			print("Gemini 连接等待中... status=", http_client.get_status(), " elapsed_ms=", connect_wait_frames * 16)
		await get_tree().process_frame

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		error.emit({
			"error_msg": "连接失败",
			"data": {
				"status": http_client.get_status(),
				"status_name": _status_to_text(http_client.get_status())
			}
		})
		return

	if print_log:
		print("Gemini 连接成功，status=", http_client.get_status())

	if print_log:
		print("Gemini 请求模型: ", model_name)

	var err = http_client.request(HTTPClient.METHOD_POST, path, headers, request_body)
	if err != OK:
		error.emit({
			"error_msg": "请求失败",
			"data": err
		})
		return

	generatting = true
	if print_log:
		print("Gemini 请求已发送，等待响应头...")

	var request_wait_frames := 0
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		request_wait_frames += 1
		if print_log and request_wait_frames % 120 == 0:
			print("Gemini 等待响应头中... status=", http_client.get_status(), " elapsed_ms=", request_wait_frames * 16)
		await get_tree().process_frame

	if print_log:
		print("Gemini 收到响应头，status=", http_client.get_status(), " code=", http_client.get_response_code())

	if http_client.get_status() != HTTPClient.STATUS_BODY and \
	   http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		error.emit({
			"error_msg": "响应失败",
			"data": http_client.get_status()
		})
		generatting = false
		return

	if http_client.get_response_code() != 200:
		var body_chunks = PackedByteArray()
		while http_client.get_status() == HTTPClient.STATUS_BODY:
			http_client.poll()
			var err_chunk = http_client.read_response_body_chunk()
			if err_chunk.size() > 0:
				body_chunks.append_array(err_chunk)
			await get_tree().process_frame

		var error_body = body_chunks.get_string_from_utf8()
		error.emit({
			"error_msg": "HTTP错误: " + str(http_client.get_response_code()),
			"data": error_body
		})
		generatting = false
		return

	var buffer = PackedByteArray()
	var emitted_finish = false
	var body_frames_without_chunk := 0
	var total_chunk_count := 0

	while http_client.get_status() == HTTPClient.STATUS_BODY:
		http_client.poll()
		var chunk = http_client.read_response_body_chunk()
		if chunk.size() > 0:
			total_chunk_count += 1
			body_frames_without_chunk = 0
			if print_log:
				print("Gemini 收到流分片 #", total_chunk_count, " bytes=", chunk.size())
			buffer.append_array(chunk)
			emitted_finish = _process_buffer(buffer, emitted_finish)
		else:
			body_frames_without_chunk += 1
			if print_log and body_frames_without_chunk % 180 == 0:
				print("Gemini BODY阶段暂无新分片... status=", http_client.get_status(), " idle_ms=", body_frames_without_chunk * 16)
		await get_tree().process_frame

	if print_log:
		print("Gemini BODY循环结束。status=", http_client.get_status(), " emitted_finish=", emitted_finish, " tool_calls=", tool_calls.size())

	if not emitted_finish:
		if not tool_calls.is_empty():
			if print_log:
				print("Gemini 走兜底：触发 tool_calls 结束")
			response_use_tool.emit()
			use_tool.emit(tool_calls)
			generate_finish.emit("tool_calls", 0)
		else:
			if print_log:
				print("Gemini 走兜底：触发 stop 结束")
			generate_finish.emit("stop", 0)

	generatting = false

func _parse_api_base(url: String) -> Dictionary:
	var clean = url.strip_edges()
	var use_tls = clean.begins_with("https://")
	clean = clean.replace("https://", "").replace("http://", "")

	var parts = clean.split("/", false, 1)
	var host = parts[0] if parts.size() > 0 else ""
	var base_path = ""
	if parts.size() > 1 and parts[1] != "":
		base_path = "/" + parts[1]
		if base_path.ends_with("/"):
			base_path = base_path.substr(0, base_path.length() - 1)

	return {
		"host": host,
		"use_tls": use_tls,
		"base_path": base_path
	}

func _build_stream_path(base_path: String) -> String:
	var action = ":streamGenerateContent?alt=sse"
	if base_path.contains("/models/"):
		return base_path + action

	if base_path.ends_with("/v1beta"):
		return base_path + "/models/%s%s" % [model_name, action]

	if base_path.is_empty():
		return "/v1beta/models/%s%s" % [model_name, action]

	return base_path + "/v1beta/models/%s%s" % [model_name, action]

func _build_request_data(messages: Array[Dictionary]) -> Dictionary:
	var contents: Array = []
	var system_texts: Array[String] = []
	var tool_call_name_map: Dictionary = {}

	for msg in messages:
		var role = str(msg.get("role", ""))
		var content_val = msg.get("content", "")
		var text = "" if content_val == null else str(content_val)
		if text.is_empty() and role != "system":
			if not (role == "assistant" and msg.has("tool_calls")) and role != "tool":
				continue

		match role:
			"system":
				if not text.is_empty():
					system_texts.append(text)
			"user":
				contents.append({
					"role": "user",
					"parts": [{"text": text}]
				})
			"assistant":
				var model_parts: Array = []

				if msg.has("tool_calls") and msg["tool_calls"] is Array:
					var history_tool_calls: Array = msg["tool_calls"]
					for i in range(history_tool_calls.size()):
						var tool_call_data = history_tool_calls[i]
						if not (tool_call_data is Dictionary):
							continue

						var function_data = tool_call_data.get("function", {})
						if not (function_data is Dictionary):
							continue

						var fn_name = str(function_data.get("name", ""))
						if fn_name.is_empty():
							continue

						var args_text = str(function_data.get("arguments", "{}"))
						var args_data = JSON.parse_string(args_text)
						var fn_args: Dictionary = args_data if args_data is Dictionary else {
							"raw": args_text
						}

						var call_id = str(tool_call_data.get("id", ""))
						if call_id.is_empty():
							call_id = "gemini_tool_" + str(Time.get_unix_time_from_system()) + "_" + str(i)
						tool_call_name_map[call_id] = fn_name

						var function_call_part: Dictionary = {
							"name": fn_name,
							"args": fn_args
						}
						var thought_signature = str(tool_call_data.get("thought_signature", tool_call_data.get("thoughtSignature", "")))
						var model_part: Dictionary = {
							"functionCall": function_call_part
						}
						if not thought_signature.is_empty():
							model_part["thought_signature"] = thought_signature
						model_parts.append(model_part)

				if not text.is_empty():
					model_parts.append({"text": text})

				if not model_parts.is_empty():
					contents.append({
						"role": "model",
						"parts": model_parts
					})
			"tool":
				var tool_call_id = str(msg.get("tool_call_id", ""))
				var tool_name = str(tool_call_name_map.get(tool_call_id, "tool_result"))
				var tool_result = JSON.parse_string(text)
				if not (tool_result is Dictionary):
					tool_result = {"content": text}

				contents.append({
					"role": "user",
					"parts": [{
						"functionResponse": {
							"name": tool_name,
							"response": tool_result
						}
					}]
				})
			_:
				contents.append({
					"role": "user",
					"parts": [{"text": text}]
				})

	if contents.is_empty():
		contents.append({
			"role": "user",
			"parts": [{"text": ""}]
		})

	var payload: Dictionary = {
		"contents": contents,
		"generationConfig": {
			"temperature": temperature,
			"maxOutputTokens": max_tokens
		}
	}

	if use_thinking:
		payload["generationConfig"]["thinkingConfig"] = {
			"thinkingBudget": mini(maxi(1024, int(max_tokens / 2)), max_tokens - 1)
		}

	if not system_texts.is_empty():
		payload["systemInstruction"] = {
			"parts": [{"text": "\n\n".join(system_texts)}]
		}

	if tools.size() > 0:
		var function_declarations: Array = []
		for tool in tools:
			if not (tool is Dictionary):
				continue
			if str(tool.get("type", "")) != "function":
				continue

			var fn = tool.get("function", {})
			if not (fn is Dictionary):
				continue

			var fn_name = str(fn.get("name", ""))
			if fn_name.is_empty():
				continue

			function_declarations.append({
				"name": fn_name,
				"description": str(fn.get("description", "")),
				"parameters": _sanitize_schema_for_gemini(fn.get("parameters", {
					"type": "object",
					"properties": {}
				}))
			})

		if not function_declarations.is_empty():
			payload["tools"] = [{
				"functionDeclarations": function_declarations
			}]

	return payload

## 处理流式响应缓冲区
func _process_buffer(buffer: PackedByteArray, emitted_finish: bool) -> bool:
	var text = buffer.get_string_from_utf8()
	var lines = text.split("\n")

	for i in range(lines.size() - 1):
		var line = lines[i].strip_edges()
		if line.is_empty():
			continue

		var data_str = ""
		if line.begins_with("data: "):
			data_str = line.substr(6).strip_edges()
		elif line.begins_with("{"):
			data_str = line
		else:
			continue

		if data_str.is_empty() or data_str == "[DONE]":
			continue

		if not _is_valid_json_string(data_str):
			if print_log:
				print("Gemini 跳过不完整的JSON: ", data_str.substr(0, 120))
			continue

		var parsed = JSON.parse_string(data_str)
		if parsed == null or not (parsed is Dictionary):
			continue

		var data := parsed as Dictionary
		var extracted := _extract_candidate_parts(data)
		if not extracted.thinking.is_empty():
			think.emit(extracted.thinking)
		if not extracted.text.is_empty():
			message.emit(extracted.text)

		var chunk_tool_calls = _extract_tool_calls(data)
		if not chunk_tool_calls.is_empty():
			if print_log:
				print("Gemini chunk 检测到 functionCall 数量: ", chunk_tool_calls.size())
			_merge_tool_calls(chunk_tool_calls)

		if not emitted_finish:
			var finish_reason = _extract_finish_reason(data)
			if finish_reason != "":
				var total_tokens = _extract_total_tokens(data)
				if print_log:
					print("Gemini chunk finishReason=", finish_reason, " total_tokens=", total_tokens, " merged_tool_calls=", tool_calls.size())
				if not tool_calls.is_empty():
					response_use_tool.emit()
					use_tool.emit(tool_calls)
					generate_finish.emit("tool_calls", total_tokens)
				else:
					generate_finish.emit(finish_reason, total_tokens)
				emitted_finish = true

	if lines.size() > 0:
		buffer.clear()
		buffer.append_array(lines[-1].to_utf8_buffer())

	return emitted_finish

func _extract_candidate_parts(data: Dictionary) -> Dictionary:
	var result := {"text": "", "thinking": ""}
	var candidates = data.get("candidates", [])
	if not (candidates is Array) or candidates.is_empty():
		return result

	var first = candidates[0]
	if not (first is Dictionary):
		return result

	var content = first.get("content", {})
	if not (content is Dictionary):
		return result

	var parts = content.get("parts", [])
	if not (parts is Array):
		return result

	for part in parts:
		if not (part is Dictionary) or not part.has("text"):
			continue
		var part_text := str(part["text"])
		if part.get("thought", false):
			result.thinking += part_text
		else:
			result.text += part_text
	return result

func _extract_candidate_text(data: Dictionary) -> String:
	return _extract_candidate_parts(data).text

func _extract_finish_reason(data: Dictionary) -> String:
	var candidates = data.get("candidates", [])
	if not (candidates is Array) or candidates.is_empty():
		return ""

	var first = candidates[0]
	if not (first is Dictionary):
		return ""

	var finish_reason = str(first.get("finishReason", ""))
	if finish_reason.is_empty():
		return ""

	return finish_reason.to_lower()

func _extract_tool_calls(data: Dictionary) -> Array[AgentModelUtils.ToolCallsInfo]:
	var result: Array[AgentModelUtils.ToolCallsInfo] = []
	var candidates = data.get("candidates", [])
	if not (candidates is Array) or candidates.is_empty():
		return result

	var first = candidates[0]
	if not (first is Dictionary):
		return result

	var content = first.get("content", {})
	if not (content is Dictionary):
		return result

	var parts = content.get("parts", [])
	if not (parts is Array):
		return result

	for i in range(parts.size()):
		var part = parts[i]
		if not (part is Dictionary) or not part.has("functionCall"):
			continue

		var fn_call = part["functionCall"]
		if not (fn_call is Dictionary):
			continue

		var fn_name = str(fn_call.get("name", ""))
		if fn_name.is_empty():
			continue

		var args_data = fn_call.get("args", {})
		var args_text = JSON.stringify(args_data if args_data is Dictionary else {})

		var info = AgentModelUtils.ToolCallsInfo.new()
		var call_id = str(fn_call.get("id", ""))
		if call_id.is_empty():
			call_id = "gemini_tool_" + str(i)
		info.id = call_id
		info.type = "function"
		info.thought_signature = str(fn_call.get("thoughtSignature", fn_call.get("thought_signature", part.get("thoughtSignature", part.get("thought_signature", "")))))
		info.function.name = fn_name
		info.function.arguments = args_text
		result.append(info)

	return result

func _merge_tool_calls(new_calls: Array[AgentModelUtils.ToolCallsInfo]):
	for new_call in new_calls:
		var merged = false
		for old_call in tool_calls:
			if old_call.id == new_call.id:
				old_call.type = new_call.type
				old_call.thought_signature = new_call.thought_signature
				old_call.function.name = new_call.function.name
				var new_args = new_call.function.arguments
				var old_args = old_call.function.arguments
				if old_args.is_empty() or new_args.begins_with(old_args):
					old_call.function.arguments = new_args
				elif not old_args.ends_with(new_args):
					old_call.function.arguments += new_args
				merged = true
				break
		if not merged:
			tool_calls.append(new_call)

func _extract_total_tokens(data: Dictionary) -> float:
	if data.has("usageMetadata") and data["usageMetadata"] is Dictionary:
		return float(data["usageMetadata"].get("totalTokenCount", 0))
	return 0

func _sanitize_schema_for_gemini(schema) -> Variant:
	if schema is Dictionary:
		var dict_schema: Dictionary = schema.duplicate(true)

		var schema_type = dict_schema.get("type", "")
		if schema_type is String and schema_type == "array":
			if not dict_schema.has("items") or dict_schema["items"] == null:
				# Gemini 要求 array 字段必须声明 items
				dict_schema["items"] = {"type": "string"}

		for key in dict_schema.keys():
			dict_schema[key] = _sanitize_schema_for_gemini(dict_schema[key])

		# Gemini 要求 required 中的每个字段都必须在 properties 中定义
		if schema_type is String and schema_type == "object":
			var props = dict_schema.get("properties", {})
			if not (props is Dictionary):
				props = {}
				dict_schema["properties"] = props

			if dict_schema.has("required") and dict_schema["required"] is Array:
				var filtered_required: Array = []
				for req_name in dict_schema["required"]:
					if props.has(str(req_name)):
						filtered_required.append(str(req_name))
				dict_schema["required"] = filtered_required
		return dict_schema

	if schema is Array:
		var arr: Array = []
		for item in schema:
			arr.append(_sanitize_schema_for_gemini(item))
		return arr

	return schema

func _status_to_text(status: int) -> String:
	match status:
		HTTPClient.STATUS_DISCONNECTED:
			return "DISCONNECTED"
		HTTPClient.STATUS_RESOLVING:
			return "RESOLVING"
		HTTPClient.STATUS_CANT_RESOLVE:
			return "CANT_RESOLVE"
		HTTPClient.STATUS_CONNECTING:
			return "CONNECTING"
		HTTPClient.STATUS_CANT_CONNECT:
			return "CANT_CONNECT"
		HTTPClient.STATUS_CONNECTED:
			return "CONNECTED"
		HTTPClient.STATUS_REQUESTING:
			return "REQUESTING"
		HTTPClient.STATUS_BODY:
			return "BODY"
		_:
			return "UNKNOWN"

## 简单验证 JSON 字符串是否完整
func _is_valid_json_string(json_str: String) -> bool:
	if json_str.is_empty():
		return false

	var brace_count = 0
	var bracket_count = 0
	var in_string = false
	var escape_next = false

	for i in range(json_str.length()):
		var c = json_str[i]

		if escape_next:
			escape_next = false
			continue

		if c == "\\":
			escape_next = true
			continue

		if c == '"':
			in_string = !in_string
			continue

		if in_string:
			continue

		if c == "{":
			brace_count += 1
		elif c == "}":
			brace_count -= 1
		elif c == "[":
			bracket_count += 1
		elif c == "]":
			bracket_count -= 1

	return brace_count == 0 and bracket_count == 0 and not in_string

## 关闭连接
func close():
	if http_client:
		http_client.close()
		generatting = false

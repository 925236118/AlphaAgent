@tool
class_name AnthropicChat
extends Node

## Anthropic Messages API 非流式聊天客户端

@export var api_base: String = "https://api.anthropic.com"
@export var secret_key: String = ""
@export var model_name: String = "claude-sonnet-4-6"
@export var use_thinking: bool = false
@export var max_tokens: int = 8192
@export var tools: Array = []
@export var print_log: bool = false

signal generate_finish(msg: String, think_msg: String)
signal use_tool(tool_calls: Array[AgentModelUtils.ToolCallsInfo])
signal response_use_tool
signal error(error_info: Dictionary)

var http_request: HTTPRequest = null
var generatting: bool = false

func _ready() -> void:
	var node := HTTPRequest.new()
	add_child(node)
	http_request = node

func post_message(messages: Array[Dictionary]):
	AgentModelUtils.apply_proxy_to_http_request(http_request)

	var headers := _build_headers()
	var request_data := _build_request_data(messages)
	var request_body := JSON.stringify(request_data)

	if print_log:
		print("Anthropic 非流式请求: ", request_body)

	if not http_request.request_completed.is_connected(_http_request_completed):
		http_request.request_completed.connect(_http_request_completed)

	var err := http_request.request(_build_messages_url(), headers, HTTPClient.METHOD_POST, request_body)
	generatting = true
	if err != OK:
		generatting = false
		push_error("Anthropic 请求发送失败: " + str(err))

func _http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	generatting = false
	var body_text := body.get_string_from_utf8()

	if response_code != 200:
		error.emit(AgentModelUtils.map_http_error(response_code, body_text))
		return

	var json := JSON.new()
	if json.parse(body_text) != OK:
		push_error("Anthropic JSON解析失败: " + json.get_error_message())
		push_error(body_text)
		error.emit({"error_msg":"响应解析失败: " + json.get_error_message(), "error_code":0, "error_type":"server", "data":body_text, "retryable":true})
		return

	var data = json.get_data()
	if not (data is Dictionary):
		push_error("Anthropic 响应结构无效")
		error.emit({"error_msg":"无效的响应结构", "error_code":0, "error_type":"server", "data":body_text, "retryable":false})
		return

	if data.has("error"):
		push_error("Anthropic API错误: " + JSON.stringify(data["error"]))
		error.emit({"error_msg":"Anthropic API错误: " + JSON.stringify(data["error"]), "error_code":0, "error_type":"server", "data":body_text, "retryable":false})
		return

	var content_blocks = data.get("content", [])
	if not (content_blocks is Array):
		content_blocks = []

	var text_parts: Array[String] = []
	var think_parts: Array[String] = []
	var tool_calls := _extract_tool_calls(content_blocks)

	for block in content_blocks:
		if not (block is Dictionary):
			continue
		var block_type := str(block.get("type", ""))
		if block_type == "text":
			text_parts.append(str(block.get("text", "")))
		elif block_type == "thinking":
			think_parts.append(str(block.get("thinking", "")))

	if not tool_calls.is_empty():
		response_use_tool.emit()
		use_tool.emit(tool_calls)

	generate_finish.emit("".join(text_parts), "".join(think_parts))

func _build_headers() -> PackedStringArray:
	return PackedStringArray([
		"Accept: application/json",
		"Content-Type: application/json",
		"x-api-key: %s" % secret_key,
		"anthropic-version: 2023-06-01"
	])

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
				var text_content := str(msg.get("content", ""))
				if not text_content.is_empty():
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

				if blocks.is_empty():
					blocks.append({
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
	var parsed = JSON.parse_string(args_text)
	if parsed is Dictionary:
		return parsed
	return {}

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

func _extract_tool_calls(content_blocks: Array) -> Array[AgentModelUtils.ToolCallsInfo]:
	var result: Array[AgentModelUtils.ToolCallsInfo] = []
	for block in content_blocks:
		if not (block is Dictionary):
			continue
		if str(block.get("type", "")) != "tool_use":
			continue

		var info := AgentModelUtils.ToolCallsInfo.new()
		info.id = str(block.get("id", ""))
		info.type = "function"
		info.function.name = str(block.get("name", ""))
		info.function.arguments = JSON.stringify(block.get("input", {}))
		result.append(info)
	return result

func close():
	if http_request:
		http_request.cancel_request()
		generatting = false

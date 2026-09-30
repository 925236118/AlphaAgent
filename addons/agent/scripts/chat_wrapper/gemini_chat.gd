@tool
class_name GeminiChat
extends Node

## Gemini 非流式聊天客户端（generateContent）

## API基础URL
@export var api_base: String = "https://generativelanguage.googleapis.com/v1beta"
## API密钥
@export var secret_key: String = ""
## 模型名称
@export var model_name: String = "gemini-3-flash-preview"
## 温度值，越高输出越随机，默认为1
@export_range(0.0, 2.0, 0.1) var temperature: float = 1.0
## 最大输出长度
@export var max_tokens: int = 8192
## 可供模型调用的工具（OpenAI function schema，将转换为 Gemini functionDeclarations）
@export var tools: Array = []

## 生成结束信号
signal generate_finish(msg: String, think_msg: String)
## 使用工具（可选）
signal use_tool(tool_calls: Array[AgentModelUtils.ToolCallsInfo])
## 正在返回使用工具请求（可选）
signal response_use_tool
## 失败信号
signal error(error_info: Dictionary)

## 发送请求的HTTPRequest节点
var http_request: HTTPRequest = null
## 是否在生成中
var generatting: bool = false
var tool_calls: Array[AgentModelUtils.ToolCallsInfo] = []

func _ready() -> void:
	var node = HTTPRequest.new()
	add_child(node)
	http_request = node

## 发送请求
func post_message(messages: Array[Dictionary]):
	tool_calls = []
	AgentModelUtils.apply_proxy_to_http_request(http_request)

	var headers = [
		"Accept: application/json",
		"x-goog-api-key: %s" % secret_key,
		"Content-Type: application/json"
	]

	var request_data = _build_request_data(messages)
	var request_body = JSON.stringify(request_data)

	if not http_request.request_completed.is_connected(_http_request_completed):
		http_request.request_completed.connect(_http_request_completed)

	var url = _build_generate_url(false)
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	generatting = true
	if err != OK:
		push_error("Gemini 请求发送失败: " + str(err))
		return

func _http_request_completed(_result, response_code, _headers, body: PackedByteArray):
	generatting = false
	var body_text = body.get_string_from_utf8()

	if response_code != 200:
		error.emit(AgentModelUtils.map_http_error(response_code, body_text))
		return

	var json = JSON.new()
	var err = json.parse(body_text)
	if err != OK:
		push_error("Gemini JSON解析错误: " + json.get_error_message())
		push_error(body_text)
		error.emit({"error_msg":"响应解析失败: " + json.get_error_message(), "error_code":0, "error_type":"server", "data":body_text, "retryable":true})
		return

	var data = json.get_data()
	if data == null or not (data is Dictionary):
		push_error("Gemini 无效的响应结构")
		error.emit({"error_msg":"无效的响应结构", "error_code":0, "error_type":"server", "data":body_text, "retryable":false})
		return

	tool_calls = _extract_tool_calls(data)
	if not tool_calls.is_empty():
		response_use_tool.emit()
		use_tool.emit(tool_calls)

	var content_text = _extract_candidate_text(data)

	# Gemini 无公开推理文本字段，这里按空字符串返回
	generate_finish.emit(content_text, "")

func _build_generate_url(stream: bool) -> String:
	var url = api_base
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)

	var action = ":streamGenerateContent?alt=sse" if stream else ":generateContent"

	if url.contains("/models/"):
		return url + action

	if url.ends_with("/v1beta"):
		return url + "/models/%s%s" % [model_name, action]

	return url + "/v1beta/models/%s%s" % [model_name, action]

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

func _extract_candidate_text(data: Dictionary) -> String:
	if not data.has("candidates"):
		if data.has("promptFeedback"):
			push_error("Gemini 未返回候选内容，可能被安全策略拦截: " + JSON.stringify(data["promptFeedback"]))
		return ""

	var candidates = data.get("candidates", [])
	if not (candidates is Array) or candidates.is_empty():
		return ""

	var first = candidates[0]
	if not (first is Dictionary):
		return ""

	var content = first.get("content", {})
	if not (content is Dictionary):
		return ""

	var parts = content.get("parts", [])
	if not (parts is Array):
		return ""

	var full_text := ""
	for part in parts:
		if part is Dictionary and part.has("text"):
			full_text += str(part["text"])
	return full_text

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
			call_id = "gemini_tool_" + str(Time.get_unix_time_from_system()) + "_" + str(i)
		info.id = call_id
		info.type = "function"
		info.thought_signature = str(fn_call.get("thoughtSignature", fn_call.get("thought_signature", part.get("thoughtSignature", part.get("thought_signature", "")))))
		info.function.name = fn_name
		info.function.arguments = args_text
		result.append(info)

	return result

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

## 结束请求
func close():
	if http_request:
		http_request.cancel_request()
		generatting = false

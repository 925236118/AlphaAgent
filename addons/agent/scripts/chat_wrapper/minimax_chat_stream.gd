@tool
class_name MiniMaxChatStream
extends Node

## MiniMax OpenAI兼容模式流式聊天客户端

## API基础URL
@export var api_base: String = "https://api.minimaxi.com/v1"
## API密钥
@export var secret_key: String = ''
## 模型名称
@export var model_name: String = "MiniMax-M2.5"
## 是否使用深度思考
@export var use_thinking: bool = false
## 温度值，越高输出越随机，默认为1
@export_range(0.0, 2.0, 0.1) var temperature: float = 1.0
## 为正数时降低模型重复相同内容的可能性
@export_range(-2.0, 2.0, 0.1) var frequency_penalty: float = 0
## 为正数时增加模型谈论新主题的可能性
@export_range(-2.0, 2.0, 0.1) var presence_penalty: float = 0
## 最大输出长度
@export var max_tokens: int = 4096
## 是否输出调试日志
@export var print_log: bool = false
## 可以供模型调用的工具
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

var tool_calls: Array[AgentModelUtils.ToolCallsInfo] = []

## 发送请求的http客户端
@onready var http_client: HTTPClient = HTTPClient.new()

var generatting: bool = false

## 发送请求
func post_message(messages: Array[Dictionary]):
	tool_calls = []
	AgentModelUtils.apply_proxy_to_http_client(http_client)
	if print_log: print("请求消息列表: ", messages)

	var headers = [
		"Accept: application/json",
		"Authorization: Bearer %s" % secret_key,
		"Content-Type: application/json"
	]

	var request_data = {
		"messages": messages,
		"model": model_name,
		"frequency_penalty": frequency_penalty,
		"max_tokens": max_tokens,
		"presence_penalty": presence_penalty,
		"stream": true,
		"temperature": temperature,
		"top_p": 1,
	}

	if use_thinking:
		request_data["reasoning_split"] = true

	if tools.size() > 0:
		request_data["tools"] = tools

	var request_body = JSON.stringify(request_data)

	if print_log: print("请求消息数据体: ", request_body)

	var url_parts = api_base.replace("https://", "").replace("http://", "").split("/", false, 1)
	var host = url_parts[0]
	var use_tls = api_base.begins_with("https://")

	var connect_err = http_client.connect_to_host(host, 443 if use_tls else 80,
												  TLSOptions.client() if use_tls else null)
	if connect_err != OK:
		error.emit({
			"error_msg": "连接失败",
			"data": connect_err
		})
		return

	while http_client.get_status() == HTTPClient.STATUS_CONNECTING or \
		  http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		http_client.poll()
		await get_tree().process_frame

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		error.emit({
			"error_msg": "连接失败",
			"data": http_client.get_status()
		})
		return

	var path = "/v1/chat/completions"
	if url_parts.size() > 1 and url_parts[1] != "":
		var base_path = "/" + url_parts[1]
		if base_path.ends_with("/"):
			base_path = base_path.substr(0, base_path.length() - 1)

		if base_path.ends_with("/chat/completions"):
			path = base_path
		elif base_path.ends_with("/v1"):
			path = base_path + "/chat/completions"
		else:
			path = base_path + "/v1/chat/completions"

	if print_log:
		print("请求主机: ", host)
		print("请求路径: ", path)
		print("请求模型: ", model_name)

	var err = http_client.request(HTTPClient.METHOD_POST, path, headers, request_body)
	if err != OK:
		error.emit({
			"error_msg": "请求失败",
			"data": err
		})
		return

	generatting = true

	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		await get_tree().process_frame

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
			var chunk = http_client.read_response_body_chunk()
			if chunk.size() > 0:
				body_chunks.append_array(chunk)
			await get_tree().process_frame

		var error_body = body_chunks.get_string_from_utf8()
		error.emit(AgentModelUtils.map_http_error(http_client.get_response_code(), error_body))
		generatting = false
		return

	var buffer = PackedByteArray()
	while http_client.get_status() == HTTPClient.STATUS_BODY:
		http_client.poll()
		var chunk = http_client.read_response_body_chunk()
		if chunk.size() > 0:
			buffer.append_array(chunk)
			_process_buffer(buffer)
		await get_tree().process_frame

	generatting = false

## 处理流式响应缓冲区
func _process_buffer(buffer: PackedByteArray):
	var text = buffer.get_string_from_utf8()
	var lines = text.split("\n")

	for i in range(lines.size() - 1):
		var line = lines[i].strip_edges()

		if line == "[DONE]" or line == "data: [DONE]":
			continue

		var data_str = ""

		if line.begins_with("data: "):
			data_str = line.substr(6).strip_edges()
		elif line.begins_with("{"):
			data_str = line
		else:
			continue

		if data_str.is_empty():
			continue

		if not data_str.begins_with("{"):
			if print_log and data_str.length() > 0:
				print("跳过非JSON数据: ", data_str.substr(0, 50))
			continue

		if not _is_valid_json_string(data_str):
			if print_log:
				print("跳过不完整的JSON: ", data_str.substr(0, 50))
			continue

		var json = JSON.parse_string(data_str)
		if json != null and json is Dictionary:
			_process_chunk(json)
		elif print_log:
			print("JSON解析失败或格式错误: ", data_str.substr(0, 100))

	if lines.size() > 0:
		buffer.clear()
		buffer.append_array(lines[-1].to_utf8_buffer())

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

## 处理单个数据块
func _process_chunk(data: Dictionary):
	# 检查 MiniMax 业务层错误（base_resp.status_code）
	if data.has("base_resp"):
		var base_resp = data["base_resp"]
		if base_resp is Dictionary and int(base_resp.get("status_code", 0)) != 0:
			generatting = false
			var err_info = AgentModelUtils.map_minimax_base_resp(int(base_resp.get("status_code", 0)))
			err_info["data"] = JSON.stringify(data)
			error.emit(err_info)
			return

	if not data.has("choices"):
		return

	var choices = data["choices"]
	if choices.is_empty():
		return

	var choice = choices[0]
	var delta = choice.get("delta", {})
	var finish_reason = choice.get("finish_reason", null)

	# MiniMax 通过 reasoning_details 返回思考内容（每个 chunk 的 text 就是增量）
	if delta.has("reasoning_details") and delta["reasoning_details"] is Array:
		for detail in delta["reasoning_details"]:
			if detail is Dictionary and detail.has("text"):
				var text_part: String = detail["text"]
				if not text_part.is_empty():
					think.emit(text_part)
	elif delta.has("reasoning_content") and delta["reasoning_content"] != null:
		# 兼容 reasoning_content（其他 OpenAI 兼容提供商格式）
		think.emit(delta["reasoning_content"])

	if delta.has("content") and delta["content"] != null:
		message.emit(delta["content"])

	if delta.has("tool_calls"):
		_process_tool_calls(delta["tool_calls"])

	if finish_reason != null:
		if finish_reason == "tool_calls":
			use_tool.emit(tool_calls)

		var total_tokens = 0
		if data.has("usage") and data["usage"] is Dictionary:
			total_tokens = data["usage"].get("total_tokens", 0)

		generate_finish.emit(finish_reason, total_tokens)

## 处理工具调用
func _process_tool_calls(tool_calls_data: Array):
	response_use_tool.emit()

	for tool_call_data in tool_calls_data:
		var index = tool_call_data.get("index", 0)

		while tool_calls.size() <= index:
			tool_calls.append(AgentModelUtils.ToolCallsInfo.new())

		var tool_call = tool_calls[index]

		if tool_call_data.has("id"):
			tool_call.id = tool_call_data["id"]

		if tool_call_data.has("type"):
			tool_call.type = tool_call_data["type"]

		if tool_call_data.has("function"):
			var func_data = tool_call_data["function"]
			if func_data.has("name"):
				tool_call.function.name = func_data["name"]
			if func_data.has("arguments"):
				tool_call.function.arguments += func_data["arguments"]

## 关闭连接
func close():
	if http_client:
		http_client.close()
		generatting = false

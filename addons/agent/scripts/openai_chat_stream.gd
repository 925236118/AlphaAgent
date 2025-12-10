@tool
class_name OpenAIChatStream
extends Node

## 通用的OpenAI规范流式聊天客户端，支持所有兼容OpenAI API的服务

## API基础URL
@export var api_base: String = "https://api.openai.com"
## API密钥
@export var secret_key: String = ''
## 模型名称
@export var model_name: String = "gpt-3.5-turbo"
## 是否使用深度思考（DeepSeek专用）
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
## 提供商类型（用于特殊处理）
@export var provider: String = "openai"

## 返回正文
signal message(msg: String)
## 返回思考内容（DeepSeek专用）
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
	if print_log: print("请求消息列表: ", messages)

	# 准备请求头
	var headers = [
		"Accept: application/json",
		"Authorization: Bearer %s" % secret_key,
		"Content-Type: application/json"
	]

	# 准备请求体
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

	if tools.size() > 0:
		request_data["tools"] = tools

	var request_body = JSON.stringify(request_data)

	if print_log: print("请求消息数据体: ", request_body)

	# 解析API URL
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

	# 等待连接
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

	# 发送请求
	var path = "/v1/chat/completions"
	if url_parts.size() > 1 and url_parts[1] != "":
		# 如果API base包含路径，则拼接路径
		var base_path = "/" + url_parts[1]
		# 移除末尾的斜杠
		if base_path.ends_with("/"):
			base_path = base_path.substr(0, base_path.length() - 1)

		# 检查路径情况 - 按照优先级从具体到一般
		if base_path.ends_with("/chat/completions"):
			# 已经是完整路径（如豆包：/api/v3/chat/completions）
			path = base_path
		elif base_path.ends_with("/v3"):
			# 豆包等使用 v3，只添加 /chat/completions
			path = base_path + "/chat/completions"
		elif base_path.ends_with("/v1"):
			# 标准 OpenAI，只添加 /chat/completions
			path = base_path + "/chat/completions"
		else:
			# 默认添加完整的 /v1/chat/completions
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

	# 等待响应
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

	# 检查响应码
	if http_client.get_response_code() != 200:
		var body_chunks = PackedByteArray()
		while http_client.get_status() == HTTPClient.STATUS_BODY:
			http_client.poll()
			var chunk = http_client.read_response_body_chunk()
			if chunk.size() > 0:
				body_chunks.append_array(chunk)
			await get_tree().process_frame

		var error_body = body_chunks.get_string_from_utf8()
		error.emit({
			"error_msg": "HTTP错误: " + str(http_client.get_response_code()),
			"data": error_body
		})
		generatting = false
		return

	# 读取流式响应
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

		# 处理 [DONE] 标记
		if line == "[DONE]" or line == "data: [DONE]":
			continue

		var data_str = ""

		# 检查是否有 "data: " 前缀（标准 OpenAI 格式）
		if line.begins_with("data: "):
			data_str = line.substr(6).strip_edges()
		# 如果没有前缀，直接尝试解析（豆包等格式）
		elif line.begins_with("{"):
			data_str = line
		else:
			# 跳过空行或其他无效行
			continue

		# 跳过空行或不完整的数据
		if data_str.is_empty():
			continue

		# 必须以 { 开头（确保是完整的 JSON 对象）
		if not data_str.begins_with("{"):
			if print_log and data_str.length() > 0:
				print("跳过非JSON数据: ", data_str.substr(0, 50))
			continue

		# 验证 JSON 是否完整（简单检查括号平衡）
		if not _is_valid_json_string(data_str):
			if print_log:
				print("跳过不完整的JSON: ", data_str.substr(0, 50))
			continue

		var json = JSON.parse_string(data_str)
		if json != null and json is Dictionary:
			_process_chunk(json)
		elif print_log:
			print("JSON解析失败或格式错误: ", data_str.substr(0, 100))

	# 保留最后一行（可能不完整）
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
	if not data.has("choices"):
		return

	var choices = data["choices"]
	if choices.is_empty():
		return

	var choice = choices[0]
	var delta = choice.get("delta", {})
	var finish_reason = choice.get("finish_reason", null)

	# 处理思考内容（支持 reasoning_content 的提供商，如 SiliconFlow）
	if delta.has("reasoning_content") and delta["reasoning_content"] != null:
		think.emit(delta["reasoning_content"])

	# 处理普通消息
	if delta.has("content") and delta["content"] != null:
		message.emit(delta["content"])

	# 处理工具调用
	if delta.has("tool_calls"):
		_process_tool_calls(delta["tool_calls"])

	# 处理结束
	if finish_reason != null:
		if finish_reason == "tool_calls":
			use_tool.emit(tool_calls)

		var total_tokens = 0
		if data.has("usage"):
			total_tokens = data["usage"].get("total_tokens", 0)

		generate_finish.emit(finish_reason, total_tokens)

## 处理工具调用
func _process_tool_calls(tool_calls_data: Array):
	response_use_tool.emit()

	for tool_call_data in tool_calls_data:
		var index = tool_call_data.get("index", 0)

		# 确保有足够的tool_calls槽位
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

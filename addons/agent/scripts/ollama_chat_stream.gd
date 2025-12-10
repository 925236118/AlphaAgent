@tool
class_name OllamaChatStream
extends Node

## Ollama 流式聊天客户端

## API基础URL（默认本地Ollama）
@export var api_base: String = "http://localhost:11434"
## 模型名称
@export var model_name: String = "llama3:8b"
## 是否使用思考模式（deepseek-r1等推理模型支持）
@export var use_thinking: bool = false
## 温度值，越高输出越随机，默认为0.8
@export_range(0.0, 2.0, 0.1) var temperature: float = 0.8
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
	if print_log: print("Ollama 请求消息列表: ", messages)

	# 准备请求头
	var headers = [
		"Accept: application/json",
		"Content-Type: application/json"
	]

	# 准备请求体 - Ollama 格式
	var request_data = {
		"model": model_name,
		"messages": messages,
		"stream": true,
		"options": {
			"temperature": temperature,
			"num_predict": max_tokens
		}
	}

	# 添加思考模式支持
	if use_thinking:
		request_data["think"] = true

	# 添加工具支持
	if tools.size() > 0:
		request_data["tools"] = tools

	var request_body = JSON.stringify(request_data)

	if print_log: print("Ollama 请求数据体: ", request_body)

	# 解析API URL
	var url_parts = api_base.replace("https://", "").replace("http://", "").split("/", false, 1)
	var host_and_port = url_parts[0]
	var use_tls = api_base.begins_with("https://")

	# 解析主机和端口
	var host = host_and_port
	var port = 443 if use_tls else 11434
	if ":" in host_and_port:
		var parts = host_and_port.split(":", false, 2)
		host = parts[0]
		if parts.size() > 1:
			port = int(parts[1])

	if print_log:
		print("Ollama 连接主机: ", host)
		print("Ollama 连接端口: ", port)

	var connect_err = http_client.connect_to_host(host, port,
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

	# 发送请求 - Ollama 使用 /api/chat 端点
	var path = "/api/chat"

	# 如果 api_base 包含路径部分，需要处理
	if url_parts.size() > 1 and url_parts[1] != "":
		var base_path = "/" + url_parts[1]
		if base_path.ends_with("/"):
			base_path = base_path.substr(0, base_path.length() - 1)

		# 如果 base_path 已经包含 /api，则只添加 /chat
		if base_path.ends_with("/api"):
			path = base_path + "/chat"
		elif base_path == "/api/chat":
			# 已经是完整路径
			path = base_path
		else:
			# 否则添加完整的 /api/chat
			path = base_path + "/api/chat"

	if print_log:
		print("Ollama 请求主机: ", host)
		print("Ollama 请求路径: ", path)
		print("Ollama 请求模型: ", model_name)

	var err = http_client.request(HTTPClient.METHOD_POST, path, headers, request_body)
	if err != OK:
		error.emit({
			"error_msg": "请求失败",
			"data": err
		})
		return

	generatting = true

	# 等待响应头
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

		# Ollama 直接返回 JSON，不需要 "data: " 前缀
		if line.is_empty() or not line.begins_with("{"):
			continue

		# 验证 JSON 是否完整
		if not _is_valid_json_string(line):
			if print_log:
				print("Ollama 跳过不完整的JSON: ", line.substr(0, 50))
			continue

		var json = JSON.parse_string(line)
		if json != null and json is Dictionary:
			_process_chunk(json)
		elif print_log:
			print("Ollama JSON解析失败: ", line.substr(0, 100))

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

## 处理 Ollama 格式的数据块
func _process_chunk(data: Dictionary):
	# Ollama 响应格式:
	# {
	#   "model": "llama3:8b",
	#   "created_at": "2023-12-12T14:13:43.416799Z",
	#   "message": {
	#     "role": "assistant",
	#     "content": "Hello! How are you today?",
	#     "tool_calls": [...]  // 可选：工具调用
	#   },
	#   "done": false
	# }

	if data.has("error"):
		error.emit({
			"error_msg": "Ollama错误",
			"data": data["error"]
		})
		return

	if data.has("message"):
		var msg = data["message"]

		# 处理思考内容（deepseek-r1 等推理模型）
		if msg.has("thinking") and msg["thinking"] != null and msg["thinking"] != "":
			think.emit(msg["thinking"])

		# 处理内容
		if msg.has("content") and msg["content"] != null and msg["content"] != "":
			message.emit(msg["content"])

		# 处理工具调用
		if msg.has("tool_calls"):
			_process_tool_calls(msg["tool_calls"])

	# 检查是否完成
	if data.get("done", false):
		# 如果有工具调用，发出信号
		if tool_calls.size() > 0:
			use_tool.emit(tool_calls)

		var total_tokens = 0.0
		if data.has("prompt_eval_count"):
			total_tokens += float(data["prompt_eval_count"])
		if data.has("eval_count"):
			total_tokens += float(data["eval_count"])

		if print_log:
			print("Ollama 生成完成，总tokens: ", total_tokens)

		generate_finish.emit("stop", total_tokens)

## 处理工具调用
func _process_tool_calls(tool_calls_data: Array):
	if tool_calls_data.is_empty():
		return

	response_use_tool.emit()

	for tool_call_data in tool_calls_data:
		if not tool_call_data is Dictionary:
			continue

		var tool_call = AgentModelUtils.ToolCallsInfo.new()

		if tool_call_data.has("id"):
			tool_call.id = tool_call_data["id"]

		if tool_call_data.has("type"):
			tool_call.type = tool_call_data["type"]

		if tool_call_data.has("function"):
			var func_data = tool_call_data["function"]
			if func_data.has("name"):
				tool_call.function.name = func_data["name"]
			if func_data.has("arguments"):
				# Ollama 可能返回字符串或字典
				if func_data["arguments"] is String:
					tool_call.function.arguments = func_data["arguments"]
				else:
					tool_call.function.arguments = JSON.stringify(func_data["arguments"])

		tool_calls.append(tool_call)

## 关闭连接
func close():
	if http_client:
		http_client.close()
		generatting = false

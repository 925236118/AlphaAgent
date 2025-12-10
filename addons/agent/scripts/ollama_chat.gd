@tool
class_name OllamaChat
extends Node

## Ollama 非流式聊天客户端（用于标题生成等场景）

## API基础URL（默认本地Ollama）
@export var api_base: String = "http://localhost:11434"
## 模型名称
@export var model_name: String = "llama3:8b"
## 温度值，越高输出越随机，默认为0.8
@export_range(0.0, 2.0, 0.1) var temperature: float = 0.8
## 最大输出长度
@export var max_tokens: int = 4096

## 生成结束信号
signal generate_finish(msg: String, think_msg: String)

## 发送请求的HTTPRequest节点
var http_request: HTTPRequest = null
## 是否在生成中
var generatting: bool = false

func _ready() -> void:
	var node = HTTPRequest.new()
	add_child(node)
	http_request = node

## 发送请求
func post_message(messages: Array[Dictionary]):
	# 准备请求头
	var headers = [
		"Accept: application/json",
		"Content-Type: application/json"
	]

	# 准备请求体 - Ollama 格式
	var request_data = {
		"model": model_name,
		"messages": messages,
		"stream": false,
		"options": {
			"temperature": temperature,
			"num_predict": max_tokens
		}
	}

	var request_body = JSON.stringify(request_data)

	if not http_request.request_completed.is_connected(_http_request_completed):
		http_request.request_completed.connect(_http_request_completed)

	# 构建完整URL - Ollama 使用 /api/chat 端点
	var url = api_base
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)

	# 检查 api_base 是否已经包含 /api 路径
	if url.ends_with("/api"):
		url += "/chat"
	else:
		url += "/api/chat"

	# 发送POST请求
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	generatting = true
	if err != OK:
		push_error("Ollama 请求发送失败: " + str(err))
		return

func _http_request_completed(_result, response_code, _headers, body: PackedByteArray):
	generatting = false

	if response_code != 200:
		push_error("Ollama HTTP错误: " + str(response_code))
		push_error(body.get_string_from_utf8())
		return

	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		push_error("Ollama JSON解析错误: " + json.get_error_message())
		push_error(body.get_string_from_utf8())
		return

	var data = json.get_data()

	# Ollama 响应格式:
	# {
	#   "model": "llama3:8b",
	#   "created_at": "2023-12-12T14:13:43.416799Z",
	#   "message": {
	#     "role": "assistant",
	#     "content": "Hello! How are you today?"
	#   },
	#   "done": true,
	#   "done_reason": "stop"
	# }

	if data and data.has("message"):
		var message_data = data["message"]
		var content = message_data.get("content", "")
		var thinking = message_data.get("thinking", "")
		generate_finish.emit(content, thinking)
	elif data and data.has("error"):
		push_error("Ollama API错误: " + str(data["error"]))
	else:
		push_error("Ollama 无效的响应结构")
		print("响应数据: ", JSON.stringify(data))

## 结束请求
func close():
	if http_request:
		http_request.cancel_request()
		generatting = false

@tool
class_name OpenAIChat
extends Node

## 通用的OpenAI规范非流式聊天客户端

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
@export var max_tokens: int = 8192
## 输出内容的类型
@export_enum("text", "json_object") var response_format: String = "text"
## 提供商类型
@export var provider: String = "openai"

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
		"Authorization: Bearer %s" % secret_key,
		"Content-Type: application/json"
	]

	# 准备请求体
	var model = model_name
	if provider == "deepseek" and use_thinking:
		model = "deepseek-reasoner"
	
	var request_data = {
		"messages": messages,
		"model": model,
		"frequency_penalty": frequency_penalty,
		"max_tokens": max_tokens,
		"presence_penalty": presence_penalty,
		"response_format": {
			"type": response_format
		},
		"stream": false,
		"temperature": temperature,
		"top_p": 1,
		"tools": null,
		"tool_choice": "none",
	}
	
	# 注意：enable_thinking 参数并非所有提供商都支持
	# 豆包等提供商的推理模型会自动返回 reasoning_content，无需额外参数
	
	var request_body = JSON.stringify(request_data)
	
	if not http_request.request_completed.is_connected(_http_request_completed):
		http_request.request_completed.connect(_http_request_completed)

	# 构建完整URL
	var url = api_base
	# 移除末尾的斜杠
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	
	# 检查是否已经包含完整路径
	if url.ends_with("/chat/completions"):
		# 已经是完整路径，不需要添加
		pass
	elif url.ends_with("/v3"):
		# 豆包等使用 v3，只添加 /chat/completions
		url += "/chat/completions"
	elif url.ends_with("/v1"):
		# 标准 OpenAI，只添加 /chat/completions
		url += "/chat/completions"
	else:
		# 默认添加完整的 /v1/chat/completions
		url += "/v1/chat/completions"
	
	# 发送POST请求
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	generatting = true
	if err != OK:
		push_error("请求发送失败: " + str(err))
		return

func _http_request_completed(_result, _response_code, _headers, body: PackedByteArray):
	generatting = false
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		push_error("JSON解析错误: " + json.get_error_message())
		push_error(body.get_string_from_utf8())
		return

	var data = json.get_data()
	if data and data.has("choices"):
		var choices := data["choices"] as Array
		if choices.size() > 0:
			var message_data = choices[0].get("message", {})
			var content = message_data.get("content", "")
			# 支持 reasoning_content（如 SiliconFlow 等提供商）
			var think_msg = message_data.get("reasoning_content", "")
			generate_finish.emit(content, think_msg)
	else:
		# 检查是否是错误响应
		if data.has("error"):
			var error_info = data["error"]
			var error_msg = "API错误"
			if error_info is Dictionary:
				if error_info.has("message"):
					error_msg = error_info["message"]
				if error_info.has("type"):
					error_msg += " (类型: " + str(error_info["type"]) + ")"
			push_error(error_msg)
			print("完整错误信息: ", JSON.stringify(data))
		else:
			print(data)
			push_error("无效的响应结构")

## 结束请求
func close():
	if http_request:
		http_request.cancel_request()
		generatting = false

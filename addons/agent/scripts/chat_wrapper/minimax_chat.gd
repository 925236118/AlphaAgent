@tool
class_name MiniMaxChat
extends Node

## MiniMax OpenAI兼容模式非流式聊天客户端

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
@export var max_tokens: int = 8192
## 输出内容的类型
@export_enum("text", "json_object") var response_format: String = "text"

## 生成结束信号
signal generate_finish(msg: String, think_msg: String)
## 失败信号
signal error(error_info: Dictionary)

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
	AgentModelUtils.apply_proxy_to_http_request(http_request)

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
		"response_format": {
			"type": response_format
		},
		"stream": false,
		"temperature": temperature,
		"top_p": 1,
		"tools": null,
		"tool_choice": "none",
	}

	if use_thinking:
		request_data["reasoning_split"] = true

	var request_body = JSON.stringify(request_data)

	if not http_request.request_completed.is_connected(_http_request_completed):
		http_request.request_completed.connect(_http_request_completed)

	var url = api_base
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)

	if url.ends_with("/chat/completions"):
		pass
	elif url.ends_with("/v1"):
		url += "/chat/completions"
	else:
		url += "/v1/chat/completions"

	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	generatting = true
	if err != OK:
		push_error("MiniMax 请求发送失败: " + str(err))
		return

func _http_request_completed(_result, _response_code, _headers, body: PackedByteArray):
	generatting = false
	var body_str = body.get_string_from_utf8()

	# 检查 HTTP 状态码
	if _response_code != 200:
		error.emit(AgentModelUtils.map_http_error(_response_code, body_str))
		return

	var json = JSON.new()
	var err = json.parse(body_str)
	if err != OK:
		push_error("JSON解析错误: " + json.get_error_message())
		push_error(body_str)
		error.emit({"error_msg":"响应解析失败: " + json.get_error_message(), "error_code":0, "error_type":"server", "data":body_str, "retryable":true})
		return

	var data = json.get_data()

	# 检查 MiniMax 业务层错误（base_resp.status_code）
	if data.has("base_resp"):
		var base_resp = data["base_resp"]
		if base_resp is Dictionary and int(base_resp.get("status_code", 0)) != 0:
			var err_info = AgentModelUtils.map_minimax_base_resp(int(base_resp.get("status_code", 0)))
			err_info["data"] = JSON.stringify(data)
			error.emit(err_info)
			return

	if data and data.has("choices"):
		var choices := data["choices"] as Array
		if choices.size() > 0:
			var message_data = choices[0].get("message", {})
			var content = message_data.get("content", "")

			# MiniMax 通过 reasoning_details 返回思考内容
			var think_msg = ""
			if message_data.has("reasoning_details") and message_data["reasoning_details"] is Array:
				for detail in message_data["reasoning_details"]:
					if detail is Dictionary and detail.has("text"):
						think_msg += detail["text"]

			# 如果未启用 reasoning_split，content 中可能包含 <think> 标签
			if think_msg.is_empty() and content.find("<think>") != -1:
				var think_start = content.find("<think>") + 7
				var think_end = content.find("</think>")
				if think_end > think_start:
					think_msg = content.substr(think_start, think_end - think_start)
					content = content.substr(think_end + 8).strip_edges()

			generate_finish.emit(content, think_msg)
	else:
		if data.has("error"):
			var error_info = data["error"]
			var error_msg = "MiniMax API错误"
			if error_info is Dictionary:
				if error_info.has("message"):
					error_msg = error_info["message"]
				if error_info.has("type"):
					error_msg += " (类型: " + str(error_info["type"]) + ")"
			error.emit({"error_msg":error_msg, "error_code":0, "error_type":"server", "data":JSON.stringify(data), "retryable":false})
		else:
			print(data)
			error.emit({"error_msg":"无效的响应结构", "error_code":0, "error_type":"server", "data":body_str, "retryable":false})

## 结束请求
func close():
	if http_request:
		http_request.cancel_request()
		generatting = false

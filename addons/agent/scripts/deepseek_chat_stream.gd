@tool
class_name DeepSeekChatStream
extends Node

## 用于向deepseek发送请求并获取流式返回的节点

## deepseek Token，在开放平台获取
@export var secret_key: String = ''
## 系统角色prompt，用于预设人设
#@export_multiline var prompt: String = ""
## 深度思考
@export var use_thinking: bool = false
## 温度值，越高输出越随机，默认为1
@export_range(0.0, 2.0, 0.1) var temperature: float = 1.0
## 为正数时降低模型重复相同内容的可能性
@export_range(-2.0, 2.0, 0.1) var frequency_penalty: float = 0
## 为正数时增加模型谈论新主题的可能性
@export_range(-2.0, 2.0, 0.1) var presence_penalty: float = 0
## 最大输出长度，deepseek-chat模型，最大8K，deepseek-reasoner模型，最大64K
@export var max_tokens: int = 4096
## 是否输出调试日志
@export var print_log: bool = false

## 返回正文
signal message(msg: String)
## 返回正思考内容
signal think(msg: String)
## 返回结束
signal generate_finish

## 发送请求的http客户端
@onready var http_client: HTTPClient = HTTPClient.new()

var generatting: bool = false

## 发送请求
func post_message(messages: Array[Dictionary]):
	if print_log: print("请求消息列表: ", messages)
	# 准备请求数据
	var headers = [
		"Accept: application/json",
		"Authorization: Bearer %s" % secret_key,
		"Content-Type: application/json"
	]

	var request_body = JSON.stringify({
		"messages": messages,
		"model": "deepseek-reasoner" if use_thinking else "deepseek-chat",
		"frequency_penalty": frequency_penalty,
		"max_tokens": max_tokens,
		"presence_penalty": presence_penalty,
		"response_format": {
			"type": "text"
		},
		"stream": true,
		"stream_options": null,
		"temperature": temperature,
		"top_p": 1,
		"tools": null,
		"tool_choice": "none",
		"logprobs": false,
		"top_logprobs": null
	})

	if print_log: print("请求消息数据体: ", request_body)

	var connect_err = http_client.connect_to_host("https://api.deepseek.com")
	generatting = true
	if connect_err != OK:
		push_error("连接服务器失败: " + error_string(connect_err))
		return
	while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		http_client.poll()
		#print("Connecting...")
		await get_tree().process_frame
	if print_log: print("链接服务器成功")
	# 发送POST请求
	var err = http_client.request(HTTPClient.METHOD_POST, "/chat/completions", headers, request_body)
	if err != OK:
		push_error("请求发送失败: " + error_string(err))
		return
	if print_log: print("发送请求成功")
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		await get_tree().process_frame

	if print_log: print("开始返回数据")

	if http_client.has_response():
		headers = http_client.get_response_headers_as_dictionary()

		if print_log: print("http_client.get_status()", http_client.get_status())

		while http_client.get_status() == HTTPClient.STATUS_BODY:
			http_client.poll()
			var chunk = http_client.read_response_body_chunk()
			if print_log: print("chunk.size()", chunk.size())
			if chunk.size() == 0:
				await get_tree().process_frame
			else:
				var chunk_string = chunk.get_string_from_utf8()
				
				if print_log: print(chunk_string)
				
				var data_array = chunk_string.split("\n")
				for data_string in data_array:
					if data_string.begins_with("data: "):
						data_string = data_string.replace("data: ", "")
						if data_string == "[DONE]":
							continue
						var json = JSON.new()
						var parse_err = json.parse(data_string)
						if parse_err != OK:
							push_error("JSON解析错误: " + json.get_error_message())
							push_error(data_string)
							return

						var data = json.get_data()
						if print_log: print("返回数据: ", data)
						if data and data.has("choices"):
							var choices := data["choices"] as Array
							var delta = choices[0]["delta"]
							if use_thinking and delta.has("reasoning_content") and delta.get("reasoning_content") != null:
								think.emit(delta["reasoning_content"])
							else:
								message.emit(delta["content"])
							if choices[0].has("finish_reason") and choices[0].get("finish_reason") == "stop":
								generatting = false
								generate_finish.emit()
						else:
							generatting = false
							print(data)
							push_error("无效的响应结构")
## 中断请求
func close():
	generatting = false
	http_client.close()

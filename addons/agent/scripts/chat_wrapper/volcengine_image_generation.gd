@tool
class_name VolcengineImageGeneration
extends Node

## 火山引擎 Seedream 图片生成客户端
## 文档：https://www.volcengine.com/docs/82379/seedream-4-0-5-0
## POST /api/v3/images/generations
## 支持：文生图、图生图（单图/多图）

@export var api_base: String = "https://ark.cn-beijing.volces.com/api/v3"
@export var secret_key: String = ''
@export var model_name: String = "doubao-seedream-5-0-flash-260915"

## 图片生成完成信号（返回 data URL 数组，可直接渲染）
signal image_generated(images: Array)
## 失败信号
signal error(error_info: Dictionary)

var http_request: HTTPRequest = null
var generatting: bool = false

func _ready() -> void:
	var node = HTTPRequest.new()
	add_child(node)
	http_request = node

## 生成图片
## prompt: 文本描述（必需）
## images: 参考图 URL 或 data URL 数组（图生图，可选）
## size: "1K"/"1.5K"/"2K"/"3K"/"4K"
## output_format: "png"/"jpeg"
func generate(prompt: String, images: Array = [], size: String = "2K", output_format: String = "png"):
	AgentModelUtils.apply_proxy_to_http_request(http_request)

	var headers = [
		"Accept: application/json",
		"Authorization: Bearer %s" % secret_key,
		"Content-Type: application/json"
	]

	var request_data = {
		"model": model_name,
		"prompt": prompt,
		"size": size,
		"output_format": output_format,
		"response_format": "b64_json",
		"watermark": false
	}

	# 图生图：image 参数（单图传字符串，多图传数组）
	if images.size() == 1:
		request_data["image"] = images[0]
	elif images.size() > 1:
		request_data["image"] = images

	var request_body = JSON.stringify(request_data)

	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	# 构造 URL
	var url = api_base
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	url += "/images/generations"

	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	generatting = true
	if err != OK:
		error.emit({"error_msg": "火山引擎生图请求发送失败", "error_code": 0, "error_type": "network", "data": err, "retryable": true})

func _on_request_completed(_result, response_code, _headers, body: PackedByteArray):
	generatting = false
	var body_str = body.get_string_from_utf8()

	if response_code != 200:
		error.emit(AgentModelUtils.map_http_error(response_code, body_str))
		return

	var json = JSON.new()
	if json.parse(body_str) != OK:
		error.emit({"error_msg": "响应解析失败: " + json.get_error_message(), "error_code": 0, "error_type": "server", "data": body_str, "retryable": true})
		return

	var data = json.get_data()

	# 提取图片
	var images_result: Array = []
	if data.has("data"):
		for img_data in data["data"]:
			if img_data is Dictionary:
				if img_data.has("b64_json"):
					images_result.append("data:image/png;base64," + img_data["b64_json"])
				elif img_data.has("url"):
					images_result.append(img_data["url"])

	if images_result.size() > 0:
		image_generated.emit(images_result)
	else:
		error.emit({"error_msg": "未生成任何图片", "error_code": 0, "error_type": "request", "data": body_str, "retryable": false})

func close():
	if http_request:
		http_request.cancel_request()
		generatting = false

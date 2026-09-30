@tool
class_name MiniMaxImageGeneration
extends Node

## MiniMax 图片生成客户端（image-01 / image-01-live）
## T2I 文生图 + I2I 图生图，共用 POST /v1/image_generation 端点
## 文档：https://platform.minimax.cn/docs/api-reference/image-generation-t2i.md

@export var api_base: String = "https://api.minimax.cn"
@export var secret_key: String = ''
@export var model_name: String = "image-01"

## 图片生成完成信号（返回 data URL 数组，可直接用于渲染）
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
## prompt: 文本描述（必需，最长 1500 字符）
## subject_refs: 参考图数组 [{type:"character", image_file:"data:image/..."}]（图生图，可选）
## aspect_ratio: 宽高比（1:1/16:9/4:3/3:2/2:3/3:4/9:16/21:9）
## n: 生成数量 [1,9]
## style_type: 画风风格（漫画/元气/中世纪/水彩，仅 image-01-live 生效）
func generate(prompt: String, subject_refs: Array = [], aspect_ratio: String = "1:1", n: int = 1, style_type: String = ""):
	AgentModelUtils.apply_proxy_to_http_request(http_request)

	var headers = [
		"Accept: application/json",
		"Authorization: Bearer %s" % secret_key,
		"Content-Type: application/json"
	]

	var request_data = {
		"model": model_name,
		"prompt": prompt,
		"aspect_ratio": aspect_ratio,
		"n": n,
		"response_format": "base64",
		"prompt_optimizer": true
	}

	# 图生图：添加参考图（url 字符串转为 subject_reference 格式）
	if subject_refs.size() > 0:
		request_data["subject_reference"] = subject_refs.map(func(url): return {"type": "character", "image_file": url})

	# 画风设置（仅 image-01-live 生效）
	if not style_type.is_empty() and model_name == "image-01-live":
		request_data["style"] = {"style_type": style_type}

	var request_body = JSON.stringify(request_data)

	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	# 构造 URL
	var url = api_base
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	if url.ends_with("/v1"):
		url += "/image_generation"
	elif url.ends_with("/chat/completions"):
		url = url.substr(0, url.find_last("/chat/completions")) + "/image_generation"
	else:
		url += "/v1/image_generation"

	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, request_body)
	generatting = true
	if err != OK:
		error.emit({"error_msg": "MiniMax 生图请求发送失败", "error_code": 0, "error_type": "network", "data": err, "retryable": true})

func _on_request_completed(_result, response_code, _headers, body: PackedByteArray):
	generatting = false
	var body_str = body.get_string_from_utf8()

	# 检查 HTTP 状态码
	if response_code != 200:
		error.emit(AgentModelUtils.map_http_error(response_code, body_str))
		return

	var json = JSON.new()
	if json.parse(body_str) != OK:
		error.emit({"error_msg": "响应解析失败: " + json.get_error_message(), "error_code": 0, "error_type": "server", "data": body_str, "retryable": true})
		return

	var data = json.get_data()

	# 检查 MiniMax 业务层错误（base_resp.status_code）
	if data.has("base_resp"):
		var base_resp = data["base_resp"]
		if base_resp is Dictionary and int(base_resp.get("status_code", 0)) != 0:
			var err_info = AgentModelUtils.map_minimax_base_resp(int(base_resp.get("status_code", 0)))
			err_info["data"] = body_str
			error.emit(err_info)
			return

	# 提取图片
	var images: Array = []
	if data.has("data"):
		var data_obj = data["data"]
		if data_obj is Dictionary:
			if data_obj.has("image_base64"):
				# base64 格式 → 转成 data URL 便于直接渲染
				for b64 in data_obj["image_base64"]:
					images.append("data:image/png;base64," + b64)
			elif data_obj.has("image_urls"):
				# URL 格式（备用）
				for img_url in data_obj["image_urls"]:
					images.append(img_url)

	if images.size() > 0:
		image_generated.emit(images)
	else:
		var failed = 0
		if data.has("metadata") and data["metadata"] is Dictionary:
			failed = int(data["metadata"].get("failed_count", 0))
		var msg = "未生成任何图片" if failed == 0 else "%d 张图片因内容安全检查被拦截" % failed
		error.emit({"error_msg": msg, "error_code": 0, "error_type": "request", "data": body_str, "retryable": false})

func close():
	if http_request:
		http_request.cancel_request()
		generatting = false

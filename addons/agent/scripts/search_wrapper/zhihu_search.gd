@tool
class_name ZhihuSearch
extends SearchProviderBase

## 知乎数据开放平台搜索
## 文档: https://developer.zhihu.com/docs?key=zhihu_search
## 站内搜索: https://developer.zhihu.com/api/v1/content/zhihu_search
## 全网搜索: https://developer.zhihu.com/api/v1/content/global_search
## 认证: Access Secret（长期有效，申请一次即可）

var access_secret: String = ""

## 站内搜索（知乎站内内容）
func search(query: String, max_results: int = 10) -> Dictionary:
	if access_secret.is_empty():
		return {"error": "知乎 Access Secret 未配置，请在设置面板填写"}

	var http = HTTPRequest.new()
	add_child(http)
	_setup_http_proxy(http)

	var url = "https://developer.zhihu.com/api/v1/content/zhihu_search"
	url += "?Query=" + query.uri_encode()
	url += "&Count=" + str(mini(max_results, 10))

	var timestamp = str(int(Time.get_unix_time_from_system()))
	var headers = [
		"Authorization: Bearer " + access_secret,
		"X-Request-Timestamp: " + timestamp,
		"Content-Type: application/json"
	]
	var err = http.request(url, headers, HTTPClient.METHOD_GET, "")
	if err != OK:
		http.queue_free()
		return {"error": "请求发送失败"}

	var response = await http.request_completed
	http.queue_free()

	return _parse_response(query, response)

## 全网搜索（全网内容）
func search_global(query: String, max_results: int = 10) -> Dictionary:
	if access_secret.is_empty():
		return {"error": "知乎 Access Secret 未配置，请在设置面板填写"}

	var http = HTTPRequest.new()
	add_child(http)
	_setup_http_proxy(http)

	var url = "https://developer.zhihu.com/api/v1/content/global_search"
	url += "?Query=" + query.uri_encode()
	url += "&Count=" + str(mini(max_results, 20))

	var timestamp = str(int(Time.get_unix_time_from_system()))
	var headers = [
		"Authorization: Bearer " + access_secret,
		"X-Request-Timestamp: " + timestamp,
		"Content-Type: application/json"
	]
	var err = http.request(url, headers, HTTPClient.METHOD_GET, "")
	if err != OK:
		http.queue_free()
		return {"error": "请求发送失败"}

	var response = await http.request_completed
	http.queue_free()

	return _parse_response(query, response)

## 解析知乎响应（两个接口响应格式一致）
func _parse_response(query: String, response: Array) -> Dictionary:
	var result_code = response[0]
	var response_code = response[1]
	var response_body = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"error": "网络请求失败"}
	if response_code != 200:
		return {"error": "知乎搜索失败（HTTP %d）: %s" % [response_code, response_body.get_string_from_utf8()]}

	var json = JSON.parse_string(response_body.get_string_from_utf8())
	if not json is Dictionary:
		return {"error": "响应解析失败"}

	# 知乎业务错误码: 0=成功, 10001=参数错误, 20001=鉴权失败, 30001=频率限制, 90001=内部错误
	var code = json.get("Code", -1)
	if code != 0:
		return {"error": "知乎搜索失败（码 %d）: %s" % [code, json.get("Message", "未知错误")]}

	var results: Array = []
	var data = json.get("Data", {})
	if data is Dictionary:
		var items = data.get("Items", [])
		for item in items:
			if item is Dictionary:
				results.append(format_result(
					item.get("Title", ""),
					item.get("Url", ""),
					item.get("ContentText", ""),
					"知乎"
				))

	return {"query": query, "results": results}

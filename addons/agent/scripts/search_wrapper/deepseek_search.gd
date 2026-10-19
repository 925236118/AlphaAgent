@tool
class_name DeepSeekSearch
extends SearchProviderBase

## DeepSeek 独立搜索 API（不依赖当前对话模型）
## 文档: https://api-docs.deepseek.com/zh-cn/guides/search/
const SEARCH_URL = "https://api.deepseek.com/v1/tools/search"

var api_key: String = ""

func search(query: String, max_results: int = 10) -> Dictionary:
	if api_key.strip_edges().is_empty():
		return {"error": "DeepSeek API Key 未配置，请在设置面板填写"}
	if query.strip_edges().is_empty() or query.length() > 128:
		return {"error": "DeepSeek 搜索关键字须为 1～128 个字符，且不能全为空白"}

	var http = HTTPRequest.new()
	http.timeout = 60.0
	add_child(http)
	_setup_http_proxy(http)
	var body = JSON.stringify({
		"query": query,
		"count": clampi(max_results, 1, 50),
		"need_content": false
	})
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + api_key.strip_edges()]
	var err = http.request(SEARCH_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"error": "DeepSeek 搜索请求发送失败（错误码 %d）" % err}

	var response = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"error": "DeepSeek 搜索网络请求失败或超时（错误码 %d）" % response[0]}
	return _parse_response(query, response[1], response[3].get_string_from_utf8())


func _parse_response(query: String, response_code: int, response_body: String) -> Dictionary:
	var parser = JSON.new()
	var json = parser.data if parser.parse(response_body) == OK else null
	if response_code != 200:
		var message = ""
		if json is Dictionary and json.get("error") is Dictionary:
			message = str(json["error"].get("message", ""))
		match response_code:
			401:
				message = "API Key 无效，请检查设置中的 DeepSeek API Key"
			402:
				message = "DeepSeek 账号余额不足，请充值后重试"
			408, 429, 500, 502, 503, 504:
				message = "请求超时、限流或服务暂不可用，请稍后重试。" + message
		return {"error": "DeepSeek 搜索失败（HTTP %d）: %s" % [response_code, message]}
	if not json is Dictionary or not json.get("results") is Array:
		return {"error": "DeepSeek 搜索响应解析失败：缺少 results 数组"}

	var results: Array = []
	for item in json["results"]:
		if not item is Dictionary:
			continue
		# 官方长摘要供模型阅读；缺失时回退到短摘要。
		var content = str(item.get("summary", ""))
		if content.is_empty():
			content = str(item.get("snippet", ""))
		var source = item.get("site_name")
		if not source is String or source.is_empty():
			source = "deepseek"
		var result = format_result(str(item.get("title", "")), str(item.get("url", "")), content, source)
		result["date"] = item.get("date")
		result["authority"] = item.get("authority", -1)
		result["rerank_score"] = item.get("rerank_score", 0)
		results.append(result)
	return {"query": query, "results": results}

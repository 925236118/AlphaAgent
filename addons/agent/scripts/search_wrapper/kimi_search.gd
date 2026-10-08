@tool
class_name KimiSearch
extends SearchProviderBase

## Kimi (Moonshot) 联网搜索
## 文档: https://platform.kimi.com/docs/api/tools-search

var api_key: String = ""

func search(query: String, max_results: int = 10) -> Dictionary:
	if api_key.is_empty():
		return {"error": "Kimi API Key 未配置，请在设置面板填写"}

	var http = HTTPRequest.new()
	add_child(http)
	_setup_http_proxy(http)

	var body = JSON.stringify({
		"text_query": query,
		"limit": mini(max_results, 20)
	})
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + api_key]
	var err = http.request("https://api.moonshot.cn/v1/tools/search", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"error": "请求发送失败"}

	var response = await http.request_completed
	http.queue_free()

	var result_code = response[0]
	var response_code = response[1]
	var response_body = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"error": "网络请求失败"}
	if response_code != 200:
		return {"error": "Kimi 搜索失败（HTTP %d）: %s" % [response_code, response_body.get_string_from_utf8()]}

	var json = JSON.parse_string(response_body.get_string_from_utf8())
	if not json is Dictionary:
		return {"error": "响应解析失败"}

	var results: Array = []
	var search_results = json.get("search_results", [])
	for item in search_results:
		if item is Dictionary:
			results.append(format_result(
				item.get("title", ""),
				item.get("url", ""),
				item.get("snippet", ""),
				item.get("site_name", "kimi")
			))

	return {"query": query, "results": results}

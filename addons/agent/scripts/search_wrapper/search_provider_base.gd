@tool
class_name SearchProviderBase
extends Node

## 搜索供应商基类，定义统一搜索接口

## 统一搜索接口，子类实现
func search(query: String, max_results: int = 10) -> Dictionary:
	return {"error": "未实现"}


## 统一结果格式化（content 截取前 500 字）
static func format_result(title: String, url: String, content: String, source: String = "") -> Dictionary:
	if content.length() > 500:
		content = content.substr(0, 500) + "..."
	return {"title": title, "url": url, "content": content, "source": source}


## 设置 HTTP/HTTPS 代理（复用全局设置，与 chat_wrapper 一致）
func _setup_http_proxy(http: HTTPRequest):
	AgentModelUtils.apply_proxy_to_http_request(http)

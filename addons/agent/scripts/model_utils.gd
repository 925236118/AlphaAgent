@tool
class_name AgentModelUtils
extends RefCounted

class ToolCallsInfo:
	var id: String = ""
	var function: ToolCallsInfoFunc = ToolCallsInfoFunc.new()
	var type: String = "function"
	# Gemini 工具调用要求在后续回传 functionCall 时携带 thought_signature
	var thought_signature: String = ""
	func to_dict():
		return {
			"id": id,
			"type": type,
			"thought_signature": thought_signature,
			"function": function.to_dict()
		}

class ToolCallsInfoFunc:
	var name: String = ""
	var arguments: String = ""

	func to_dict():
		return {
			"name": name,
			"arguments": arguments
		}

static func get_proxy_config() -> Dictionary:
	var host := ""
	var port := 0
	var enabled := false

	if AlphaAgentPlugin.global_setting != null:
		host = str(AlphaAgentPlugin.global_setting.http_proxy_host).strip_edges()
		var port_text = str(AlphaAgentPlugin.global_setting.http_proxy_port).strip_edges()
		if not port_text.is_empty() and port_text.is_valid_int():
			port = int(port_text)

	enabled = not host.is_empty() and port > 0 and port <= 65535
	return {
		"enabled": enabled,
		"host": host,
		"port": port
	}

static func apply_proxy_to_http_client(client: HTTPClient) -> void:
	if client == null:
		return

	var proxy = get_proxy_config()
	if proxy.get("enabled", false):
		var host = str(proxy.get("host", ""))
		var port = int(proxy.get("port", 0))
		client.set_http_proxy(host, port)
		client.set_https_proxy(host, port)
	else:
		client.set_http_proxy("", 0)
		client.set_https_proxy("", 0)

static func apply_proxy_to_http_request(request_node: HTTPRequest) -> void:
	if request_node == null:
		return

	var proxy = get_proxy_config()
	if proxy.get("enabled", false):
		var host = str(proxy.get("host", ""))
		var port = int(proxy.get("port", 0))
		request_node.set_http_proxy(host, port)
		request_node.set_https_proxy(host, port)
	else:
		request_node.set_http_proxy("", 0)
		request_node.set_https_proxy("", 0)

## 将 HTTP 状态码映射为结构化的错误信息。
## 适用于所有 OpenAI 兼容厂商（DeepSeek/OpenAI/MoonShot/MiniMax HTTP 层等）。
## 参考：DeepSeek https://api-docs.deepseek.com/zh-cn/quick_start/error_codes
static func map_http_error(code: int, body: String = "") -> Dictionary:
	var type := "server"
	var msg := "HTTP错误: " + str(code)
	var retryable := false
	match code:
		400:
			type = "request"
			msg = "请求体格式错误，请检查消息内容"
			retryable = false
		401:
			type = "auth"
			msg = "API 密钥错误，请在模型设置中检查密钥"
			retryable = false
		402:
			type = "balance"
			msg = "账号余额不足，请充值后重试"
			retryable = false
		403:
			type = "auth"
			msg = "无访问权限，请检查账户权限"
			retryable = false
			# 解析 body 中的 error.code，给出更准确的错误信息
			if body.begins_with("{"):
				var parsed = JSON.parse_string(body)
				if parsed is Dictionary and parsed.has("error"):
					var err = parsed["error"]
					if err is Dictionary:
						match err.get("code", ""):
							"AccountOverdueError":
								type = "balance"
								msg = "账户欠费，请充值后重试"
								retryable = false
							"ModelNotOpen":
								type = "auth"
								msg = "模型未开通，请在控制台开通对应模型"
								retryable = false
		404:
			type = "request"
			msg = "模型名或接口地址错误，请检查配置"
			retryable = false
		413:
			type = "request"
			msg = "请求体过大（图片太多或太大）"
			retryable = false
		422:
			type = "request"
			msg = "请求参数错误，请检查模型或消息参数"
			retryable = false
		429:
			type = "rate_limit"
			msg = "请求过于频繁，已触发限流，请稍后重试"
			retryable = true
		500, 502, 503, 504:
			type = "server"
			msg = "服务暂不可用，请稍后重试"
			retryable = true
		_:
			# 其他非 200 状态码，默认按服务器错误处理（可重试）
			if code >= 500:
				type = "server"
				msg = "服务暂不可用（%d），请稍后重试" % code
				retryable = true
			else:
				type = "request"
				msg = "请求错误（%d），请检查配置" % code
				retryable = false
	return {
		"error_msg": msg,
		"error_code": code,
		"error_type": type,
		"data": body,
		"retryable": retryable
	}

## 将 MiniMax 业务层错误码（base_resp.status_code）映射为结构化错误信息。
## 参考：https://platform.minimax.cn/docs/api-reference/errorcode.md
static func map_minimax_base_resp(status_code: int) -> Dictionary:
	var msg := "MiniMax错误码: " + str(status_code)
	var type := "server"
	var retryable := false
	match status_code:
		1000:
			msg = "未知错误，请稍后再试"
			type = "server"
			retryable = true
		1001:
			msg = "请求超时，请检查网络后稍后再试"
			type = "network"
			retryable = true
		1002:
			msg = "请求频率超限，请稍后再试"
			type = "rate_limit"
			retryable = true
		1004:
			msg = "未授权，请检查 API Key"
			type = "auth"
			retryable = false
		1008:
			msg = "余额不足，请检查账户余额"
			type = "balance"
			retryable = false
		1024:
			msg = "内部错误，请稍后再试"
			type = "server"
			retryable = true
		1026:
			msg = "输入内容涉敏，请调整输入内容"
			type = "request"
			retryable = false
		1027:
			msg = "输出内容涉敏，请调整输入内容"
			type = "request"
			retryable = false
		1033:
			msg = "系统错误/下游服务错误，请稍后再试"
			type = "server"
			retryable = true
		1039:
			msg = "Token 限制，请调整 max_tokens"
			type = "request"
			retryable = false
		1041:
			msg = "连接数限制，请联系服务商"
			type = "rate_limit"
			retryable = false
		2045:
			msg = "请求频率增长超限，请避免请求骤增骤减"
			type = "rate_limit"
			retryable = true
		2049:
			msg = "无效的 API Key，请检查配置"
			type = "auth"
			retryable = false
		2056:
			msg = "超出 Token Plan 资源限制，请等待下个时间段释放"
			type = "rate_limit"
			retryable = true
	return {
		"error_msg": msg,
		"error_code": status_code,
		"error_type": type,
		"data": "",
		"retryable": retryable
	}

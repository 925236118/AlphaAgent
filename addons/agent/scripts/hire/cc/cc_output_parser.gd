@tool
class_name CCOutputParser
extends AgentOutputParser

## CC stream-json 输出解析器
## 将 CC 的 JSON 事件流转换为统一事件格式

## 解析一行 CC stream-json 输出
## 返回统一事件 Dictionary
func parse(raw_line: String) -> Dictionary:
	if raw_line.is_empty():
		return {"type": "empty"}

	var json = JSON.parse_string(raw_line)
	if json == null:
		# 非 JSON 行，可能是纯文本输出
		return {"type": "raw", "text": raw_line}

	return json

## 将 CC 原始事件映射为统一事件
## raw_event: CC stream-json 的单个 JSON 对象
func map_to_unified(raw_event: Dictionary) -> Dictionary:
	match raw_event.get("type", ""):
		"system":
			# system/init 事件包含 session_id
			if raw_event.get("subtype") == "init":
				var result = {"type": "agent_started"}
				if raw_event.has("session_id"):
					result["session_id"] = raw_event["session_id"]
				return result
			elif raw_event.get("subtype") == "api_retry":
				return {"type": "error", "message": raw_event.get("error", ""), "is_retryable": true}
			return {"type": "empty"}

		"stream_event":
			var event = raw_event.get("event", {})
			var delta = event.get("delta", {})
			match delta.get("type", ""):
				"text_delta":
					return {"type": "text_delta", "text": delta.get("text", "")}
				"tool_use":
					return {
						"type": "tool_started",
						"tool_name": delta.get("name", ""),
						"tool_args": delta.get("input", {}),
						"tool_id": delta.get("id", "")
					}
			return {"type": "empty"}

		"user":
			# user message 通常是 tool_result
			var message = raw_event.get("message", {})
			var content = message.get("content", [])
			var tool_name = "unknown"
			var is_error = false
			if content.size() > 0:
				var first_content = content[0]
				if first_content is Dictionary:
					tool_name = first_content.get("tool_use_id", "unknown")
					is_error = first_content.get("is_error", false)
			return {
				"type": "tool_finished",
				"tool_name": tool_name,
				"result": {"content": content, "is_error": is_error}
			}

		"result":
			# 最终结果
			var sub = raw_event.get("subtype", "")
			if sub == "success":
				return {"type": "agent_finished", "result": raw_event.get("result", "")}
			else:
				return {"type": "error", "message": raw_event.get("result", "Unknown error")}

		_:
			return {"type": "empty"}

@tool
class_name PiOutputParser
extends AgentOutputParser

## Pi --mode json 输出解析器
## 将 Pi 的 JSONL 事件流转换为统一事件格式

## 解析一行 Pi JSONL 输出
func parse(raw_line: String) -> Dictionary:
	if raw_line.is_empty():
		return {"type": "empty"}

	var json = JSON.parse_string(raw_line)
	if json == null:
		return {"type": "raw", "text": raw_line}

	return json

## 将 Pi 原始事件映射为统一事件
func map_to_unified(raw_event: Dictionary) -> Dictionary:
	match raw_event.get("type", ""):
		"agent_start":
			var result: Dictionary = {"type": "agent_started"}
			if raw_event.has("session_id"):
				result["session_id"] = raw_event["session_id"]
			return result

		"session":
			if raw_event.has("id"):
				return {"type": "agent_started", "session_id": raw_event["id"]}
			return {"type": "agent_started"}

		"agent_end":
			return {
				"type": "agent_finished",
				"messages": raw_event.get("messages", [])
			}

		"message_update":
			var delta = raw_event.get("assistantMessageEvent", {})
			match delta.get("type", ""):
				"text_delta":
					return {"type": "text_delta", "text": delta.get("delta", "")}
				"thinking_delta":
					return {"type": "text_delta", "text": "[思考] " + delta.get("delta", "")}
				"toolcall_start":
					return {
						"type": "tool_started",
						"tool_name": delta.get("name", ""),
						"tool_args": delta.get("arguments", {})
					}
				"toolcall_end":
					return {
						"type": "tool_finished",
						"tool_name": delta.get("toolCall", {}).get("name", ""),
						"result": delta.get("toolCall", {}).get("output", "")
					}
			return {"type": "empty"}

		"tool_execution_start":
			return {
				"type": "tool_started",
				"tool_name": raw_event.get("toolName", ""),
				"tool_args": raw_event.get("args", {})
			}

		"tool_execution_update":
			return {
				"type": "tool_updated",
				"tool_name": raw_event.get("toolName", ""),
				"partial_output": str(raw_event.get("partialResult", {}))
			}

		"tool_execution_end":
			return {
				"type": "tool_finished",
				"tool_name": raw_event.get("toolName", ""),
				"result": raw_event.get("result", {})
			}

		"extension_error":
			return {
				"type": "error",
				"message": raw_event.get("error", ""),
				"is_retryable": false
			}

		_:
			return {"type": "empty"}

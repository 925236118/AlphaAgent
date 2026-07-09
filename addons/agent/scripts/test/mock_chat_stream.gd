@tool
class_name MockChatStream
extends Node

signal message(msg: String)
signal think(msg: String)
signal generate_finish(finish_reason: String, total_tokens: float)
signal use_tool(tool_calls: Array[AgentModelUtils.ToolCallsInfo])
signal response_use_tool
signal error(error_info: Dictionary)

var generatting: bool = false
var use_thinking: bool = false
var tools: Array = []
var scripted_responses: Array = []
var response_index: int = 0

func queue_text_response(text: String, thinking: String = "") -> void:
	scripted_responses.append({
		"type": "text",
		"text": text,
		"thinking": thinking
	})

func queue_tool_call(tool_name: String, arguments: Dictionary = {}) -> void:
	scripted_responses.append({
		"type": "tool",
		"name": tool_name,
		"arguments": arguments
	})

func queue_error(error_msg: String) -> void:
	scripted_responses.append({
		"type": "error",
		"error_msg": error_msg
	})

func post_message(_messages: Array[Dictionary]) -> void:
	generatting = true
	if response_index >= scripted_responses.size():
		generate_finish.emit("stop", 42)
		generatting = false
		return

	var step = scripted_responses[response_index]
	response_index += 1

	match str(step.get("type", "")):
		"text":
			var thinking_text := str(step.get("thinking", ""))
			if use_thinking and not thinking_text.is_empty():
				think.emit(thinking_text)
			message.emit(str(step.get("text", "")))
			generate_finish.emit("stop", 42)
		"tool":
			var info := AgentModelUtils.ToolCallsInfo.new()
			info.id = "mock_tool_call"
			info.type = "function"
			info.function.name = str(step.get("name", ""))
			info.function.arguments = JSON.stringify(step.get("arguments", {}))
			response_use_tool.emit()
			use_tool.emit([info])
			generate_finish.emit("tool_calls", 42)
		"error":
			error.emit({
				"error_msg": str(step.get("error_msg", "mock error")),
				"data": {}
			})
		_:
			generate_finish.emit("stop", 0)

	generatting = false

func close() -> void:
	generatting = false

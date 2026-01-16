@tool
class_name ReadFileTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "read_file"

func _get_tool_short_description() -> String:
	return "读取文件内容。"

func _get_tool_description() -> String:
	return "读取文件内容。可以指定读取的开始行号和结束行号，默认是1和-1，表示读取到文件末尾。**限制**：此工具最多会读取500行文件内容。返回内容中包含总行数和开始行号和结束行号。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"path": {
				"type": "string",
				"description": "需要读取的文件目录，必须是以res://开头的绝对路径。",
			},
			"start": {
				"type": "integer",
				"description": "需要读取的文件的开始行号，默认是1。",
			},
			"end": {
				"type": "integer",
				"description": "需要读取的文件的结束行号，默认是-1，表示读取到文件末尾。**注意**：返回时不会返回结束行号的内容。",
			}
		},
		"required": ["path", "start", "end"]
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.FILE

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("path") and json.has("start") and json.has("end"):
		var path: String = json.path
		var start: int = json.get("start", 0)
		var end: int = json.get("end", -1)

		var file_string = FileAccess.get_file_as_string(path)
		if file_string == "":
			return {
				"file_path": path,
				"file_uid": ResourceUID.path_to_uid(path),
				"file_content": "",
				"start": 1,
				"end": 1,
				"total_lines": 1
			}

		var file_lines = file_string.split("\n")
		var total_lines = file_lines.size()
		var start_line = max(1, start)
		start_line = min(start_line, total_lines)
		if end == -1:
			end = total_lines
		else:
			end = min(total_lines, end)
		end = min(total_lines + 1, end + 1, start_line + 501)

		var file_content = file_lines.slice(max(start_line - 1, 0), end)
		return {
			"file_path": path,
			"file_uid": ResourceUID.path_to_uid(path),
			"file_content": file_content,
			"start": start_line,
			"end": end,
			"total_lines": total_lines
		}

	return {
		"error": "调用失败。请检查参数是否正确。"
	}

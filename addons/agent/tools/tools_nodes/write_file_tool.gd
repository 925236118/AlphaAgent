@tool
class_name WriteFileTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "write_file"

func _get_tool_short_description() -> String:
	return "全量替换写入文件内容。"

func _get_tool_description() -> String:
	return "全量替换写入文件内容。文件格式应为资源文件(.tres)、Godot着色器(.gdshader)、文本文件(.txt或.md)、CSV文件(.csv)，当明确提及创建或修改文件时再调用该工具。**限制**：不应使用本工具修改脚本和场景文件。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"path": {
				"type": "string",
				"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
			},
			"content": {
				"type": "string",
				"description": "需要写入的文件内容。以\n换行的字符串。"
			}
		},
		"required": ["path", "content"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.FILE

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("path") and json.has("content"):
		var path: String = json.path
		var content = json.content

		# 保存临时文件（用于回滚）
		AgentTempFileManager.get_instance().create_temp_file(path)

		var write_file_err = AgentToolUtils.write_file(path, content)
		if write_file_err == OK:
			if path.get_file().get_extension() == "tscn":
				EditorInterface.reload_scene_from_path(path)
			return {
				"file_path": path,
				"file_uid": ResourceUID.path_to_uid(path),
				"file_content": FileAccess.get_file_as_string(path),
			}

		return {
			"open_error": error_string(FileAccess.get_open_error()),
			"error_msg": error_string(write_file_err)
		}

	return { "error": "调用失败。请检查参数是否正确。" }

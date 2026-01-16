@tool
class_name CreateFolderTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "create_folder"

func _get_tool_short_description() -> String:
	return "创建文件夹。"

func _get_tool_description() -> String:
	return "创建文件夹。在给定的目录下创建一个指定称的空的文件夹。如果不给名称就叫新建文件夹，有重复的就后缀写上（数字）。**限制**：每次创建的文件夹应存在上级文件夹。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"path": {
				"type": "string",
				"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
			}
		},
		"required": ["path"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.FILE

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("path"):
		var path = json.path
		var has_folder = DirAccess.dir_exists_absolute(path)
		if has_folder:
			EditorInterface.get_resource_filesystem().scan()
			return { "error": "文件夹已存在，无需创建" }

		var error = DirAccess.make_dir_absolute(path)
		EditorInterface.get_resource_filesystem().scan()
		if error == OK:
			return { "success": "文件创建成功" }
		return { "error": "文件夹创建失败，%s" % error_string(error) }

	return { "error": "调用失败。请检查参数是否正确。" }

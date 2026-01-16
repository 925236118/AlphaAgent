@tool
class_name CreateScriptTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "create_script"

func _get_tool_short_description() -> String:
	return "通过继承创建脚本文件。"

func _get_tool_description() -> String:
	return "通过继承创建脚本文件。需提供继承的对象类型与所需创建的脚本目录及名称"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"inherits": {
				"type": "string",
				"description": "继承的对象类型，必须是Godot的原声对象类型 或 以res://开头的绝对路径。",
			},
			"path": {
				"type": "string",
				"description": "所需创建的脚本目录。必须是以res://开头并附带脚本名称的绝对路径。"
			}
		},
		"required": ["inherits", "path"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.FILE

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("inherits") and json.has("path"):
		var inherits: String = json.inherits
		var path: String = json.path
		var create_result: bool = await AgentToolUtils.create_script(inherits, path)
		if create_result:
			return {
				"file_path": path,
				"file_uid": ResourceUID.path_to_uid(path),
				"file_content": FileAccess.get_file_as_string(path)
			}
		return {
			"error": "提供的\"inherits\"不存在或是提供的\"path\"已存在脚本文件"
		}

	return { "error": "调用失败。请检查参数是否正确。" }

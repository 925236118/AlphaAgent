@tool
class_name OpenResourceTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "open_resource"

func _get_tool_short_description() -> String:
	return "使用编辑器打开资源文件。"

func _get_tool_description() -> String:
	return "使用Godot编辑器立刻打开或切换到对应资源，资源应是场景文件（.tscn）或脚本文件（.gd）。**依赖**：需要打开的场景或资源文件必须存在。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"path": {
				"type": "string",
				"description": "需要打开的资源路径，必须是以res://开头的绝对路径。",
			},
			"type": {
				"type": "string",
				"enum": ["scene", "script"],
				"description": "打开的类型",
			},
			"line": {
				"type": "number",
				"description": "如果打开的是脚本，可以指定行号， 默认是-1",
			},
			"column": {
				"type": "number",
				"description": "如果打开的是脚本，可以指定列号，默认是0",
			},
		},
		"required": ["path", "type"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.EDITOR

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("path") and json.has("type"):
		var path = json.path
		var type = json.type
		match type:
			"scene":
				EditorInterface.open_scene_from_path(path)
				return { "success": "打开成功" }
			"script":
				var resource = load(path)
				var line = json.get("line", -1)
				var column = json.get("column", 0)
				EditorInterface.edit_script(resource, line, column)
				return { "success": "打开成功" }
			_:
				return { "error": "错误的type类型" }

	return { "error": "调用失败。请检查参数是否正确。" }

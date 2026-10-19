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
				"enum": ["scene", "script", "resource"],
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
				await get_tree().process_frame
				var edited_scene_root = EditorInterface.get_edited_scene_root()
				if edited_scene_root == null or edited_scene_root.get_scene_file_path() != path:
					return { "error": "打开失败：当前编辑场景与目标场景不一致。" }
				return { "success": "打开成功" }
			"script":
				var resource = load(path)
				if resource == null:
					return { "error": "资源加载失败，请检查path是否正确。" }
				if not resource is Script:
					return { "error": "类型错误：script 模式仅支持脚本资源。" }
				var line = json.get("line", -1)
				var column = json.get("column", 0)
				EditorInterface.set_main_screen_editor("Script")
				await get_tree().process_frame
				EditorInterface.edit_script(resource, line, column)
				await get_tree().process_frame
				var current_script = EditorInterface.get_script_editor().get_current_script()
				if current_script == null or current_script.resource_path != path:
					return { "error": "打开失败：当前编辑脚本与目标脚本不一致。" }
				return { "success": "打开成功" }
			"resource":
				var resource = load(path)
				if resource == null:
					return { "error": "资源加载失败，请检查path是否正确。" }
				EditorInterface.edit_resource(resource)
				await get_tree().process_frame
				var edited_object = EditorInterface.get_inspector().get_edited_object()
				if edited_object == null:
					return { "error": "打开失败：Inspector 当前没有编辑对象。" }
				if not edited_object is Resource:
					return {
						"error": "打开失败：Inspector 当前对象不是 Resource。",
						"object_type": edited_object.get_class()
					}
				var edited_resource := edited_object as Resource
				if edited_resource.resource_path != path:
					return {
						"error": "打开失败：Inspector 当前资源路径与目标不一致。",
						"current_path": edited_resource.resource_path,
						"target_path": path
					}
				return { "success": "打开成功" }
			_:
				return { "error": "错误的type类型" }

	return { "error": "调用失败。请检查参数是否正确。" }

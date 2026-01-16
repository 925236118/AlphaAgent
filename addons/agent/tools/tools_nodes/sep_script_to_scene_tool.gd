@tool
class_name SepScriptToSceneTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "sep_script_to_scene"

func _get_tool_short_description() -> String:
	return "将节点上的脚本分离。"

func _get_tool_description() -> String:
	return "将一个节点上的脚本分离，如果需要为节点分离脚本，应优先使用本工具"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"scene_path": {
				"type": "string",
				"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
			},
		},
		"required": ["scene_path"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.SCENE

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("scene_path"):
		var scene_path = json.scene_path
		var has_scene_file = FileAccess.file_exists(scene_path)
		var result: Dictionary = {}
		if has_scene_file:
			var scene_file = ResourceLoader.load(scene_path)
			var root_node = scene_file.instantiate()
			var has_script = root_node.get_script()
			if has_script != null and root_node is PackedScene:
				scene_file.set_script(null)
			else:
				result = { "error": "场景文件并未挂在脚本" }
		else:
			result = { "error": "场景文件不存在，询问是否需要新建该场景" }

		EditorInterface.get_resource_filesystem().scan()
		return result

	return { "error": "调用失败。请检查参数是否正确。" }

@tool
class_name AddScriptToSceneTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "add_script_to_scene"

func _get_tool_short_description() -> String:
	return "将脚本加载到节点上。"

func _get_tool_description() -> String:
	return "将一个脚本加载到节点上，如果需要为节点挂载脚本，应优先使用本工具"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"scene_path": {
				"type": "string",
				"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
			},
			"script_path": {
				"type": "string",
				"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
			}
		},
		"required": ["scene_path","script_path"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.SCENE

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("scene_path") and json.has("script_path"):
		var scene_path = json.scene_path
		var script_path = json.script_path
		var has_scene_file = FileAccess.file_exists(scene_path)
		var has_script_file = FileAccess.file_exists(script_path)
		var result: Dictionary = {}

		if has_scene_file and has_script_file:
			var scene_file = ResourceLoader.load(scene_path)
			var root_node = scene_file.instantiate()
			var has_script = root_node.get_script()
			var script_file = ResourceLoader.load(script_path)
			var script = script_file.new()
			if has_script == null:
				if root_node is PackedScene and script is GDScript:
					scene_file.set_script(script_file)
					var scene_class = scene_file.get_class()
					var script_class = script_file.get_instance_base_type()
					result = {
						"scene_class": scene_class,
						"script_class": script_class,
					}
					if scene_class == script_class:
						result["success"] = "脚本加载成功"
					else:
						result["error"] = "场景节点类型与脚本继承类型不符"
				else:
					result["error"] = "文件非场景节点和脚本的关系"
			else:
				result = { "error": "该场景节点已挂载脚本" }
		else:
			if not has_scene_file:
				result = { "error": "场景文件不存在，询问是否需要新建该场景" }
			if not has_script_file:
				result = { "error": "脚本文件不存在，询问是否需要新建该脚本" }

		EditorInterface.get_resource_filesystem().scan()
		return result

	return { "error": "调用失败。请检查参数是否正确。" }

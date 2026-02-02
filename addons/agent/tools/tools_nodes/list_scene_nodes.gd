@tool
class_name ListSceneNodesTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "list_scene_nodes"

func _get_tool_short_description() -> String:
	return "列出场景中的所有节点信息。"

func _get_tool_description() -> String:
	return "列出某一个场景中的全部节点信息，可以获取到所有节点的NodePath、节点名称、节点属性等。当你需要对某个场景中的某个节点执行操作前，应先调用本文档获取该节点的nodePath。该工具会打开该场景并查看获取需要的信息。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"scene_path": {
				"type": "string",
				"description": "需要列出节点的场景路径，必须是以res://开头的路径。",
			}
		},
		"required": ["scene_path"]
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("scene_path"):
		var scene_path = json.scene_path

		if not scene_path.ends_with(".tscn"):
			return {
				"error": "场景路径不是以.tscn结尾"
			}
		EditorInterface.open_scene_from_path(scene_path)

		var root_node = EditorInterface.get_edited_scene_root()

		var queue = [root_node]
		var node_info = []
		while queue.size() > 0:
			var current_node = queue.pop_front()
			var script = current_node.get_script()
			var script_path = ""
			if script:
				script_path = script.resource_path

			node_info.append({
				"unique_node_path": root_node.get_path_to(current_node, true),
				"node_path": root_node.get_path_to(current_node, false),
				"node_name": current_node.get_name(),
				"node_base_type": current_node.get_class(),
				"script": script_path,
				"parent": root_node.get_path_to(current_node.get_parent(), false)
			})
			var nodes = current_node.get_children()
			for node in nodes:
				queue.push_back(node)

		return {
			"result": node_info
		}

	return {
		"error": "调用失败。请检查参数是否正确。"
	}

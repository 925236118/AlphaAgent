@tool
class_name UpdateSceneNodePropertyTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "update_scene_node_property"

func _get_tool_short_description() -> String:
	return "调用编辑器接口设置场景中的节点的属性。"

func _get_tool_description() -> String:
	return "调用编辑器接口，设置某个场景内的某个节点的某个属性为某个值，可设置的值的类型参照Godot官方文档中Variant.Type枚举值对应类型。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"scene_path": {
				"type": "string",
				"description": "需要打开的场景路径，必须是以res://开头的路径。",
			},
			"node_path": {
				"type": "string",
				"description": "想修改的节点在场景树中的路径。从场景的根节点开始，用“/”分隔。",
			},
			"property_name": {
				"type": "string",
				"description": "想设置的属性的名称。",
			},
			"property_value": {
				"type": "string",
				"description": "想设置的属性的值，该字符串需要能用str_to_var方法还原对应Variant类型值",
			}
		},
		"required": ["scene_path", "node_path", "property_name", "property_value"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.EDITOR

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("scene_path") and json.has("node_path") and json.has("property_name") and json.has("property_value"):
		if AgentToolUtils.update_scene_node_property(json.scene_path, json.node_path, json.property_name, json.property_value):
			return { "success": "属性更新成功" }
		return { "error": "操作失败" }

	return { "error": "调用失败。请检查参数是否正确。" }

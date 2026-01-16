@tool
class_name SetResourcePropertyTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "set_resource_property"

func _get_tool_short_description() -> String:
	return "调用编辑器接口设置资源属性。"

func _get_tool_description() -> String:
	return "写入资源文件，并将其引用为某个场景内的某个节点的某个属性。"

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
			"property_path": {
				"type": "string",
				"description": "想设置的属性的路径，注意对于shader文件等可能会嵌套在其他资源内的属性，这个路径应该为material/shader，即格式为‘节点属性/资源属性/.../目标属性’",
			},
			"resource_path": {
				"type": "string",
				"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
			},
			"content": {
				"type": "string",
				"description": "需要写入的文件内容",
			}
		},
		"required": ["scene_path", "node_path", "property_path", "resource_path", "content"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.EDITOR

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("scene_path") and json.has("node_path") and json.has("property_path") and json.has("resource_path") and json.has("content"):
		# 保存临时文件（用于回滚）
		AgentTempFileManager.get_instance().create_temp_file(json.resource_path)

		var write_file_err = AgentToolUtils.write_file(json.resource_path, json.content)
		if write_file_err == OK:
			if AgentToolUtils.set_resource_property(json.resource_path, json.scene_path, json.node_path, json.property_path):
				return { "success": "更新成功" }
			return { "error": "资源挂载失败" }

		return {
			"error": "资源写入失败",
			"error_msg": error_string(write_file_err)
		}

	return { "error": "调用失败。请检查参数是否正确。" }

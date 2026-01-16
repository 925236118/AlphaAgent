@tool
class_name SetSingletonTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "set_singleton"

func _get_tool_short_description() -> String:
	return "调用编辑器接口设置自动加载脚本或场景。"

func _get_tool_description() -> String:
	return "设置或删除项目自动加载脚本或场景"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"name": {
				"type": "string",
				"description": "需要设置的自动加载名称，需要以大驼峰的方式命名。一般可以和脚本或场景文件同名。**依赖**：设置的自动加载脚本或场景文件必须存在。且不能和已有的自动加载名称重复。",
			},
			"path": {
				"type": "string",
				"description": "需要设置为自动加载的脚本或场景路径，必须是以res://开头的绝对路径。如果为空时则会删除该自动加载。**依赖**：设置的自动加载脚本或场景文件必须存在。",
			},
		},
		"required": ["name"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.EDITOR

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("name"):
		var singleton_name = json.name
		var singleton_path = json.get("path", "")
		if singleton_path:
			var singleton = AlphaAgentSingleton.get_instance()
			singleton.add_autoload_singleton(singleton_name, singleton_path)
			return {
				"name": singleton_name,
				"path": singleton_path,
				"success": "添加自动加载成功"
			}
		else:
			var singleton = AlphaAgentSingleton.get_instance()
			singleton.remove_autoload_singleton(singleton_name)
			return {
				"name": singleton_name,
				"success": "删除自动加载成功"
			}

	return { "error": "调用失败。请检查参数是否正确。" }

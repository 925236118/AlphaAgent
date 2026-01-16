@tool
@abstract
class_name AgentToolBase
extends Node

var tool_name: String = "":
	get: return _get_tool_name()
var tool_description: String = "":
	get: return _get_tool_description()
var tool_readonly: bool = false:
	get: return _get_tool_readonly()
var tool_group: ToolGroup = ToolGroup.QUERY:
	get: return _get_tool_group()
var tool_short_description: String = "":
	get: return _get_tool_short_description()

enum ToolGroup {
	QUERY, # 查询操作
	FILE,   # 文件操作
	SCENE, # 场景操作
	EDITOR, # 编辑器操作
	COMMAND, # 命令行操作
	DEBUG, # 调试操作
}

const TOOL_GROUP_NAMES = {
	ToolGroup.QUERY: "查询操作",
	ToolGroup.FILE: "文件操作",
	ToolGroup.SCENE: "场景操作",
	ToolGroup.EDITOR: "编辑器操作",
	ToolGroup.COMMAND: "命令行操作",
	ToolGroup.DEBUG: "调试操作",
}


@abstract
func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary


@abstract
func _get_tool_name() -> String

@abstract
func _get_tool_description() -> String

@abstract
func _get_tool_short_description() -> String

@abstract
func _get_tool_parameters() -> Dictionary

@abstract
func _get_tool_readonly() -> bool

@abstract
func _get_tool_group() -> ToolGroup

func get_tool_func_description() -> Dictionary:
	return {
		"type": "function",
		"function": {
			"name": tool_name,
			"description": _get_tool_description(),
			"parameters": _get_tool_parameters()
		}
	}

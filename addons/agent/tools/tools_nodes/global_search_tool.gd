@tool
class_name GlobalSearchTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "global_search"

func _get_tool_short_description() -> String:
	return "全局搜索脚本文件。"

func _get_tool_description() -> String:
	return "全局搜索脚本文件。必须指定需要搜索的内容text，如果希望指定路径搜索则必须指定res://开头的绝对路径，目前默认只能搜索.gd后缀文件。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"text": {
				"type": "string",
				"description": "需要搜索的关键字，不得使用诸如func, return, if 等gds原生关键字，不能为空。",
			},
			"path": {
				"type": "string",
				"description": "需要查找的文件目录，要么为\"\"，要么必须是以res://开头的绝对路径。",
			}
		},
		"required": ["text"]
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("text"):
		var text = json.text
		var path = json.get("path", "res://")
		var search_results = []
		search_results = await AgentToolUtils.search_recursive(text, search_results, path)
		return {
			"result": search_results
		}

	return {
		"error": "调用失败。请检查参数是否正确。"
	}

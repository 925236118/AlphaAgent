@tool
class_name AgentTools
extends Node

var tool_map: Dictionary[String, AgentToolBase] = {}

func _ready():
	register_tools()

func register_tools():
	var tools = get_children()
	for tool_node in tools:
		if tool_node is AgentToolBase:
			tool_map.set(tool_node.tool_name, tool_node)

# 获取工具名称列表
func get_function_name_list():
	var function_name_list: Dictionary = {}
	for tool_name in tool_map.keys():
		function_name_list.set(tool_name, {
			"readonly": tool_map[tool_name].tool_readonly,
			"group": tool_map[tool_name].tool_group,
			"description": tool_map[tool_name].tool_short_description
		})
	return function_name_list

# 获取筛选后的工具列表
func get_filtered_tools_list(filter_list: Array) -> Array[Dictionary]:
	return get_tools_list().filter(func(tool: Dictionary) -> bool:
		return filter_list.has(tool.function.name)
	)

func get_readonly_tools_list() -> Array[Dictionary]:
	return get_tools_list().filter(func(tool: Dictionary) -> bool:
		var tool_name: String = tool.function.name
		return tool_map.has(tool_name) and tool_map[tool_name].tool_readonly
	)

func is_tool_readonly(tool_name: String) -> bool:
	return tool_map.has(tool_name) and tool_map[tool_name].tool_readonly

const MAX_TOOL_OUTPUT_CHARS := 12000

func truncate_tool_output(content: String) -> String:
	if content.length() <= MAX_TOOL_OUTPUT_CHARS:
		return content
	return content.substr(0, MAX_TOOL_OUTPUT_CHARS) + "\n...[输出已截断]"

# 获取工具列表
func get_tools_list() -> Array[Dictionary]:
	var tools_list: Array[Dictionary] = []
	for tool_name in tool_map.keys():
		tools_list.push_back(tool_map[tool_name].get_tool_func_description())
	return tools_list

# 使用工具
func use_tool(tool_call: AgentModelUtils.ToolCallsInfo) -> String:
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.emit_before_tool_call(tool_call)

	for interceptor in singleton.tool_call_interceptors:
		if interceptor.is_valid() and interceptor.call(tool_call):
			var intercepted := JSON.stringify({"intercepted": true})
			singleton.emit_after_tool_call(tool_call, intercepted)
			return intercepted

	var result = {}
	var function_name = tool_call.function.name
	if tool_map.has(function_name):
		result = await tool_map[function_name].do_action(tool_call)
	else:
		result = {
			"error": "错误的function.name"
		}
	var output := truncate_tool_output(JSON.stringify(result))
	singleton.emit_after_tool_call(tool_call, output)
	return output

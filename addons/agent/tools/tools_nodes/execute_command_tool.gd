@tool
class_name ExecuteCommandTool
extends AgentToolBase

var thread: Thread = null

func _get_tool_name() -> String:
	return "execute_command"

func _get_tool_short_description() -> String:
	return "执行命令行命令。"

func _get_tool_description() -> String:
	return "创建一个独立于 Godot 运行的命令行工具，该工具运行在项目目录下。调用本工具需要提醒用户，以防止造成无法预料的后果。**限制**：需要预先知道当前的系统。windows中使用的是cmd命令。linux中使用的是bash命令。不要出现当前系统下没有的命令。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"command": {
				"type": "string",
				"description": "需要执行的命令名称，不需要指定bash或者cmd，可以直接输入命令名称。",
			},
			"args": {
				"type": "array",
				"description": "需要执行的命令的参数，会按给定顺序执行。不需要/c或者-Command参数。",
			}
		},
		"required": ["command", "args"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.COMMAND

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("command") and json.has("args"):
		var is_timeout: bool = false
		thread = Thread.new()
		thread.start(AgentToolUtils.execute_command.bind(json.command, json.args))
		while not thread.is_started():
			await get_tree().process_frame

		get_tree().create_timer(30.0).timeout.connect(func():
			if thread and thread.is_alive():
				is_timeout = true
				thread = Thread.new()
		)

		while thread.is_alive():
			await get_tree().process_frame

		if is_timeout or !thread.is_started():
			thread = null
			return { "error": "命令行执行因超时停止" }

		var command_result = thread.wait_to_finish()
		thread = null
		return command_result

	return { "error": "调用失败。请检查参数是否正确。" }

func _exit_tree() -> void:
	if thread != null:
		thread.wait_to_finish()
		thread = null

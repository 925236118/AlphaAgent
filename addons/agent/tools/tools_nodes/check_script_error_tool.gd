@tool
class_name CheckScriptErrorTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "check_script_error"

func _get_tool_short_description() -> String:
	return "检查脚本中的语法错误。"

func _get_tool_description() -> String:
	return "使用Godot脚本引擎检查脚本中的语法错误，只能检查gd脚本。**依赖**：需要检查的脚本文件必须存在。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"path": {
				"type": "string",
				"description": "需要检查的脚本路径，必须是以res://开头的绝对路径。",
			},
		},
		"required": ["name"]
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.DEBUG

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("path"):
		var log_file_path = AlphaAgentPlugin.project_alpha_dir + "check_script.temp"
		var path = json.path
		if FileAccess.file_exists(log_file_path):
			DirAccess.remove_absolute(log_file_path)

		var instance_pid = OS.create_instance(["--head-less", "--script", path, "--check-only", "--log-file", log_file_path])

		await get_tree().create_timer(3.0).timeout
		OS.kill(instance_pid)

		var script_check_result = FileAccess.get_file_as_string(log_file_path)
		DirAccess.remove_absolute(log_file_path)

		return {
			"script_path": path,
			"script_check_result": script_check_result
		}

	return { "error": "调用失败。请检查参数是否正确。" }

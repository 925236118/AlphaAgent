@tool
class_name CheckScriptErrorTool
extends AgentToolBase

const CHECK_TIMEOUT_SECONDS := 8.0
const POLL_INTERVAL_SECONDS := 0.1

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
		"required": ["path"]
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.DEBUG

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if json != null and json.has("path"):
		var path: String = str(json.path)
		if not path.begins_with("res://"):
			return { "error": "调用失败。path 必须是以 res:// 开头的脚本路径。" }
		if not FileAccess.file_exists(path):
			return { "error": "调用失败。脚本不存在：%s" % path }

		var log_file_path := _build_log_path()
		_ensure_parent_dir(log_file_path)
		if FileAccess.file_exists(log_file_path):
			DirAccess.remove_absolute(log_file_path)

		var syntax_check := await _run_external_syntax_check(path, log_file_path)
		var static_check := _run_static_parse_check(path)
		var combined_result := _merge_result_text(
			str(syntax_check.get("result_text", "")),
			str(static_check.get("result_text", ""))
		)

		if FileAccess.file_exists(log_file_path):
			DirAccess.remove_absolute(log_file_path)

		return {
			"script_path": path,
			# 保留旧字段，兼容已有调用方
			"script_check_result": combined_result,
			"syntax_check": syntax_check,
			"static_check": static_check,
			"combined_result": combined_result
		}

	return { "error": "调用失败。请检查参数是否正确。" }

func _build_log_path() -> String:
	return AlphaAgentPlugin.global_setting.project_alpha_dir + "check_script.temp.log"

func _ensure_parent_dir(file_path: String) -> void:
	var parent_dir := file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)

func _run_external_syntax_check(path: String, log_file_path: String) -> Dictionary:
	var args := PackedStringArray([
		"--headless",
		"--script",
		path,
		"--check-only",
		"--log-file",
		log_file_path
	])
	var pid := OS.create_instance(args)
	if pid <= 0:
		return {
			"ok": false,
			"phase": "syntax",
			"result_text": "语法检查启动失败（无法创建子进程）。",
			"process_pid": pid,
		}

	var elapsed := 0.0
	while OS.is_process_running(pid) and elapsed < CHECK_TIMEOUT_SECONDS:
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		elapsed += POLL_INTERVAL_SECONDS

	var timeout := OS.is_process_running(pid)
	if timeout:
		OS.kill(pid)

	var log_info := _read_log_file_result(log_file_path)
	var text := str(log_info.get("text", "")).strip_edges()
	if timeout and text == "":
		text = "语法检查超时（%.1fs），且未生成可用日志。" % CHECK_TIMEOUT_SECONDS
	elif text == "":
		text = "代码没有语法错误"

	return {
		"ok": not timeout and not bool(log_info.get("read_error", false)),
		"phase": "syntax",
		"timed_out": timeout,
		"process_pid": pid,
		"log_path": log_file_path,
		"log_exists": bool(log_info.get("exists", false)),
		"result_text": text,
	}


func _run_static_parse_check(path: String) -> Dictionary:
	var source_code := FileAccess.get_file_as_string(path)
	if FileAccess.get_open_error() != OK:
		return {
			"ok": false,
			"phase": "static",
			"result_text": "静态检查失败：无法读取脚本内容。"
		}
	var script:GDScript=ResourceLoader.load(path,"GDScript",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if script==null:
		return {
			"ok": false,
			"phase": "static",
			"result_text": "静态检查失败：无法装载脚本。"
		}
	
	var reload_error := script.reload()
	
	return {
		"ok": reload_error == OK,
		"phase": "static",
		"error_code": reload_error,
		"result_text": "代码没有静态解析错误" if reload_error == OK else "静态解析失败：%s" % error_string(reload_error)
	}


func _read_log_file_result(log_file_path: String) -> Dictionary:
	if not FileAccess.file_exists(log_file_path):
		return {
			"exists": false,
			"read_error": false,
			"text": ""
		}

	var text := FileAccess.get_file_as_string(log_file_path)
	var open_error := FileAccess.get_open_error()
	if open_error != OK:
		return {
			"exists": true,
			"read_error": true,
			"text": "日志读取失败：%s" % error_string(open_error)
		}

	return {
		"exists": true,
		"read_error": false,
		"text": text
	}

func _merge_result_text(syntax_text: String, static_text: String) -> String:
	var syntax_line := syntax_text.strip_edges()
	var static_line := static_text.strip_edges()

	if syntax_line == "":
		syntax_line = "语法检查结果为空"
	if static_line == "":
		static_line = "静态检查结果为空"

	if syntax_line == "代码没有语法错误" and static_line == "代码没有静态解析错误":
		return "代码没有语法和静态解析错误"

	return "[语法检查]\n%s\n\n[静态检查]\n%s" % [syntax_line, static_line]

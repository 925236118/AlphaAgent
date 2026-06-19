@tool
class_name CCChecker
extends AgentChecker

## Claude Code（CC）可用性检测器
## 检测 claude CLI 是否安装、是否可执行、版本号

var cc_path: String = ""
var cc_version: String = ""

const CLI_NAME: String = "claude"

## 执行检测：where/which → --version
func check() -> bool:
	# Step 1: 查找命令路径（验证 PATH 中存在）
	var find_output: Array = []
	var found = _find_in_path(CLI_NAME, find_output)
	if not found:
		error_message = "未找到 %s 命令。请确保 Claude Code 已安装并在 PATH 中。" % CLI_NAME
		return false

	cc_path = _pick_best_path(find_output)

	# Step 2: 执行 --version（Windows 走 cmd.exe /c 以确保 PATH 解析正确）
	var version_output: Array = []
	var exit_code = _exec_version(version_output)
	if exit_code != 0:
		error_message = "%s --version 执行失败 (exit code: %d)。" % [CLI_NAME, exit_code]
		return false

	cc_version = version_output[0].strip_edges() if version_output.size() > 0 else "unknown"
	is_available = true
	return true

func get_agent_name() -> String:
	return "Claude Code"

func get_status_text() -> String:
	if is_available:
		return "✅ CC 就绪: %s (v%s)" % [cc_path, cc_version]
	else:
		return "❌ CC 不可用: %s" % error_message

# -- 内部 --

func _find_in_path(name: String, out: Array) -> bool:
	if OS.get_name() == "Windows":
		return OS.execute("cmd.exe", PackedStringArray(["/c", "where " + name]), out, true) == 0
	else:
		return OS.execute("which", PackedStringArray([name]), out, true) == 0

func _exec_version(out: Array) -> int:
	if OS.get_name() == "Windows":
		return OS.execute("cmd.exe", PackedStringArray(["/c", CLI_NAME + " --version"]), out, true)
	else:
		return OS.execute(CLI_NAME, PackedStringArray(["--version"]), out, true)

func _pick_best_path(paths: Array) -> String:
	if paths.is_empty():
		return ""
	# Windows: 优先选 .cmd / .exe 版本
	if OS.get_name() == "Windows":
		for p in paths:
			var s = str(p).strip_edges()
			if s.ends_with(".cmd") or s.ends_with(".exe"):
				return s
	return str(paths[0]).strip_edges()

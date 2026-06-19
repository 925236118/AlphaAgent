@tool
class_name PiChecker
extends AgentChecker

## Pi Coding Agent 可用性检测器
## 检测 pi CLI 是否安装、是否可执行、版本号

var pi_path: String = ""
var pi_version: String = ""

const CLI_NAME: String = "pi"

## 执行检测：where/which → --version
func check() -> bool:
	# Step 1: 查找命令路径（验证 PATH 中存在）
	var find_output: Array = []
	var found = _find_in_path(CLI_NAME, find_output)
	if not found:
		error_message = "未找到 %s 命令。请确保 Pi 已安装并在 PATH 中。" % CLI_NAME
		error_message += "\n安装: npm install -g @earendil-works/pi-coding-agent"
		return false

	pi_path = _pick_best_path(find_output)

	# Step 2: 执行 --version（Windows 走 cmd.exe /c 以确保 PATH 解析正确）
	var version_output: Array = []
	var exit_code = _exec_version(version_output)
	if exit_code != 0:
		error_message = "%s --version 执行失败 (exit code: %d)。" % [CLI_NAME, exit_code]
		return false

	pi_version = version_output[0].strip_edges() if version_output.size() > 0 else "unknown"
	is_available = true
	return true

func get_agent_name() -> String:
	return "Pi"

func get_status_text() -> String:
	if is_available:
		return "✅ Pi 就绪: %s (v%s)" % [pi_path, pi_version]
	else:
		return "❌ Pi 不可用: %s" % error_message

# -- 内部 --

func _find_in_path(name: String, out: Array) -> bool:
	if OS.get_name() == "Windows":
		return OS.execute("cmd.exe", PackedStringArray(["/c", "where " + name]), out, true) == 0
	else:
		return OS.execute("which", PackedStringArray([name]), out, true) == 0

func _exec_version(out: Array) -> int:
	if OS.get_name() == "Windows":
		# cmd.exe /c 让 shell 解析 PATH，避免 Godot OS.execute 找不到 npm 全局命令
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

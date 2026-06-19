@tool
class_name PiAdapter
extends AgentAdapter

## Pi Coding Agent Adapter
## 实现 AgentAdapter 接口，将 Pi 的 --mode json JSONL 输出映射为统一事件
##
## Pi Session 模型（与 CC 的对比）:
##   - Pi: --session <id> 续接已有 session；--fork <id> 分叉到新 session
##   - CC: --session-id <id> 续接已有 session
##   - 修复循环：Pi 同 session 内重试（--session）；CC 同 session 内重试（--session-id）
##   - 新步骤：Pi 不传 session 参数（新建）；或 --fork 从当前分叉
##   - Ctrl+C: Pi 直接 OS.kill()，session 文件已持久化在磁盘

var process_manager: PiProcessManager = null
var output_parser: PiOutputParser = null
var _checker: PiChecker = null
var _session_id: String = ""
var _current_step_index: int = -1

func _init() -> void:
	_checker = PiChecker.new()
	output_parser = PiOutputParser.new()

# -- 生命周期 --

func check_availability() -> bool:
	return _checker.check()

func start() -> bool:
	process_manager = PiProcessManager.new()
	return process_manager.start()

func terminate() -> void:
	if process_manager:
		process_manager.kill()

# -- 对话控制 --

func send_prompt(prompt: String) -> void:
	# Step 1: 写入临时文件
	var tmp_file = "user://.alpha/pi_temp_prompt.txt"
	var dir_path = "user://.alpha/"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(dir_path))

	var file = FileAccess.open(tmp_file, FileAccess.WRITE)
	if file:
		file.store_string(prompt)
		file.close()

	var abs_path = ProjectSettings.globalize_path(tmp_file)

	# Step 2: 构造平台管道命令（含 session 选项）
	var pi_args = "--mode json"
	if not _session_id.is_empty():
		pi_args += ' --session "%s"' % _session_id

	var command: String
	match OS.get_name():
		"Windows":
			command = 'type "%s" | pi %s\n' % [abs_path, pi_args]
		"Linux", "macOS":
			command = 'cat "%s" | pi %s\n' % [abs_path, pi_args]
		_:
			command = 'cat "%s" | pi %s\n' % [abs_path, pi_args]

	# Step 3: 发送给 Pi
	process_manager.write_to_stdin(command)

func abort() -> void:
	# Pi session 已持久化在磁盘，直接终止进程即可
	if process_manager:
		process_manager.kill()

# -- 输出读取 --

func read_event() -> Dictionary:
	if not process_manager:
		return {"type": "empty"}

	var raw = process_manager.read_line()
	if raw.is_empty():
		return {"type": "empty"}

	var event = output_parser.parse(raw)
	if event.get("type") == "raw":
		return event

	var unified = output_parser.map_to_unified(event)

	# 捕获 session_id（Pi 在 agent_start 或 session 事件中返回）
	if unified.get("type") == "agent_started" and event.has("session_id"):
		_session_id = event["session_id"]

	return unified

func has_exited() -> bool:
	if not process_manager:
		return true
	return not process_manager.is_running()

func get_exit_code() -> int:
	if process_manager:
		return process_manager.get_exit_code()
	return -1

# -- Session 管理 --

func supports_session() -> bool:
	return true

func get_session_id() -> String:
	return _session_id

func resume_session(session_id: String) -> void:
	if not session_id.is_empty():
		_session_id = session_id

func start_new_step(step_index: int) -> void:
	_current_step_index = step_index
	_session_id = ""  # 新步骤 = 新 session，Pi 自动创建

# -- 信息获取 --

func get_agent_name() -> String:
	return "Pi"

func get_agent_version() -> String:
	return _checker.pi_version

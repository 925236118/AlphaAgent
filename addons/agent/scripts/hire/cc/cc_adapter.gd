@tool
class_name CCAdapter
extends AgentAdapter

## Claude Code (CC) Adapter
## 实现 AgentAdapter 接口，将 CC 的 stream-json 输出映射为统一事件

var process_manager: CCProcessManager = null
var output_parser: CCOutputParser = null
var session_manager: CCSessionManager = null
var controller: CCProcessController = null
var _checker: CCChecker = null

# 当前步骤索引
var _current_step_index: int = -1

func _init() -> void:
	_checker = CCChecker.new()
	output_parser = CCOutputParser.new()
	session_manager = CCSessionManager.new()

# -- 生命周期 --

func check_availability() -> bool:
	return _checker.check()

func start() -> bool:
	process_manager = CCProcessManager.new()
	var ok = process_manager.start()
	if ok:
		controller = CCProcessController.new(process_manager)
	return ok

func terminate() -> void:
	if controller:
		controller.terminate()
	if process_manager:
		process_manager.close_all()

# -- 对话控制 --

func send_prompt(prompt: String) -> void:
	# supports_session() 是 AgentAdapter 的方法，调用自身而非 session_manager
	var is_new = not supports_session() or session_manager.get_session_id().is_empty()
	CCPromptFileWriter.write_and_send(prompt, session_manager.get_session_id(), is_new, process_manager)

func abort() -> void:
	if controller:
		controller.pause()

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

	# 映射为统一事件
	var unified = output_parser.map_to_unified(event)

	# 捕获 session_id
	if unified.get("type") == "agent_started" and unified.has("session_id"):
		session_manager.capture_session_id(unified)

	return unified

func has_exited() -> bool:
	if not process_manager:
		return true
	return not process_manager.is_running()

func get_exit_code() -> int:
	if process_manager:
		return process_manager.get_exit_code()
	return -1

# -- 上下文管理 --

func supports_session() -> bool:
	return true

func get_session_id() -> String:
	return session_manager.get_session_id()

func resume_session(session_id: String) -> void:
	# 记录 session_id，CCProcessManager 会在 start() 时创建新的 shell 进程
	# 实际的 --session-id 参数在 send_prompt 时通过 CCPromptFileWriter 传入
	if not session_id.is_empty():
		session_manager._current_session_id = session_id

# -- 新的步骤 --

func start_new_step(step_index: int) -> void:
	_current_step_index = step_index
	session_manager.start_new_step(step_index)

# -- 信息获取 --

func get_agent_name() -> String:
	return "Claude Code"

func get_agent_version() -> String:
	return _checker.cc_version

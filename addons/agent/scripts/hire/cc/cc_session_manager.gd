@tool
class_name CCSessionManager
extends RefCounted

## CC Session 管理器
## 管理 CC 的 session_id 生命周期
## 注意: session_id 由 CC 在首次对话的 system/init 事件中返回，不是 Alpha 自行生成的

var _current_session_id: String = ""
var _session_step_index: int = -1

## 从 CC 的 system/init 事件中捕获 session_id
func capture_session_id(event: Dictionary) -> bool:
	if event.get("type") == "agent_started" and event.has("session_id"):
		_current_session_id = event["session_id"]
		return true
	return false

## 检查当前 session 是否属于指定步骤
func is_same_step(step_index: int) -> bool:
	return step_index == _session_step_index and not _current_session_id.is_empty()

## 获取当前 session_id
func get_session_id() -> String:
	return _current_session_id

## 开始新步骤的 session（清除旧 session_id，等待 CC 返回新的）
func start_new_step(step_index: int) -> void:
	_session_step_index = step_index
	_current_session_id = ""  # 重置，等待 CC 返回新 session_id

## 构建 CC 启动参数（是否带 --session-id）
func build_cc_args(is_fix: bool, verbose: bool = true) -> String:
	var args = "--output-format stream-json"
	if verbose:
		args += " --verbose"
	if is_fix and not _current_session_id.is_empty():
		args += ' --session-id "%s"' % _current_session_id
	return args

## 重置所有状态
func reset() -> void:
	_current_session_id = ""
	_session_step_index = -1

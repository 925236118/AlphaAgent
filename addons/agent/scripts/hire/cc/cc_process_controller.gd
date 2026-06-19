@tool
class_name CCProcessController
extends RefCounted

## CC 进程控制器 — 实现 Ctrl+C 四级回退策略
##
## Level 1: 写入 \x03 (ETX/ Ctrl+C ASCII) 到 stdin 管道
## Level 2: 平台信号 kill -INT (仅 Linux/macOS)
## Level 3: 关闭 stdin 发送 EOF
## Level 4: OS.kill() 强制终止

var _process_manager: CCProcessManager
const LEVEL_TIMEOUT: float = 2.0  # 每级等待秒数

func _init(pm: CCProcessManager) -> void:
	_process_manager = pm

## 暂停（Ctrl+C）— 尝试四级回退
func pause() -> bool:
	if not _process_manager or not _process_manager.is_running():
		return true

	# Level 1: 写入 ETX (Ctrl+C 的 ASCII 码，十进制 3)
	_process_manager.write_to_stdin(String.chr(3))
	await _wait_and_check(LEVEL_TIMEOUT)
	if not _process_manager.is_running():
		return true

	# Level 2: 平台特定信号（仅 Linux/macOS）
	if OS.get_name() in ["Linux", "macOS"]:
		var pid = _process_manager.get_pid()
		OS.execute("kill", ["-INT", str(pid)])
		await _wait_and_check(LEVEL_TIMEOUT)
		if not _process_manager.is_running():
			return true

	# Level 3: 关闭 stdin 发送 EOF
	_process_manager.close_stdin()
	await _wait_and_check(LEVEL_TIMEOUT)
	if not _process_manager.is_running():
		return true

	# Level 4: 强制终止
	OS.kill(_process_manager.get_pid())
	return true

## 终止 — 直接跳到 Level 3（关闭 stdin）
func terminate() -> bool:
	if not _process_manager or not _process_manager.is_running():
		return true

	# 关闭 stdin
	_process_manager.close_stdin()
	await _wait_and_check(LEVEL_TIMEOUT)
	if not _process_manager.is_running():
		return true

	# 强制终止
	OS.kill(_process_manager.get_pid())
	return true

## 等待指定时间，检查进程是否仍在运行
func _wait_and_check(timeout: float) -> void:
	var elapsed: float = 0.0
	var tree = AlphaAgentSingleton.get_instance().get_scene_tree()
	if tree == null:
		return

	while elapsed < timeout and _process_manager.is_running():
		await tree.create_timer(0.1).timeout
		elapsed += 0.1

@tool
class_name CCProcessManager
extends AgentProcessManager

## CC 子进程生命周期管理器
## 负责创建 shell 子进程、管理 stdin/stdout/stderr 管道
##
## Windows 使用 cmd.exe，Linux/macOS 使用 /bin/sh

var _stdio: FileAccess = null
var _stderr: FileAccess = null
var _pid: int = -1
var _shell_path: String = ""

## 启动 shell 子进程
## 返回 true 表示成功
func start() -> bool:
	match OS.get_name():
		"Windows":
			_shell_path = "cmd.exe"
		"Linux", "macOS":
			_shell_path = "/bin/sh"
		_:
			push_error("CCProcessManager: 不支持的操作系统 %s" % OS.get_name())
			return false

	var result = OS.execute_with_pipe(_shell_path, PackedStringArray(), false)
	if not result or result.is_empty():
		push_error("CCProcessManager: 无法启动 shell 子进程")
		return false

	_stdio = result.get("stdio")
	_stderr = result.get("stderr")
	_pid = result.get("pid")
	return true

## 向子进程 stdin 写入数据
func write_to_stdin(data: String) -> void:
	if _stdio:
		_stdio.store_string(data)

## 非阻塞读取 stdout 的一行
## 返回空字符串表示暂无数据
func read_line() -> String:
	if not _stdio or _stdio.eof_reached():
		return ""
	return _stdio.get_line()

## 获取当前可用的所有输出（非阻塞）
func read_all() -> String:
	if not _stdio or _stdio.eof_reached():
		return ""
	return _stdio.get_as_text()

## 获取错误输出
func read_stderr() -> String:
	if not _stderr or _stderr.eof_reached():
		return ""
	return _stderr.get_as_text()

## 关闭 stdin 管道（发送 EOF 信号）
func close_stdin() -> void:
	if _stdio:
		_stdio.close()
		_stdio = null

## 关闭所有管道
func close_all() -> void:
	close_stdin()
	if _stderr:
		_stderr.close()
		_stderr = null

## 进程是否在运行
func is_running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid)

## 获取进程 PID
func get_pid() -> int:
	return _pid

## 获取退出码
func get_exit_code() -> int:
	return OS.get_process_exit_code(_pid) if _pid > 0 else -1

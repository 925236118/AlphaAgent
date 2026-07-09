@tool
class_name PiProcessManager
extends AgentProcessManager

## Pi 子进程生命周期管理器
## 与 CCProcessManager 类似，但 Pi 每次执行完后自动退出，无需维护长连接 Session
##
## 非阻塞读取：使用内部缓冲 + get_buffer() 实现真正的非阻塞逐行读取。

var _stdio: FileAccess = null
var _stderr: FileAccess = null
var _pid: int = -1
var _shell_path: String = ""
var _read_buffer: String = ""  ## 非阻塞读取的内部缓冲区

## 启动 shell 子进程
func start() -> bool:
	match OS.get_name():
		"Windows":
			_shell_path = "cmd.exe"
		"Linux", "macOS":
			_shell_path = "/bin/sh"
		_:
			push_error("PiProcessManager: 不支持的操作系统 %s" % OS.get_name())
			return false

	var result = OS.execute_with_pipe(_shell_path, PackedStringArray(), false)
	if not result or result.is_empty():
		push_error("PiProcessManager: 无法启动 shell 子进程")
		return false

	_stdio = result.get("stdio")
	_stderr = result.get("stderr")
	_pid = result.get("pid")
	return true

## 向子进程 stdin 写入数据
func write_to_stdin(data: String) -> void:
	if _stdio:
		_stdio.store_string(data)

## 真·非阻塞读取 stdout 的一行
## 使用内部缓冲 + get_buffer() 避免 get_line() 的阻塞行为
func read_line() -> String:
	if not _stdio or _stdio.eof_reached():
		if not _read_buffer.is_empty():
			var remaining = _read_buffer
			_read_buffer = ""
			return remaining
		return ""

	var chunk = _stdio.get_buffer(4096)
	if not chunk.is_empty():
		_read_buffer += chunk.get_string_from_utf8()

	var newline_idx = _read_buffer.find("\n")
	if newline_idx >= 0:
		var line = _read_buffer.substr(0, newline_idx).strip_edges(false, true)
		_read_buffer = _read_buffer.substr(newline_idx + 1)
		return line

	return ""

## 获取错误输出
func read_stderr() -> String:
	if not _stderr or _stderr.eof_reached():
		return ""
	return _stderr.get_as_text()

## 关闭所有管道
func close_all() -> void:
	if _stdio:
		_stdio.close()
		_stdio = null
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

## 终止进程
func kill() -> void:
	if _pid > 0:
		OS.kill(_pid)
	close_all()

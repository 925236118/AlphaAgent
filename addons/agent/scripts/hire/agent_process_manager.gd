@tool
@abstract
class_name AgentProcessManager
extends RefCounted

## Agent 子进程生命周期管理器 — 抽象基类
## CCProcessManager / PiProcessManager 的公共接口

## 启动 shell 子进程，返回 true 表示成功
@abstract
func start() -> bool

## 向子进程 stdin 写入数据
@abstract
func write_to_stdin(data: String) -> void

## 非阻塞读取 stdout 的一行，返回空字符串表示暂无数据
@abstract
func read_line() -> String

## 关闭所有管道
@abstract
func close_all() -> void

## 进程是否在运行
@abstract
func is_running() -> bool

## 获取进程 PID — 有默认实现
func get_pid() -> int:
	return -1

## 获取退出码 — 有默认实现
func get_exit_code() -> int:
	return -1

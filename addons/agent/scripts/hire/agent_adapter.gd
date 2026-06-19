@tool
@abstract
class_name AgentAdapter
extends RefCounted

## Agent 统一抽象基类
## 所有外部 Agent（CC、Pi 等）的 Adapter 必须继承此类
## 封装了进程管理、事件解析、Session 控制等通用接口

# -- 生命周期（抽象，子类必须实现） --

@abstract
func check_availability() -> bool

@abstract
func start() -> bool

@abstract
func terminate() -> void

# -- 对话控制（抽象，子类必须实现） --

@abstract
func send_prompt(prompt: String) -> void

@abstract
func abort() -> void

# -- 输出读取（抽象，子类必须实现） --

@abstract
func read_event() -> Dictionary

@abstract
func has_exited() -> bool

@abstract
func get_exit_code() -> int

# -- 上下文管理（可重写，有默认实现） --

## 是否支持 session 管理
func supports_session() -> bool:
	return false

## 获取当前 session ID（仅 supports_session()=true 时有效）
func get_session_id() -> String:
	return ""

## 恢复指定 session（仅 supports_session()=true 时有效）
func resume_session(session_id: String) -> void:
	pass

# -- 信息获取（有默认实现，子类可重写） --

func get_agent_name() -> String:
	return "Unknown"

func get_agent_version() -> String:
	return ""

@tool
@abstract
class_name AgentChecker
extends RefCounted

## Agent 可用性检测器 — 抽象基类
## CCChecker / PiChecker 的公共接口
## 负责检测 CLI 是否存在、获取版本号

## CLI 是否可用
var is_available: bool = false

## 错误消息（当 is_available == false 时）
var error_message: String = ""

## 执行检测：where/which → --version
## 子类必须实现。返回 true 表示可用
@abstract
func check() -> bool

## 获取 Agent 显示名称，如 "Claude Code" / "Pi"
@abstract
func get_agent_name() -> String

## 获取状态文本（用于 UI 展示）— 有默认实现，子类可重写
func get_status_text() -> String:
	if is_available:
		return "✅ %s 就绪" % get_agent_name()
	else:
		return "❌ %s 不可用: %s" % [get_agent_name(), error_message]

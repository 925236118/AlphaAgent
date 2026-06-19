@tool
class_name HireWorkflowDisplay
extends RefCounted

## 雇佣模式工作流展示器
## 在聊天消息区域中以格式化消息展示雇佣模式各阶段
## 不依赖 .tscn 文件，纯代码创建 UI 元素

var _main_panel: AgentMainPanel
var _message_list: VBoxContainer
var _current_phase_item: AgentChatMessageItem = null
var _phase_text: String = ""

const MESSAGE_ITEM = preload("uid://cjytvn2j0yi3s")

func _init(panel: AgentMainPanel) -> void:
	_main_panel = panel
	_message_list = panel.message_list

## 添加一个系统消息（灰色背景的提示消息）
func add_system_message(text: String) -> AgentChatMessageItem:
	var item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	item.show_think = false
	item.message_id = AlphaUtils.generate_random_string(16)
	_message_list.add_child(item)
	item.update_message_content(text)
	item.update_finished_message("Info")
	return item

## 添加阶段标题消息
func add_phase_header(icon: String, title: String, detail: String = "") -> AgentChatMessageItem:
	var text = "%s **%s**" % [icon, title]
	if not detail.is_empty():
		text += "\n> %s" % detail
	return add_system_message(text)

## 添加步骤列表展示（Phase 2 PLAN 产出）
func add_plan_steps(steps: Array[Dictionary]) -> AgentChatMessageItem:
	var text = "📋 **执行计划**\n\n"
	for i in steps.size():
		var step = steps[i]
		var title = step.get("title", "Step %d" % i)
		text += "%d. %s\n" % [i + 1, title]
		if step.has("description") and not str(step.get("description", "")).is_empty():
			var desc = str(step.get("description", ""))
			if desc.length() > 80:
				desc = desc.substr(0, 80) + "..."
			text += "   _%s_\n" % desc
	text += "\n⏳ 等待您确认后开始执行..."
	return add_system_message(text)

## 添加步骤执行中消息
func add_step_executing(step_index: int, step_title: String, agent_name: String) -> AgentChatMessageItem:
	var text = "🔁 **步骤 %d**: %s\n\n> 正在雇佣 %s 执行此步骤..." % [step_index + 1, step_title, agent_name]
	return add_system_message(text)

## 添加 CC/Pi 输出片段
func add_agent_output(text: String, is_error: bool = false) -> void:
	if _current_phase_item:
		var current = _current_phase_item.message_content.text
		if is_error:
			_current_phase_item.update_message_content(current + "\n```\n[错误] %s\n```" % text)
		else:
			_current_phase_item.update_message_content(current + "\n```\n%s\n```" % text)

## 添加工具调用信息
func add_tool_call_info(tool_name: String, tool_args: Dictionary) -> void:
	if _current_phase_item:
		var args_str = JSON.stringify(tool_args)
		if args_str.length() > 120:
			args_str = args_str.substr(0, 120) + "..."
		var current = _current_phase_item.message_content.text
		_current_phase_item.update_message_content(current + "\n🔧 `%s(%s)`" % [tool_name, args_str])

## 添加验证结果
func add_verification(report: Dictionary) -> AgentChatMessageItem:
	var verdict = report.get("overall_verdict", 0)
	var step_title = report.get("step_title", "")
	var failed = report.get("failed_criteria", [])
	var warnings_list = report.get("warnings", [])
	var suggestion = report.get("fix_suggestion", {})

	var icon: String
	var verdict_text: String
	match verdict:
		0:  # PASS
			icon = "✅"
			verdict_text = "通过"
		1:  # WARN
			icon = "⚠️"
			verdict_text = "通过（有警告）"
		2:  # FAIL
			icon = "❌"
			verdict_text = "失败"
		3:  # LOGIC_ERROR
			icon = "🔄"
			verdict_text = "逻辑错误"

	var text = "%s **验证**: %s → %s" % [icon, step_title, verdict_text]

	if failed.size() > 0:
		text += "\n\n失败项:"
		for item in failed:
			text += "\n  · %s" % str(item)

	if warnings_list.size() > 0:
		text += "\n\n警告:"
		for item in warnings_list:
			text += "\n  · %s" % str(item)

	if not suggestion.is_empty():
		text += "\n\n修复建议:"
		if suggestion.has("file"):
			text += "\n  文件: %s" % suggestion["file"]
		if suggestion.has("location"):
			text += "\n  位置: %s" % suggestion["location"]
		if suggestion.has("expected"):
			text += "\n  期望: %s" % suggestion["expected"]

	return add_system_message(text)

## 添加失败重试消息
func add_retry_message(retry_count: int, max_retries: int) -> AgentChatMessageItem:
	return add_system_message("🔧 **修复尝试 %d/%d** — 正在同一 session 中发送修复指令..." % [retry_count, max_retries])

## 添加最终总结
func add_summary(summary: Dictionary) -> AgentChatMessageItem:
	var passed = summary.get("passed", 0)
	var failed = summary.get("failed", 0)
	var skipped = summary.get("skipped", 0)
	var total = summary.get("total", 0)
	var agent = summary.get("agent", "Unknown")

	var text = "🏁 **雇佣模式执行完毕**\n\n"
	text += "Agent: %s\n" % agent
	text += "步骤: %d 总计 | " % total
	text += "✅ %d 通过 | " % passed
	text += "❌ %d 失败 | " % failed
	if skipped > 0:
		text += "⏭ %d 跳过" % skipped

	return add_system_message(text)

## 添加 Agent 不可用错误
func add_agent_unavailable(agent_type: String) -> AgentChatMessageItem:
	var agent_name = "Claude Code" if agent_type == "cc" else "Pi"
	var text = "❌ **%s 拒绝了您的 offer**\n\n" % agent_name
	text += "· 未找到 %s 命令\n" % agent_type
	text += "· 请确保已安装并在 PATH 中\n"
	text += "· 检测通过前无法发送对话\n\n"
	if agent_type == "pi":
		text += "安装: `npm install -g @earendil-works/pi-coding-agent`"
	else:
		text += "安装: https://docs.anthropic.com/en/docs/claude-code"
	return add_system_message(text)

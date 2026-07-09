@tool
class_name HireWorkflowDisplay
extends RefCounted

## 雇佣模式工作流展示器
## 在聊天消息区域中以格式化消息展示雇佣模式各阶段
## 支持实时 Prompt/Output 卡片展示（通过 HireStepCard）
## 不依赖 .tscn 文件，纯代码创建 UI 元素

var _main_panel: AgentMainPanel
var _message_list: VBoxContainer
var _current_phase_item: AgentChatMessageItem = null
var _phase_text: String = ""

# -- 新增：当前正在执行的步骤卡片 --
var _active_card: HireStepCard = null
# -- 新增：当前验证阶段的消息项 --
var _active_verification_item: AgentChatMessageItem = null

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
		var step_title = step.get("title", "Step %d" % i)
		text += "%d. %s\n" % [i + 1, step_title]
		if step.has("description") and not str(step.get("description", "")).is_empty():
			var desc = str(step.get("description", ""))
			if desc.length() > 80:
				desc = desc.substr(0, 80) + "..."
			text += "   _%s_\n" % desc
	text += "\n⏳ 等待您确认后开始执行..."
	return add_system_message(text)

# =====================================================================
# 新增：步骤卡片式展示（Prompt + Output 可折叠面板）
# =====================================================================

## 开始一个步骤的展示 — 创建可折叠 HireStepCard 并添加到消息列表
## title: 步骤标题，如 "步骤 1: 分析现有代码结构"
## prompt: 发送给 Agent 的完整提示词
## 返回创建的 HireStepCard 引用
func begin_step(title: String, prompt: String) -> HireStepCard:
	# 创建步骤卡片
	var card = HireStepCard.new()
	card.set_title(title)
	card.set_prompt(prompt)
	card.set_running()

	# 添加左右边距（模拟聊天气泡的边距）
	card.add_theme_constant_override("margin_left", 8)
	card.add_theme_constant_override("margin_right", 8)
	card.add_theme_constant_override("margin_top", 4)
	card.add_theme_constant_override("margin_bottom", 4)

	# 添加到消息列表
	_message_list.add_child(card)

	# 追踪为当前活动卡片
	_active_card = card

	# 同时创建一个配套的 _current_phase_item 用于兼容旧方法
	_current_phase_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	_current_phase_item.show_think = false
	_current_phase_item.message_id = AlphaUtils.generate_random_string(16)
	_message_list.add_child(_current_phase_item)
	# 隐藏此兼容项（它只用于接收追加内容）
	_current_phase_item.visible = false

	return card

## 结束当前步骤 — 标记卡片完成
func end_step(success: bool = true, error_message: String = "") -> void:
	if not _active_card:
		return
	if success:
		_active_card.set_finished()
	else:
		_active_card.set_error(error_message)

	# 清除追踪
	_active_card = null
	_current_phase_item = null

# =====================================================================
# 修改：以下方法现在委托给 _active_card
# =====================================================================

## 添加 Agent 输出片段（实时流式追加到当前步骤卡片）
func add_agent_output(text: String, is_error: bool = false) -> void:
	if _active_card:
		_active_card.append_output(text, is_error)
	elif _current_phase_item:
		# 回退：追加到兼容消息项
		var current = _current_phase_item.message_content.text
		if is_error:
			_current_phase_item.update_message_content(current + "\n```\n[错误] %s\n```" % text)
		else:
			_current_phase_item.update_message_content(current + "\n```\n%s\n```" % text)

## 添加工具调用信息（追加到当前步骤卡片的 Output 区域）
func add_tool_call_info(tool_name: String, tool_args: Dictionary) -> void:
	if _active_card:
		_active_card.append_tool_call(tool_name, tool_args)
	elif _current_phase_item:
		var args_str = JSON.stringify(tool_args)
		if args_str.length() > 120:
			args_str = args_str.substr(0, 120) + "..."
		var current = _current_phase_item.message_content.text
		_current_phase_item.update_message_content(current + "\n🔧 `%s(%s)`" % [tool_name, args_str])

## 添加工具执行结果（追加到当前步骤卡片的 Output 区域）
func add_tool_result(tool_name: String, result: String) -> void:
	if _active_card:
		_active_card.append_tool_result(tool_name, result)
	elif _current_phase_item:
		var short_r = result
		if short_r.length() > 300:
			short_r = short_r.substr(0, 300) + "..."
		var current = _current_phase_item.message_content.text
		_current_phase_item.update_message_content(current + "\n   → %s 完成: %s" % [tool_name, short_r])

## 添加步骤执行中消息（旧版兼容 — 现在推荐使用 begin_step）
func add_step_executing(step_index: int, step_title: String, agent_name: String) -> AgentChatMessageItem:
	# 如果已有活动卡片，先结束它
	if _active_card:
		end_step(true)

	var text = "🔁 **步骤 %d**: %s\n\n> 正在雇佣 %s 执行此步骤..." % [step_index + 1, step_title, agent_name]
	return add_system_message(text)

# =====================================================================
# 以下方法保持不变
# =====================================================================

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

	var item = add_system_message(text)
	_active_verification_item = item
	return item

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

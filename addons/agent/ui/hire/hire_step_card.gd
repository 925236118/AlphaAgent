@tool
class_name HireStepCard
extends PanelContainer

## 雇佣模式步骤卡片 — 可折叠的 Prompt + Output 展示组件
##
## 模仿 UseToolItem 的视觉结构，纯代码构建 UI：
##   PanelContainer (暗背景)
##     VBoxContainer
##       TitleButton (折叠/展开按钮)
##       DetailContainer
##         PromptLabel + PromptEdit （只读，展示发送给 Agent 的提示词）
##         OutputLabel + OutputEdit （只读，实时追加 Agent 输出）
##         StatusLabel （状态标记：执行中 / 已完成 / 错误）
##
## 使用方式:
##   var card = HireStepCard.new()
##   card.set_title("步骤 1: 分析现有代码结构")
##   card.set_prompt(prompt_text)
##   card.append_output("> 开始分析...")
##   card.set_finished()

# -- 颜色常量（与 UseToolItem 保持一致） --
const BG_COLOR := Color(0.125, 0.125, 0.125, 1.0)
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.53)
const TEXT_COLOR := Color(0.9, 0.9, 0.9, 1.0)
const ERROR_COLOR := Color(0.9, 0.31, 0.31, 1.0)
const SUCCESS_COLOR := Color(0.31, 0.8, 0.31, 1.0)
const TOOL_COLOR := Color(0.4, 0.6, 0.9, 1.0)

# -- UI 元素 --
var _title_btn: Button
var _detail_container: VBoxContainer
var _prompt_edit: TextEdit
var _output_edit: TextEdit
var _status_label: Label

# -- 状态 --
var _is_finished: bool = false
var _is_error: bool = false
var _step_title: String = ""

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	# -- 根 PanelContainer 样式 --
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = BG_COLOR
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 8
	panel_style.content_margin_top = 6
	panel_style.content_margin_right = 8
	panel_style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", panel_style)

	# -- VBoxContainer --
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(vbox)

	# -- TitleLabel（折叠按钮）--
	_title_btn = Button.new()
	_title_btn.text = ""
	_title_btn.flat = true
	_title_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	_title_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var title_style = StyleBoxEmpty.new()
	title_style.content_margin_left = 5
	title_style.content_margin_top = 3
	title_style.content_margin_bottom = 3
	_title_btn.add_theme_stylebox_override("normal", title_style)
	_title_btn.add_theme_stylebox_override("pressed", title_style)
	_title_btn.add_theme_stylebox_override("hover", title_style)
	_title_btn.add_theme_stylebox_override("focus", title_style)
	_title_btn.pressed.connect(_on_title_toggled)
	vbox.add_child(_title_btn)

	# -- DetailContainer --
	_detail_container = VBoxContainer.new()
	_detail_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_detail_container.visible = true  # 默认展开，用户可看到内容
	vbox.add_child(_detail_container)

	# -- Prompt 区域 --
	var prompt_label := Label.new()
	prompt_label.text = "📤 发送给 Agent 的提示词"
	prompt_label.add_theme_font_size_override("font_size", 12)
	prompt_label.add_theme_color_override("font_color", LABEL_COLOR)
	_detail_container.add_child(prompt_label)

	_prompt_edit = TextEdit.new()
	_prompt_edit.editable = false
	_prompt_edit.context_menu_enabled = true
	_prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt_edit.scroll_fit_content_height = true
	_prompt_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	var prompt_focus_style = StyleBoxEmpty.new()
	_prompt_edit.add_theme_stylebox_override("focus", prompt_focus_style)
	_prompt_edit.add_theme_stylebox_override("read_only", prompt_focus_style)
	_detail_container.add_child(_prompt_edit)

	# -- Output 分隔 --
	var sep := HSeparator.new()
	_detail_container.add_child(sep)

	# -- Output 区域 --
	var output_label := Label.new()
	output_label.text = "📥 Agent 返回的输出"
	output_label.add_theme_font_size_override("font_size", 12)
	output_label.add_theme_color_override("font_color", LABEL_COLOR)
	_detail_container.add_child(output_label)

	_output_edit = TextEdit.new()
	_output_edit.editable = false
	_output_edit.context_menu_enabled = true
	_output_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_output_edit.scroll_fit_content_height = true
	_output_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_output_edit.placeholder_text = "等待 Agent 输出..."
	var output_focus_style = StyleBoxEmpty.new()
	_output_edit.add_theme_stylebox_override("focus", output_focus_style)
	_output_edit.add_theme_stylebox_override("read_only", output_focus_style)
	_detail_container.add_child(_output_edit)

	# -- 状态标签 --
	_status_label = Label.new()
	_status_label.text = "⏳ 等待执行..."
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", LABEL_COLOR)
	_detail_container.add_child(_status_label)

# -- 公开方法 --

## 设置步骤标题
func set_title(text: String) -> void:
	_step_title = text
	_update_title_text()

## 设置 Prompt 内容（在 TextEdit 中展示）
func set_prompt(text: String) -> void:
	_prompt_edit.text = text
	_prompt_edit.set_caret_line(0)

## 追加 Agent 输出（实时流式）
func append_output(text: String, is_error: bool = false) -> void:
	if is_error:
		_output_edit.text += "[错误] " + text
	else:
		_output_edit.text += text
	# 自动滚动到底部
	_output_edit.set_caret_line(_output_edit.get_line_count() - 1)

## 追加工具调用信息
func append_tool_call(tool_name: String, tool_args: Dictionary) -> void:
	var args_str = JSON.stringify(tool_args, "  ")
	if args_str.length() > 200:
		args_str = args_str.substr(0, 200) + "..."
	_output_edit.text += "\n🔧 调用工具: %s(%s)\n" % [tool_name, args_str]
	_output_edit.set_caret_line(_output_edit.get_line_count() - 1)

## 追加工具执行结果
func append_tool_result(tool_name: String, result: String) -> void:
	var short_result = result
	if short_result.length() > 500:
		short_result = short_result.substr(0, 500) + "..."
	_output_edit.text += "   → %s 完成\n" % tool_name
	_output_edit.set_caret_line(_output_edit.get_line_count() - 1)

## 标记为执行完成
func set_finished() -> void:
	_is_finished = true
	_status_label.text = "✅ 执行完成"
	_status_label.add_theme_color_override("font_color", SUCCESS_COLOR)
	_update_title_text()

## 标记为执行失败
func set_error(message: String) -> void:
	_is_finished = true
	_is_error = true
	_status_label.text = "❌ 执行失败: %s" % message
	_status_label.add_theme_color_override("font_color", ERROR_COLOR)
	_update_title_text()

## 设置状态为"执行中"
func set_running() -> void:
	_status_label.text = "⏳ 执行中..."
	_status_label.add_theme_color_override("font_color", LABEL_COLOR)

## 获取输出文本
func get_output_text() -> String:
	return _output_edit.text

## 是否已完成
func is_finished() -> bool:
	return _is_finished

# -- 内部方法 --

func _update_title_text() -> void:
	var icon = ""
	if _is_finished:
		icon = "✅ " if not _is_error else "❌ "
	else:
		icon = "📤 "
	_title_btn.text = icon + _step_title

func _on_title_toggled() -> void:
	_detail_container.visible = not _detail_container.visible

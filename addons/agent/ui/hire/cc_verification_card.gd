@tool
class_name CCVerificationCard
extends MarginContainer

## 验证报告卡片
## 显示步骤验证结果：PASS / WARN / FAIL / LOGIC_ERROR
## 包含具体的检查项目和修复建议

# -- 子节点引用 --
@onready var status_icon: Label = %StatusIcon
@onready var title_label: Label = %TitleLabel
@onready var detail_container: VBoxContainer = %DetailContainer
@onready var fix_suggestion_label: RichTextLabel = %FixSuggestion

# -- 报告数据 --
var _report: Dictionary = {}

func _ready() -> void:
	hide()

## 加载验证报告并显示
func load_report(report: Dictionary) -> void:
	_report = report
	_update_display()
	show()

## 清空卡片
func clear_card() -> void:
	_report.clear()
	if detail_container:
		for child in detail_container.get_children():
			child.queue_free()
	hide()

# -- 内部方法 --

func _update_display() -> void:
	var verdict = _report.get("overall_verdict", 0)
	var step_title = _report.get("step_title", "")
	var failed = _report.get("failed_criteria", [])
	var warnings_list = _report.get("warnings", [])
	var suggestion = _report.get("fix_suggestion", {})

	# 标题
	if title_label:
		title_label.text = "验证: %s" % step_title

	# 状态图标
	if status_icon:
		match verdict:
			0:  # PASS
				status_icon.text = "✅"
				status_icon.tooltip_text = "通过"
			1:  # WARN
				status_icon.text = "⚠️"
				status_icon.tooltip_text = "警告"
			2:  # FAIL
				status_icon.text = "❌"
				status_icon.tooltip_text = "失败"
			3:  # LOGIC_ERROR
				status_icon.text = "🔄"
				status_icon.tooltip_text = "逻辑错误"
			_:
				status_icon.text = "❓"

	# 失败项
	if detail_container and failed.size() > 0:
		for item in failed:
			var label = Label.new()
			label.text = "· %s" % str(item)
			label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			detail_container.add_child(label)

	# 警告
	if detail_container and warnings_list.size() > 0:
		for item in warnings_list:
			var label = Label.new()
			label.text = "⚠ %s" % str(item)
			label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
			detail_container.add_child(label)

	# 修复建议
	if fix_suggestion_label and not suggestion.is_empty():
		var text = "修复建议:\n"
		if suggestion.has("file"):
			text += "  文件: %s\n" % suggestion["file"]
		if suggestion.has("location"):
			text += "  位置: %s\n" % suggestion["location"]
		if suggestion.has("expected"):
			text += "  期望: %s\n" % suggestion["expected"]
		fix_suggestion_label.text = text

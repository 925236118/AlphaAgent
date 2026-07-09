@tool
extends PanelContainer
@onready var title_label: Button = %TitleLabel
@onready var status_label: Label = %StatusLabel
@onready var tool_request: TextEdit = %ToolRequest
@onready var tool_response: TextEdit = %ToolResponse
@onready var detail_container: VBoxContainer = %DetailContainer

var id: String = ""

func update_title(title: String):
	title_label.text = title

func update_request(argument_string: String):
	tool_request.text = _pretty_json_or_raw(argument_string)

func update_response(result_string: String):
	tool_response.text = _pretty_json_or_raw(result_string)
	set_running(false)
	var parsed = _parse_json_safely(result_string)
	if parsed is Dictionary and parsed.has("error"):
		set_error(true)

func set_running(running: bool) -> void:
	if running:
		status_label.text = "执行中..."
		status_label.add_theme_color_override("font_color", AgentUiTokens.TEXT_MUTED)
	else:
		if not status_label.text.begins_with("失败"):
			status_label.text = "完成"
			status_label.add_theme_color_override("font_color", AgentUiTokens.SUCCESS)

func set_error(is_error: bool) -> void:
	if is_error:
		status_label.text = "失败"
		status_label.add_theme_color_override("font_color", AgentUiTokens.DANGER)

func _pretty_json_or_raw(text: String) -> String:
	var parsed = _parse_json_safely(text)
	if parsed == null:
		return text
	return JSON.stringify(parsed, "\t")

func _parse_json_safely(text: String):
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.get_data()

func _on_title_label_pressed() -> void:
	detail_container.visible = not detail_container.visible

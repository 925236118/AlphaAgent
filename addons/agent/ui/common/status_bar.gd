@tool
class_name AgentStatusBar
extends HBoxContainer

@onready var status_label: Label = %StatusLabel

var _pending_text: String = ""


func show_status(text: String, duration_sec: float = 0.0) -> void:
	_pending_text = text
	status_label.text = text
	visible = true
	if duration_sec > 0.0:
		var timer := get_tree().create_timer(duration_sec)
		timer.timeout.connect(_on_auto_hide_timeout.bind(text), CONNECT_ONE_SHOT)


func hide_status() -> void:
	_pending_text = ""
	status_label.text = ""
	visible = false


func _on_auto_hide_timeout(expected_text: String) -> void:
	if status_label.text == expected_text:
		hide_status()

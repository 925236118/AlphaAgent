@tool
extends AgentSettingItemBase
@onready var line_edit: LineEdit = $LineEdit

func get_value():
	return line_edit.text

func get_value_type() -> int:
	return TYPE_STRING

func set_value(value: String):
	line_edit.text = value

func _on_line_edit_text_changed(new_text: String) -> void:
	value_changed.emit()

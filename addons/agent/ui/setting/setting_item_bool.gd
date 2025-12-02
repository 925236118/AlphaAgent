@tool
extends AgentSettingItemBase

@onready var check_button: CheckButton = $CheckButton

func get_value():
	return check_button.button_pressed

func get_value_type() -> int:
	return TYPE_BOOL

func set_value(value: bool):
	check_button.button_pressed = value


func _on_check_button_toggled(toggled_on: bool) -> void:
	value_changed.emit()

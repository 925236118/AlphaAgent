@tool
extends AgentSettingItemBase

@onready var option_button: OptionButton = $OptionButton

func get_value():
	return option_button.get_selected_id()

func get_value_type() -> int:
	return TYPE_INT

func set_value(value: int):
	option_button.select(value)

func _on_option_button_item_selected(index: int) -> void:
	value_changed.emit()

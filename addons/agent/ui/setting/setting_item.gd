@tool
@abstract
class_name AgentSettingItemBase
extends BoxContainer

signal value_changed

@onready var setting_name_label: Label = %SettingNameLabel

@export var setting_name: String = "":
	set(val):
		setting_name = val
		if setting_name_label:
			setting_name_label.text = val

@export var setting_key: String = ""

func _ready() -> void:
	setting_name_label.text = setting_name

@abstract
func get_value()

@abstract
func get_value_type() -> int

@abstract
func set_value(value)

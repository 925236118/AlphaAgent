@tool
extends HBoxContainer

@onready var setting_name_label: Label = %SettingNameLabel

@export var setting_name: String = "":
	set(val):
		setting_name = val
		if setting_name_label:
			setting_name_label.text = val

@export var setting_value_node: Control = null

func _ready() -> void:
		setting_name_label.text = setting_name

@tool
extends PanelContainer
@onready var label: Label = $MarginContainer/HBoxContainer/Label

@onready var delete_button: Button = %DeleteButton

var info = {}

func _ready() -> void:
	delete_button.pressed.connect(queue_free)

func set_label(text):
	label.text = text

func set_tooltip(text):
	tooltip_text = text

@tool
extends PanelContainer

@onready var label: Label = $MarginContainer/Label
@onready var button: Button = $MarginContainer/Button


var info = {}

func _ready() -> void:
	button.pressed.connect(queue_free)

func set_label(text):
	label.text = text

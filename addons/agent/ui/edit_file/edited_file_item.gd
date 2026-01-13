@tool
class_name AgentEditedFileItem
extends PanelContainer

@onready var file_name_label: Label = %FileNameLabel
@onready var show_edit_file_button: Button = %ShowEditFileButton
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

signal show_edit_file

func _ready() -> void:
	show_edit_file_button.pressed.connect(show_edit_file.emit)

func set_name(file_name):
	file_name_label.text = file_name

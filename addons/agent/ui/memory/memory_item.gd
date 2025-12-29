@tool
class_name AgentMemoryItem
extends HBoxContainer

@onready var text_edit: TextEdit = $TextEdit
@onready var label: Label = $Label
@onready var remove_button: Button = $RemoveButton
@onready var edit_button: Button = $EditButton
@onready var finish_edit_button: Button = $FinishEditButton

signal remove
signal save(content: String)
enum State {
	Text,
	Edit
}

func _ready() -> void:
	remove_button.pressed.connect(func(): remove.emit())
	edit_button.pressed.connect(on_edit)
	finish_edit_button.pressed.connect(on_save)

func set_text(text):
	label.text = text

func set_state(state: State):
	if state == State.Text:
		text_edit.hide()
		label.show()
		edit_button.show()
		finish_edit_button.hide()
	else:
		text_edit.show()
		label.hide()
		edit_button.hide()
		finish_edit_button.show()

func on_edit():
	text_edit.text = label.text
	set_state(State.Edit)

func on_save():
	set_state(State.Text)
	label.text = text_edit.text
	save.emit(text_edit.text)

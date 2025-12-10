@tool
extends PanelContainer

@onready var history_message_title: Label = %HistoryMessageTitle
@onready var history_message_time: Label = %HistoryMessageTime

@onready var button_container: HBoxContainer = %ButtonContainer
@onready var recovery_button: Button = %RecoveryButton
@onready var delete_button: Button = %DeleteButton

signal recovery
signal delete

func _on_mouse_entered() -> void:
	if is_instance_valid(button_container):
		button_container.show()

func _on_mouse_exited() -> void:
	if is_instance_valid(button_container):
		button_container.hide()

func _on_recovery_button_pressed() -> void:
	recovery.emit()

func _on_delete_button_pressed() -> void:
	delete.emit()

func _on_recovery_button_mouse_entered() -> void:
	if is_instance_valid(button_container):
		button_container.show()

func _on_delete_button_mouse_entered() -> void:
	if is_instance_valid(button_container):
		button_container.show()

func set_title(title: String):
	if history_message_title:
		history_message_title.text = title

func set_time(time: String):
	if history_message_time:
		history_message_time.text = time

func _on_recovery_button_mouse_exited() -> void:
	if is_instance_valid(button_container):
		button_container.hide()

func _on_delete_button_mouse_exited() -> void:
	if is_instance_valid(button_container):
		button_container.hide()

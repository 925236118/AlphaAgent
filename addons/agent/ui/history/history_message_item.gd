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
		# 替换换行符为空格，避免多行显示
		var clean_title = title.replace("\n", " ").replace("\r", " ")
		# 如果标题过长，截断显示
		if clean_title.length() > 20:
			clean_title = clean_title.substr(0, 20) + "..."
		history_message_title.text = clean_title

func set_time(time: String):
	if history_message_time:
		history_message_time.text = time

func set_selected(value: bool) -> void:
	if value:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.23, 0.29)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.set_corner_radius_all(5)
		add_theme_stylebox_override("panel", style)
	else:
		remove_theme_stylebox_override("panel")

func _on_recovery_button_mouse_exited() -> void:
	if is_instance_valid(button_container):
		button_container.hide()

func _on_delete_button_mouse_exited() -> void:
	if is_instance_valid(button_container):
		button_container.hide()

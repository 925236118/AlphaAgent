@tool
extends Control
class_name CustomDropdown

signal mode_changed(mode: String)

@onready var checked_default_panel_container: PanelContainer = %CheckedDefaultPanelContainer
@onready var icon_arrowdown_texture_rect: TextureRect = %IconArrowdownTextureRect
@onready var checked_default_button: Button = %CheckedDefaultButton
@onready var dropdown_panel_container: PanelContainer = %DropdownPanelContainer
@onready var agent_texture_rect: TextureRect = %AgentTextureRect
@onready var ask_texture_rect: TextureRect = %ASKTextureRect
@onready var agent_button: Button = %AgentButton
@onready var ask_button: Button = %AskButton


func _ready() -> void:
	checked_default_button.pressed.connect(change_the_arrowdown)
	agent_button.pressed.connect(select_agent)
	ask_button.pressed.connect(select_ask)


func change_the_arrowdown() -> void:
	icon_arrowdown_texture_rect.flip_v = !icon_arrowdown_texture_rect.flip_v
	dropdown_panel_container.visible = !dropdown_panel_container.visible
	if dropdown_panel_container.visible:
		call_deferred("_position_dropdown_panel")


func _position_dropdown_panel() -> void:
	var panel_size := dropdown_panel_container.get_combined_minimum_size()
	dropdown_panel_container.size = panel_size
	dropdown_panel_container.custom_minimum_size = panel_size

	var host_rect := AgentUiLayoutUtils.get_host_rect(self)
	var button_rect := checked_default_panel_container.get_global_rect()
	var margin := AgentUiTokens.POPUP_MARGIN
	var panel_pos := Vector2(button_rect.position.x, button_rect.position.y - panel_size.y - 4.0)

	if panel_pos.y < host_rect.position.y + margin:
		panel_pos.y = button_rect.end.y + 4.0

	panel_pos.x = clampf(
		panel_pos.x,
		host_rect.position.x + margin,
		host_rect.end.x - panel_size.x - margin
	)
	panel_pos.y = clampf(
		panel_pos.y,
		host_rect.position.y + margin,
		host_rect.end.y - panel_size.y - margin
	)

	dropdown_panel_container.global_position = panel_pos


func select_agent() -> void:
	if agent_texture_rect.visible == false:
		agent_texture_rect.visible = !agent_texture_rect.visible
		ask_texture_rect.visible = !ask_texture_rect.visible
	checked_default_button.text = "Agent"
	change_the_arrowdown()
	check_is_action_mode()


func select_ask() -> void:
	if ask_texture_rect.visible == false:
		ask_texture_rect.visible = !ask_texture_rect.visible
		agent_texture_rect.visible = !agent_texture_rect.visible
	checked_default_button.text = "ASK"
	change_the_arrowdown()
	check_is_action_mode()


func get_now_mode() -> String:
	return checked_default_button.text


func check_is_action_mode() -> void:
	mode_changed.emit(get_now_mode())


func set_mode(mode: String, emit_signal: bool = true) -> void:
	var normalized := "ASK" if mode == "ASK" else "Agent"
	checked_default_button.text = normalized
	agent_texture_rect.visible = normalized == "Agent"
	ask_texture_rect.visible = normalized == "ASK"
	dropdown_panel_container.visible = false
	if emit_signal:
		mode_changed.emit(normalized)


func is_agent_mode() -> bool:
	return get_now_mode() == "Agent"

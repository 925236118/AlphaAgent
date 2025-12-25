@tool
extends Control
class_name CustomDropdown

signal is_action_mode

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

func _process(delta: float) -> void:
	pass
	

#切换下拉框展开状态#
func change_the_arrowdown():
	icon_arrowdown_texture_rect.flip_v =! icon_arrowdown_texture_rect.flip_v
	dropdown_panel_container.visible = ! dropdown_panel_container.visible
	#if dropdown_panel_container.mouse_filter == MOUSE_FILTER_STOP:
		#dropdown_panel_container.mouse_filter = MOUSE_FILTER_IGNORE
	#if dropdown_panel_container.mouse_filter == MOUSE_FILTER_IGNORE:
		#dropdown_panel_container.mouse_filter = MOUSE_FILTER_STOP
	#print(dropdown_panel_container.mouse_filter)

#选择Aggent#
func select_agent():
	if agent_texture_rect.visible == false:
		agent_texture_rect.visible =! agent_texture_rect.visible
		ask_texture_rect.visible =! ask_texture_rect.visible
	checked_default_button.text = "Agent"
	change_the_arrowdown()
	check_is_action_mode()

#选择ASK#
func select_ask():
	if ask_texture_rect.visible == false:
		ask_texture_rect.visible =! ask_texture_rect.visible
		agent_texture_rect.visible =! agent_texture_rect.visible
	checked_default_button.text = "ASK"
	change_the_arrowdown()
	check_is_action_mode()

func get_now_mode() -> String:
	#print(checked_default_button.text)
	return checked_default_button.text
	

func check_is_action_mode():
	is_action_mode.emit()
	print("now click")

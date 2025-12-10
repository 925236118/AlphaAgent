extends Control
class_name CustomDropdown


@onready var icon_arrowdown_texture_rect: TextureRect = %IconArrowdownTextureRect
@onready var checked_default_button: Button = %CheckedDefaultButton
@onready var dropdown_panel_container: PanelContainer = %DropdownPanelContainer
@onready var agent_texture_rect: TextureRect = %AgentTextureRect
@onready var ask_texture_rect: TextureRect = %ASKTextureRect
@onready var agent_button: Button = %AgentButton
@onready var ask_button: Button = %AskButton


func _ready() -> void:
	checked_default_button.pressed.connect(change_the_arrowdown) 



func _process(delta: float) -> void:
	pass
	



func change_the_arrowdown():
	print("is click")
	icon_arrowdown_texture_rect.flip_v =! icon_arrowdown_texture_rect.flip_v
	print("flip_v = " ,icon_arrowdown_texture_rect.flip_v)
	dropdown_panel_container.visible = ! dropdown_panel_container.visible
	
func select_agent():
	pass



func select_ask():
	pass

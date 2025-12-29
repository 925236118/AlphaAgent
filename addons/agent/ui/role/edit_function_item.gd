@tool
class_name AgentEditFunctionItem
extends PanelContainer

@onready var function_name_label: Label = %FunctionName
@onready var function_readonly: Label = %FunctionReadonly
@onready var function_description: Label = %FunctionDescription
@onready var fucntion_active_button: Button = %FucntionActiveButton
@onready var active_icon: TextureRect = %ActiveIcon
@onready var disactive_icon: TextureRect = %DisactiveIcon

var function_info: Dictionary = {}
var active: bool = false
var function_name: String = ""

func _ready() -> void:
	fucntion_active_button.pressed.connect(on_click_function_active_button)

func set_function_name(_function_name: String):
	function_name = _function_name
	var singleton = AlphaAgentSingleton.get_instance()
	if singleton.main_panel != null:
		function_info = singleton.main_panel.tools.get_function_name_list()[_function_name]
		function_name_label.text = _function_name
		function_readonly.visible = function_info.readonly
		function_description.text = function_info.description

func set_active(_active: bool):
	active = _active
	modulate.a = 1.0 if active else 0.5
	active_icon.visible = active
	disactive_icon.visible = not active

func on_click_function_active_button():
	set_active(not active)

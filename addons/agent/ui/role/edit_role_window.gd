@tool
class_name AgentEditRoleWindow
extends Window

@onready var role_name_edit: LineEdit = %RoleNameEdit
@onready var prompt_edit: TextEdit = %PromptEdit
@onready var edit_function_container: VBoxContainer = %EditFunctionContainer
@onready var cancel_button: Button = %CancelButton
@onready var create_button: Button = %CreateButton
@onready var update_button: Button = %UpdateButton

var role_info: AgentRoleConfig.RoleInfo = null
var edit_role_node: AgentSettingRoleItem = null
const EDIT_FUNCTION_ITEM = preload("uid://c8vxi8peucg51")

signal created(role: AgentRoleConfig.RoleInfo)

enum WindowMode {
	Create,
	Edit
}
var window_mode := WindowMode.Edit
func _ready() -> void:
	cancel_button.pressed.connect(on_click_cancel_button)
	create_button.pressed.connect(on_click_create_button)
	update_button.pressed.connect(on_click_update_button)
	init_function_list()
	close_requested.connect(queue_free)

func set_role_info(role_info: AgentRoleConfig.RoleInfo):
	self.role_info = role_info
	role_name_edit.text = role_info.name
	prompt_edit.text = role_info.prompt
	for function_item in edit_function_container.get_children():
		function_item.set_active(role_info.tools.has(function_item.function_name))


func init_function_list():
	var singleton = AlphaAgentSingleton.get_instance()
	if singleton.main_panel == null:
		push_error("主面板未初始化")
		return
	var function_name_list = singleton.main_panel.tools.get_function_name_list().keys()
	for function_name in function_name_list:
		var function_item := EDIT_FUNCTION_ITEM.instantiate() as AgentEditFunctionItem
		edit_function_container.add_child(function_item)
		function_item.set_function_name(function_name)

func on_click_cancel_button():
	queue_free()

func on_click_create_button():
	role_info = AgentRoleConfig.RoleInfo.new()
	role_info.name = role_name_edit.text
	role_info.prompt = prompt_edit.text
	role_info.tools = []
	for function_item in edit_function_container.get_children():
		if function_item.active:
			role_info.tools.append(function_item.function_name)
	AlphaAgentPlugin.global_setting.role_manager.add_role(role_info)
	created.emit(role_info)
	queue_free()

func on_click_update_button():
	role_info.name = role_name_edit.text
	role_info.prompt = prompt_edit.text
	role_info.tools = []
	for function_item in edit_function_container.get_children():
		if function_item.active:
			role_info.tools.append(function_item.function_name)
	AlphaAgentPlugin.global_setting.role_manager.update_role(role_info)
	if edit_role_node:
		edit_role_node.set_role_info(role_info)
		var singleton = AlphaAgentSingleton.get_instance()
		singleton.roles_changed.emit()
	queue_free()

func set_window_mode(mode: WindowMode):
	match mode:
		WindowMode.Create:
			create_button.show()
			update_button.hide()
		WindowMode.Edit:
			create_button.hide()
			update_button.show()

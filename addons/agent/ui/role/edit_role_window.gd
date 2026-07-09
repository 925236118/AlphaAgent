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
	var new_role_info = AgentRoleConfig.RoleInfo.new()
	if not _apply_form_and_validate(new_role_info):
		return
	if not AlphaAgentPlugin.global_setting.role_manager.add_role(new_role_info):
		alert("创建角色失败", "角色名称不能为空或与现有角色重名。")
		return
	created.emit(new_role_info)
	queue_free()

func on_click_update_button():
	var updated_role_info = AgentRoleConfig.RoleInfo.new()
	updated_role_info.id = role_info.id
	if not _apply_form_and_validate(updated_role_info, role_info.id):
		return
	if not AlphaAgentPlugin.global_setting.role_manager.update_role(updated_role_info):
		alert("更新角色失败", "角色名称不能为空或与现有角色重名。")
		return
	role_info = updated_role_info
	if edit_role_node:
		edit_role_node.set_role_info(updated_role_info)
		var singleton = AlphaAgentSingleton.get_instance()
		singleton.roles_changed.emit()
	queue_free()

func _apply_form_and_validate(target_role_info: AgentRoleConfig.RoleInfo, exclude_role_id: String = "") -> bool:
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager == null:
		alert("角色管理器未初始化", "请稍后重试。")
		return false
	var normalized_name = role_name_edit.text.strip_edges(true, true)
	var error_msg = role_manager.validate_role_name(normalized_name, exclude_role_id)
	if error_msg != "":
		alert("角色校验失败", error_msg)
		return false
	role_name_edit.text = normalized_name
	target_role_info.name = normalized_name
	target_role_info.prompt = prompt_edit.text
	target_role_info.tools = []
	for function_item in edit_function_container.get_children():
		if function_item.active:
			target_role_info.tools.append(function_item.function_name)
	return true

func alert(title, text):
	var dialog = AcceptDialog.new()
	dialog.close_requested.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.title = title
	dialog.dialog_text = text
	dialog.transient = true
	add_child(dialog)
	AgentUiLayoutUtils.popup_centered_clamped(dialog, Vector2i(450, 180), self)

func set_window_mode(mode: WindowMode):
	match mode:
		WindowMode.Create:
			create_button.show()
			update_button.hide()
		WindowMode.Edit:
			create_button.hide()
			update_button.show()

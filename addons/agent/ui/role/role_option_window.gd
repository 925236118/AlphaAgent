@tool
class_name AgentRoleOptionWindow
extends Window

@onready var role_button_list: VBoxContainer = %RoleButtonList
@onready var add_role_button: Button = %AddRoleButton
@onready var add_default_roles_button: Button = %AddDefaultRolesButton
@onready var role_name_edit: LineEdit = %RoleNameEdit
@onready var prompt_edit: TextEdit = %PromptEdit
@onready var edit_function_container: VBoxContainer = %EditFunctionContainer
@onready var form_container: VBoxContainer = %FormContainer
@onready var placeholder_label: Label = %PlaceholderLabel
@onready var create_button: Button = %CreateButton
@onready var update_button: Button = %UpdateButton
@onready var delete_button: Button = %DeleteButton
@onready var edit_button: Button = %EditButton
@onready var role_name_label: Label = %RoleNameLabel
@onready var prompt_label: RichTextLabel = %PromptLabel
@onready var cancel_button: Button = %CancelButton

const EDIT_FUNCTION_ITEM = preload("uid://c8vxi8peucg51")

var current_role: AgentRoleConfig.RoleInfo = null
var current_button_index: int = -1
var _edit_mode: bool = false

func _ready() -> void:
	add_role_button.pressed.connect(on_add_role_button_pressed)
	add_default_roles_button.pressed.connect(on_add_default_roles_button_pressed)
	create_button.pressed.connect(on_create_button_pressed)
	update_button.pressed.connect(on_update_button_pressed)
	delete_button.pressed.connect(on_delete_button_pressed)
	edit_button.pressed.connect(on_edit_button_pressed)
	cancel_button.pressed.connect(on_cancel_button_pressed)
	close_requested.connect(queue_free)
	init_function_list()
	init_role_list()

func init_function_list():
	for child in edit_function_container.get_children():
		child.queue_free()

	var singleton = AlphaAgentSingleton.get_instance()
	if singleton.main_panel == null:
		return
	var tools_node = singleton.main_panel.get("tools")
	if tools_node == null or not (tools_node is AgentTools):
		return
	var function_name_list = tools_node.get_function_name_list().keys()
	for function_name in function_name_list:
		var function_item := EDIT_FUNCTION_ITEM.instantiate() as AgentEditFunctionItem
		edit_function_container.add_child(function_item)
		function_item.set_function_name(function_name)

func init_role_list():
	clear_role_buttons()
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager == null:
		return
	for i in role_manager.roles.size():
		_add_role_button(role_manager.roles[i], i)
	_select(-1)

func clear_role_buttons():
	for child in role_button_list.get_children():
		child.queue_free()

func _add_role_button(role: AgentRoleConfig.RoleInfo, index: int):
	var btn = Button.new()
	btn.text = role.name
	btn.set_theme_type_variation(&"SecondaryButton")
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.toggle_mode = true
	btn.pressed.connect(_on_role_button_pressed.bind(btn, index))
	role_button_list.add_child(btn)

func _on_role_button_pressed(btn: Button, index: int):
	current_button_index = index
	for child: Button in role_button_list.get_children():
		child.button_pressed = child == btn
	_select(index)

func _select(index: int):
	_edit_mode = false
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager == null or index < 0 or index >= role_manager.roles.size():
		current_role = null
		form_container.hide()
		placeholder_label.show()
		return

	current_role = role_manager.roles[index]
	placeholder_label.hide()
	form_container.show()
	_set_editable(false)
	role_name_label.text = current_role.name
	prompt_label.text = current_role.prompt
	role_name_edit.text = current_role.name
	prompt_edit.text = current_role.prompt
	for child in edit_function_container.get_children():
		if child is AgentEditFunctionItem:
			child.set_active(current_role.tools.has(child.function_name))
	create_button.hide()
	update_button.hide()
	delete_button.show()
	edit_button.show()

func _set_editable(enabled: bool):
	role_name_edit.visible = enabled
	prompt_edit.visible = enabled
	role_name_label.visible = not enabled
	prompt_label.visible = not enabled
	role_name_edit.editable = enabled
	prompt_edit.editable = enabled
	for child in edit_function_container.get_children():
		if child is AgentEditFunctionItem:
			child.set_disabled(not enabled)

func on_edit_button_pressed():
	_edit_mode = true
	_set_editable(true)
	update_button.show()
	edit_button.hide()
	delete_button.hide()

func on_add_role_button_pressed():
	clear_role_selection()
	current_role = null
	placeholder_label.hide()
	form_container.show()
	_set_editable(true)
	role_name_edit.text = ""
	prompt_edit.text = ""
	for child in edit_function_container.get_children():
		if child is AgentEditFunctionItem:
			child.set_active(false)
	create_button.show()
	update_button.hide()
	delete_button.hide()
	edit_button.hide()

func clear_role_selection():
	current_button_index = -1
	for child: Button in role_button_list.get_children():
		child.button_pressed = false

func on_add_default_roles_button_pressed():
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager == null:
		return
	add_default_roles_button.disabled = true
	role_manager.add_default_roles()
	add_default_roles_button.disabled = false
	init_role_list()
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.roles_changed.emit()

func on_create_button_pressed():
	var new_role = AgentRoleConfig.RoleInfo.new()
	if not _apply_form(new_role):
		return
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager == null:
		return
	if not role_manager.add_role(new_role):
		_alert("创建失败", "角色名称不能为空或与现有角色重名")
		return
	init_role_list()
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.roles_changed.emit()
	_select(role_manager.roles.size() - 1)

func on_update_button_pressed():
	if current_role == null:
		return
	var updated = AgentRoleConfig.RoleInfo.new()
	updated.id = current_role.id
	if not _apply_form(updated, current_role.id):
		return
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager == null:
		return
	if not role_manager.update_role(updated):
		_alert("更新失败", "角色名称不能为空或与现有角色重名")
		return
	current_role = role_manager.get_role_by_id(updated.id)
	_edit_mode = false
	_set_editable(false)
	update_button.hide()
	edit_button.show()
	delete_button.show()
	role_name_label.text = current_role.name
	prompt_label.text = current_role.prompt
	role_name_edit.text = current_role.name
	prompt_edit.text = current_role.prompt
	var btn = role_button_list.get_child(current_button_index) as Button
	if btn:
		btn.text = current_role.name
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.roles_changed.emit()

func on_delete_button_pressed():
	if current_role == null:
		return
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager == null:
		return
	role_manager.remove_role(current_role)
	init_role_list()
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.roles_changed.emit()
	_select(-1)

func on_cancel_button_pressed():
	queue_free()

func _apply_form(target: AgentRoleConfig.RoleInfo, exclude_id: String = "") -> bool:
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager == null:
		_alert("错误", "角色管理器未初始化")
		return false
	var name = role_name_edit.text.strip_edges(true, true)
	var err = role_manager.validate_role_name(name, exclude_id)
	if err != "":
		_alert("校验失败", err)
		return false
	target.name = name
	target.prompt = prompt_edit.text
	target.tools = []
	for child in edit_function_container.get_children():
		if child is AgentEditFunctionItem and child.active:
			target.tools.append(child.function_name)
	return true

func _alert(title: String, text: String):
	var dialog = AcceptDialog.new()
	dialog.close_requested.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.title = title
	dialog.dialog_text = text
	dialog.transient = true
	add_child(dialog)
	AgentUiLayoutUtils.popup_centered_clamped(dialog, Vector2i(450, 180), self)

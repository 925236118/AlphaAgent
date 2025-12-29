@tool
extends ScrollContainer

@onready var auto_clear_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoClearSetting
@onready var auto_expand_think_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoExpandThinkSetting
@onready var auto_add_file_ref_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoAddFileRefSetting
@onready var send_shot_cut: BoxContainer = $SettingPanel/SettingItemsContainer/SendShotCut
#@onready var config_model_button: Button = $SettingPanel/SettingItemsContainer/ConfigModelButton
@onready var add_supplier_button: Button = %AddSupplierButton
@onready var supplier_list: VBoxContainer = %SupplierList
@onready var role_list: VBoxContainer = %RoleList
@onready var add_role_button: Button = %AddRoleButton

const SUPPLIER_ITEM = preload("uid://cktcl3yjma34l")
const SETTING_ROLE_ITEM = preload("uid://dwlfm5aqjw7f4")
const EDIT_ROLE_WINDOW = preload("uid://cx0yeuxsc2kui")

# 添加新节点后需要在这里注册
@onready var setting_item_nodes = [
	auto_clear_setting,
	auto_expand_think_setting,
	auto_add_file_ref_setting,
	send_shot_cut
]

signal config_model
var suppliers: Array[AgentSupplierItem] = []
func _ready() -> void:
	AlphaAgentPlugin.global_setting.load_global_setting()
	init_item_values()
	init_signals()
	add_supplier_button.pressed.connect(on_click_add_supplier_button)
	init_models_supplier()
	init_roles()
	visibility_changed.connect(_on_show_setting)
	add_role_button.pressed.connect(on_click_add_role_button)

func init_item_values():
	for setting_item in setting_item_nodes:
		if setting_item is AgentSettingItemBase:
			setting_item.set_value(AlphaAgentPlugin.global_setting[setting_item.setting_key])

func init_signals():
	for setting_item in setting_item_nodes:
		if setting_item is AgentSettingItemBase:
			setting_item.value_changed.connect(save_settings.bind(setting_item))

func save_settings(setting_item: AgentSettingItemBase):
	AlphaAgentPlugin.global_setting[setting_item.setting_key] = setting_item.get_value()
	AlphaAgentPlugin.global_setting.save_global_setting()

func on_click_add_supplier_button():
	var new_supplier := SUPPLIER_ITEM.instantiate() as AgentSupplierItem
	supplier_list.add_child(new_supplier)
	new_supplier.editing = true

func init_models_supplier():
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if model_manager == null:
		return

	for supplier in model_manager.suppliers:
		var new_supplier := SUPPLIER_ITEM.instantiate() as AgentSupplierItem
		supplier_list.add_child(new_supplier)
		new_supplier.set_supplier_info(supplier)
		suppliers.append(new_supplier)

func _on_show_setting():
	if visible:
		for supplier in suppliers:
			supplier.update_current_model()

func init_roles():
	await get_tree().process_frame
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager == null:
		return

	for role in role_list.get_children():
		role.queue_free()

	for role in role_manager.roles:
		var new_role := SETTING_ROLE_ITEM.instantiate() as AgentSettingRoleItem
		role_list.add_child(new_role)
		new_role.call_deferred("set_role_info", role)

func on_click_add_role_button():
	var edit_role_window := EDIT_ROLE_WINDOW.instantiate() as AgentEditRoleWindow
	get_tree().root.add_child(edit_role_window)
	edit_role_window.set_role_info(AgentRoleConfig.RoleInfo.new())
	edit_role_window.popup_centered()
	edit_role_window.title = "添加角色"
	edit_role_window.edit_role_node = null
	edit_role_window.set_window_mode(AgentEditRoleWindow.WindowMode.Create)
	edit_role_window.created.connect(on_create_role_window_created, CONNECT_ONE_SHOT)

func on_create_role_window_created(role_info: AgentRoleConfig.RoleInfo):
	var new_role := SETTING_ROLE_ITEM.instantiate() as AgentSettingRoleItem
	role_list.add_child(new_role)
	new_role.set_role_info(role_info)
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.roles_changed.emit()

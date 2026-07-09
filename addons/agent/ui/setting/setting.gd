@tool
extends ScrollContainer

@onready var auto_clear_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoClearSetting
@onready var auto_expand_think_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoExpandThinkSetting
@onready var auto_add_file_ref_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoAddFileRefSetting
@onready var send_shot_cut: BoxContainer = $SettingPanel/SettingItemsContainer/SendShotCut
@onready var http_proxy_host: BoxContainer = $SettingPanel/SettingItemsContainer/HBoxContainer/HttpProxyHost
@onready var http_proxy_port: BoxContainer = $SettingPanel/SettingItemsContainer/HBoxContainer/HttpProxyPort

#@onready var config_model_button: Button = $SettingPanel/SettingItemsContainer/ConfigModelButton
@onready var add_supplier_button: Button = %AddSupplierButton
@onready var supplier_list: VBoxContainer = %SupplierList
@onready var role_list: VBoxContainer = %RoleList
@onready var manage_role_button: Button = %ManageRoleButton
@onready var supplier_option_button: Button = %SupplierOptionButton
@onready var supplier_option_window: Window = $SupplierOptionWindow

const SUPPLIER_ITEM = preload("uid://cktcl3yjma34l")
const SETTING_ROLE_ITEM = preload("uid://dwlfm5aqjw7f4")
const EDIT_ROLE_WINDOW = preload("uid://cx0yeuxsc2kui")
const ROLE_OPTION_WINDOW = preload("uid://dma1q8o2by3nq")

# 添加新节点后需要在这里注册
@onready var setting_item_nodes = [
	auto_clear_setting,
	auto_expand_think_setting,
	auto_add_file_ref_setting,
	send_shot_cut,
	http_proxy_host,
	http_proxy_port
]

signal config_model
var suppliers: Array[AgentSupplierItem] = []
var _did_init: bool = false
var _setting_ready_connected: bool = false

func _ready() -> void:
	#print("settings ready")
	#init_item_values()
	supplier_option_button.pressed.connect(show_supplier_option_window)
	#init_signals()
	add_supplier_button.pressed.connect(on_click_add_supplier_button)
	visibility_changed.connect(_on_show_setting)
	manage_role_button.pressed.connect(on_click_manage_role_button)
	supplier_option_window.close_requested.connect(supplier_option_window.hide)

	# 连接角色变更信号
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.roles_changed.connect(refresh_roles)

	# 等待 setting_ready 后执行一次性初始化
	if AlphaAgentPlugin.global_setting.setting_is_ready:
		_try_init()
	elif not _setting_ready_connected:
		_setting_ready_connected = true
		AlphaAgentPlugin.global_setting.setting_ready.connect(_try_init, CONNECT_ONE_SHOT)

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

func show_supplier_option_window():
	AgentUiLayoutUtils.popup_centered_clamped(supplier_option_window, Vector2i(800, 800), self)

func init_models_supplier():
	supplier_option_window.init_models_supplier()
	pass

func _try_init():
	if _did_init:
		return
	if not AlphaAgentPlugin.global_setting.setting_is_ready:
		return
	_did_init = true
	init_item_values()
	init_signals()
	init_models_supplier()

func _on_show_setting():
	if visible:
		_try_init()
		for supplier in suppliers:
			supplier.update_current_model()

func refresh_roles():
		pass

func on_click_manage_role_button():
		var role_window = ROLE_OPTION_WINDOW.instantiate() as AgentRoleOptionWindow
		get_tree().root.add_child(role_window)
		AgentUiLayoutUtils.popup_centered_clamped(role_window, Vector2i(800, 600), get_tree().root)


func on_create_role_window_created(role_info: AgentRoleConfig.RoleInfo):
	var new_role := SETTING_ROLE_ITEM.instantiate() as AgentSettingRoleItem
	role_list.add_child(new_role)
	new_role.set_role_info(role_info)
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.roles_changed.emit()

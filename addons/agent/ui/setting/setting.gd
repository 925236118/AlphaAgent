@tool
extends ScrollContainer

@onready var auto_clear_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoClearSetting
@onready var auto_expand_think_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoExpandThinkSetting
@onready var auto_add_file_ref_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoAddFileRefSetting
@onready var send_shot_cut: BoxContainer = $SettingPanel/SettingItemsContainer/SendShotCut
@onready var http_proxy_host: BoxContainer = $SettingPanel/SettingItemsContainer/HBoxContainer/HttpProxyHost
@onready var http_proxy_port: BoxContainer = $SettingPanel/SettingItemsContainer/HBoxContainer/HttpProxyPort
@onready var quick_model_option: OptionButton = %QuickModelOption
@onready var compress_threshold_spin: SpinBox = %CompressThresholdSpin
@onready var search_provider_option: OptionButton = %SearchProviderOption
@onready var search_kimi_key_edit: LineEdit = %SearchKimiKeyEdit
@onready var search_deepseek_key_edit: LineEdit = %SearchDeepSeekKeyEdit
@onready var search_zhihu_access_secret_edit: LineEdit = %ZhihuAccessSecretEdit
@onready var load_recent_chat_setting: BoxContainer = %LoadRecentChatSetting
@onready var show_modified_files_setting: BoxContainer = %ShowModifiedFilesSetting
@onready var layout_option: OptionButton = %PluginLayoutOption
@onready var layout_status: Label = %PluginLayoutStatus
@onready var refresh_layout_button: Button = %RefreshLayoutButton

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
	load_recent_chat_setting,
	show_modified_files_setting,
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
	%ResetConfigButton.pressed.connect(_on_reset_config_pressed)
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
	singleton.models_changed.connect(_init_quick_model_option)

	# 等待 setting_ready 后执行一次性初始化
	if AlphaAgentPlugin.global_setting.setting_is_ready:
		_try_init()
	elif not _setting_ready_connected:
		_setting_ready_connected = true
		AlphaAgentPlugin.global_setting.setting_ready.connect(_try_init, CONNECT_ONE_SHOT)

func _on_reset_config_pressed() -> void:
	var host := EditorInterface.get_base_control()
	var controller = host.get_node_or_null("AlphaAgentResetController")
	if controller == null:
		controller = load("res://addons/agent/scripts/plugin_reset_controller.gd").new()
		controller.name = "AlphaAgentResetController"
		host.add_child(controller)
	elif not controller.running:
		controller.dialog.popup_centered()

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
	if setting_item.setting_key == "show_modified_files":
		var panel = AlphaAgentSingleton.get_instance().main_panel
		if is_instance_valid(panel):
			panel.show_edited_file_container()

func on_click_add_supplier_button():
	var new_supplier := SUPPLIER_ITEM.instantiate() as AgentSupplierItem
	supplier_list.add_child(new_supplier)
	new_supplier.editing = true

func show_supplier_option_window():
	supplier_option_window.popup_centered()
	pass

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
	_init_quick_model_option()
	_init_compress_threshold()
	_init_search_config()
	_init_layout_config()

func _init_layout_config() -> void:
	layout_option.select(AlphaAgentPlugin.global_setting.plugin_layout)
	if not layout_option.item_selected.is_connected(_on_layout_selected):
		layout_option.item_selected.connect(_on_layout_selected)
	if not refresh_layout_button.pressed.is_connected(AlphaAgentPlugin.request_layout_refresh):
		refresh_layout_button.pressed.connect(AlphaAgentPlugin.request_layout_refresh)
	update_layout_status()

func _on_layout_selected(index: int) -> void:
	AlphaAgentPlugin.global_setting.plugin_layout = index
	AlphaAgentPlugin.global_setting.save_global_setting()
	update_layout_status()
	var plugin = AlphaAgentSingleton.get_instance().editor_plugin
	if is_instance_valid(plugin) and plugin.instance_layout != index:
		AlphaAgentPlugin.request_layout_refresh()

func update_layout_status() -> void:
	var plugin = AlphaAgentSingleton.get_instance().editor_plugin
	var pending = is_instance_valid(plugin) and plugin.instance_layout != AlphaAgentPlugin.global_setting.plugin_layout
	layout_status.visible = pending
	refresh_layout_button.visible = pending
	layout_option.select(AlphaAgentPlugin.global_setting.plugin_layout)

## 模型配置变化时同步可用的快速模型，排除停用和生图模型。
func _init_quick_model_option():
	quick_model_option.clear()
	quick_model_option.add_item("（使用当前模型）", 0)
	quick_model_option.set_item_metadata(0, {"supplier_id": "", "model_id": ""})
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if not model_manager:
		return
	var idx = 1
	var current_quick_id = AlphaAgentPlugin.global_setting.quick_model_model_id
	var current_quick_supplier_id = AlphaAgentPlugin.global_setting.quick_model_supplier_id
	var select_idx = 0
	for supplier in model_manager.suppliers:
		for model in supplier.models:
			# 排除生图模型（不能用于对话/标题/压缩）
			if model.supports_image_generation:
				continue
			if not model.active:
				continue
			quick_model_option.add_item(supplier.name + " / " + model.name, idx)
			quick_model_option.set_item_metadata(idx, {"supplier_id": supplier.id, "model_id": model.id})
			if model.id == current_quick_id and supplier.id == current_quick_supplier_id:
				select_idx = idx
			idx += 1
	quick_model_option.select(select_idx)
	# 当前快速模型已停用、删除或改为生图模型时，同步清除持久化选择。
	if select_idx == 0 and (not current_quick_id.is_empty() or not current_quick_supplier_id.is_empty()):
		_on_quick_model_selected(0)
	if not quick_model_option.item_selected.is_connected(_on_quick_model_selected):
		quick_model_option.item_selected.connect(_on_quick_model_selected)

func _on_quick_model_selected(index: int):
	var meta = quick_model_option.get_item_metadata(index)
	if meta is Dictionary:
		AlphaAgentPlugin.global_setting.quick_model_supplier_id = meta.get("supplier_id", "")
		AlphaAgentPlugin.global_setting.quick_model_model_id = meta.get("model_id", "")
		AlphaAgentPlugin.global_setting.save_global_setting()

## 初始化压缩阈值 SpinBox
func _init_compress_threshold():
	compress_threshold_spin.value = AlphaAgentPlugin.global_setting.compress_threshold_ratio * 100.0
	if not compress_threshold_spin.value_changed.is_connected(_on_compress_threshold_changed):
		compress_threshold_spin.value_changed.connect(_on_compress_threshold_changed)

func _on_compress_threshold_changed(value: float):
	AlphaAgentPlugin.global_setting.compress_threshold_ratio = value / 100.0
	AlphaAgentPlugin.global_setting.save_global_setting()

## 初始化搜索配置
func _init_search_config():
	var gs = AlphaAgentPlugin.global_setting
	var providers = ["", "kimi", "zhihu", "deepseek"]
	var idx = providers.find(gs.search_provider)
	search_provider_option.select(idx if idx >= 0 else 0)
	search_kimi_key_edit.text = gs.search_kimi_api_key
	search_deepseek_key_edit.text = gs.search_deepseek_api_key
	search_zhihu_access_secret_edit.text = gs.search_zhihu_access_secret
	_update_search_config_visibility()
	if not search_provider_option.item_selected.is_connected(_on_search_provider_selected):
		search_provider_option.item_selected.connect(_on_search_provider_selected)
	if not search_kimi_key_edit.text_changed.is_connected(_on_search_kimi_key_changed):
		search_kimi_key_edit.text_changed.connect(_on_search_kimi_key_changed)
	if not search_deepseek_key_edit.text_changed.is_connected(_on_search_deepseek_key_changed):
		search_deepseek_key_edit.text_changed.connect(_on_search_deepseek_key_changed)
	if not search_zhihu_access_secret_edit.text_changed.is_connected(_on_search_zhihu_access_secret_changed):
		search_zhihu_access_secret_edit.text_changed.connect(_on_search_zhihu_access_secret_changed)

func _update_search_config_visibility():
	var idx = search_provider_option.selected
	# 0=禁用, 1=kimi, 2=zhihu, 3=deepseek
	search_kimi_key_edit.get_parent().visible = idx == 1
	search_zhihu_access_secret_edit.get_parent().visible = idx == 2
	search_deepseek_key_edit.get_parent().visible = idx == 3

func _on_search_provider_selected(index: int):
	var providers = ["", "kimi", "zhihu", "deepseek"]
	AlphaAgentPlugin.global_setting.search_provider = providers[index]
	AlphaAgentPlugin.global_setting.save_global_setting()
	_update_search_config_visibility()

func _on_search_kimi_key_changed(new_text: String):
	AlphaAgentPlugin.global_setting.search_kimi_api_key = new_text
	AlphaAgentPlugin.global_setting.save_global_setting()

func _on_search_deepseek_key_changed(new_text: String):
	AlphaAgentPlugin.global_setting.search_deepseek_api_key = new_text
	AlphaAgentPlugin.global_setting.save_global_setting()

func _on_search_zhihu_access_secret_changed(new_text: String):
	AlphaAgentPlugin.global_setting.search_zhihu_access_secret = new_text
	AlphaAgentPlugin.global_setting.save_global_setting()

func _on_show_setting():
	if visible:
		_try_init()
		_init_quick_model_option()
		_init_search_config()
		_init_layout_config()
		for supplier in suppliers:
			supplier.update_current_model()

func refresh_roles():
		pass

func on_click_manage_role_button():
		var role_window = ROLE_OPTION_WINDOW.instantiate() as AgentRoleOptionWindow
		add_child(role_window)
		role_window.popup_centered(Vector2i(800, 600))


func on_create_role_window_created(role_info: AgentRoleConfig.RoleInfo):
	var new_role := SETTING_ROLE_ITEM.instantiate() as AgentSettingRoleItem
	role_list.add_child(new_role)
	new_role.set_role_info(role_info)
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.roles_changed.emit()

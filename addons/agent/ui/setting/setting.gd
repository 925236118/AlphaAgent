@tool
extends ScrollContainer

@onready var auto_clear_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoClearSetting
@onready var auto_expand_think_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoExpandThinkSetting
@onready var auto_add_file_ref_setting: BoxContainer = $SettingPanel/SettingItemsContainer/AutoAddFileRefSetting
@onready var send_shot_cut: BoxContainer = $SettingPanel/SettingItemsContainer/SendShotCut
#@onready var config_model_button: Button = $SettingPanel/SettingItemsContainer/ConfigModelButton
@onready var add_supplier_button: Button = %AddSupplierButton
@onready var supplier_list: VBoxContainer = %SupplierList

const SUPPLIER_ITEM = preload("uid://cktcl3yjma34l")

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
	#config_model_button.pressed.connect(config_model.emit)
	init_models_supplier()
	visibility_changed.connect(_on_show_setting)

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

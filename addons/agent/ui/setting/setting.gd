@tool
extends ScrollContainer
@onready var setting_items_container: VBoxContainer = %SettingItemsContainer

func _ready() -> void:
	AlphaAgentPlugin.global_setting.load_global_setting()
	init_item_values()
	init_signals()

func init_item_values():
	var setting_items = setting_items_container.get_children()
	for setting_item in setting_items:
		if setting_item is AgentSettingItemBase:
			setting_item.set_value(AlphaAgentPlugin.global_setting[setting_item.setting_key])

func init_signals():
	var setting_items = setting_items_container.get_children()
	for setting_item in setting_items:
		if setting_item is AgentSettingItemBase:
			setting_item.value_changed.connect(save_settings.bind(setting_item))

func save_settings(setting_item: AgentSettingItemBase):
	AlphaAgentPlugin.global_setting[setting_item.setting_key] = setting_item.get_value()
	AlphaAgentPlugin.global_setting.save_global_setting()

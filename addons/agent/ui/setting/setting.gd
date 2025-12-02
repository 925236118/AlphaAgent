@tool
extends ScrollContainer
@onready var setting_items_container: VBoxContainer = %SettingItemsContainer

@onready var CONFIG = load("uid://b4bcww0bmnxt0")

func _ready() -> void:
	print('CONFIG.settings ',CONFIG.settings)
	read_settings()
	init_sinals()

func read_settings():
	var setting_items = setting_items_container.get_children()
	for setting_item: AgentSettingItemBase in setting_items:
		match setting_item.get_value_type():
			TYPE_BOOL:
				setting_item.set_value(CONFIG.settings.get(setting_item.setting_key, false))
			TYPE_BOOL:
				setting_item.set_value(CONFIG.settings.get(setting_item.setting_key, ""))

func init_sinals():
	var setting_items = setting_items_container.get_children()
	for setting_item: AgentSettingItemBase in setting_items:
		setting_item.value_changed.connect(save_settings)

func save_settings():
	var setting_items = setting_items_container.get_children()
	var dump_config = CONFIG.duplicate()
	for setting_item: AgentSettingItemBase in setting_items:
		dump_config.settings.set(setting_item.setting_key, setting_item.get_value())
	ResourceSaver.save(dump_config, "uid://b4bcww0bmnxt0")
	CONFIG = dump_config

@tool
class_name AgentSupplierItem
extends PanelContainer

@onready var supplier_show: VBoxContainer = %SupplierShow
@onready var expend_model_button: TextureButton = %ExpendModelButton
@onready var more_action_button: MenuButton = %MoreActionButton
@onready var setting_model_list: VBoxContainer = %SettingModelList
@onready var supplier_edit: VBoxContainer = %SupplierEdit
@onready var cancel_save_button: Button = %CancelSaveButton
@onready var save_button: Button = %SaveButton
@onready var supplier_title: Label = %SupplierTitle
@onready var edit_model_button: Button = %EditModelButton

# 编辑相关
@onready var supplier_name: LineEdit = %SupplierName
@onready var supplier_api_type: OptionButton = %SupplierAPIType
@onready var supplier_base_url: LineEdit = %SupplierBaseURL
@onready var supplier_secret_key: LineEdit = %SupplierSecretKey

const SETTING_MODEL_ITEM = preload("uid://t8tpl55g2wg0")

var model_manager_window: Window = null

const MODEL_MANAGER = preload("uid://dr7g6mrkb8u3e")

const ProviderConfig = [
	{
		"name": "OpenAI",
		"provider": "openai"
	},
	{
		"name": "DeepSeek",
		"provider": "deepseek"
	},
	{
		"name": "Ollama",
		"provider": "ollama"
	}
]

enum MoreActionType {
	Edit = 0,
	Remove = 1
}
var supplier_info: ModelConfig.SupplierInfo = null

var editing: bool = false:
	set(val):
		editing = val
		if editing:
			init_edit_fields()
		supplier_show.visible = not editing
		supplier_edit.visible = editing

func _ready() -> void:
	supplier_info = ModelConfig.SupplierInfo.new()
	editing = false
	expend_model_button.toggled.connect(on_toggle_expend_model_button)
	more_action_button.get_popup().id_pressed.connect(on_click_more_button)
	cancel_save_button.pressed.connect(on_click_cancel_save_button)
	save_button.pressed.connect(on_click_save_button)
	edit_model_button.pressed.connect(on_click_edit_model_button)
	supplier_api_type.item_selected.connect(_on_provider_changed)
	# setting_container.config_model.connect(_on_manage_models_pressed)

func on_toggle_expend_model_button(toggle_on: bool):
	expend_model_button.flip_v = toggle_on
	setting_model_list.visible = toggle_on

func on_click_more_button(id: MoreActionType):
	match id:
		MoreActionType.Edit:
			editing = true
		MoreActionType.Remove:
			if AlphaAgentPlugin.global_setting.model_manager.get_supplier_by_id(supplier_info.id) != null:
				AlphaAgentPlugin.global_setting.model_manager.remove_supplier(supplier_info)
			queue_free()

func on_click_cancel_save_button():
	editing = false

	pass

func on_click_save_button():
	refresh_setting_model_list()
	editing = false
	supplier_title.text = supplier_name.text
	supplier_info.name = supplier_name.text
	supplier_info.base_url = supplier_base_url.text
	supplier_info.api_key = supplier_secret_key.text
	supplier_info.provider = ProviderConfig[supplier_api_type.get_selected_id()]["provider"]
	if AlphaAgentPlugin.global_setting.model_manager.get_supplier_by_id(supplier_info.id) == null:
		AlphaAgentPlugin.global_setting.model_manager.add_supplier(supplier_info)
	else:
		AlphaAgentPlugin.global_setting.model_manager.update_supplier(supplier_info.id, supplier_info)
	var plugin = AlphaAgentPlugin.get_instance()
	if plugin != null:
		plugin.models_changed.emit()

func refresh_setting_model_list():
	var model_count = setting_model_list.get_child_count()
	if model_count > 0:
		for i in range(model_count):
			setting_model_list.get_child(model_count - 1 - i).queue_free()
	
	for model in supplier_info.models:
		var new_model := SETTING_MODEL_ITEM.instantiate() as AgentSettingModelItem
		setting_model_list.add_child(new_model)
		new_model.set_setting_model_info(model)

func set_supplier_info(supplier: ModelConfig.SupplierInfo):
	supplier_info = supplier
	supplier_title.text = supplier_info.name
	refresh_setting_model_list()

func init_edit_fields():
	if supplier_info == null:
		return
	supplier_name.text = supplier_info.name
	supplier_base_url.text = supplier_info.base_url
	supplier_secret_key.text = supplier_info.api_key
	var idx = -1
	for i in range(ProviderConfig.size()):
		if ProviderConfig[i].provider == supplier_info.provider:
			idx = i
			break
	supplier_api_type.select(idx)


# 打开模型管理窗口
func on_click_edit_model_button():
	if model_manager_window and is_instance_valid(model_manager_window):
		# 确保窗口可见并居中
		model_manager_window.popup_centered(Vector2i(600, 500))
		return

	model_manager_window = MODEL_MANAGER.instantiate()
	get_tree().root.add_child(model_manager_window)
	model_manager_window.set_supplier_info(supplier_info)
	# 绑定信号，当修改模型后，触发全局模型变化信号
	var plugin = AlphaAgentPlugin.get_instance()
	if plugin != null:
		model_manager_window.models_changed.connect(plugin.models_changed.emit)
	
	model_manager_window.popup_centered(Vector2i(600, 500))
	# 当窗口关闭时，销毁
	model_manager_window.close_requested.connect(func():
		model_manager_window.queue_free()
	)

func _on_provider_changed(index: int):
	# 只在添加新模型时更新 API Base（编辑时不改变）
	if editing:
		_update_default_api_base(index)

func _update_default_api_base(provider_index: int):
	match provider_index:
		0: # OpenAI
			supplier_base_url.text = "https://api.openai.com/v1"
			supplier_secret_key.placeholder_text = "sk-..."
		1: # DeepSeek
			supplier_base_url.text = "https://api.deepseek.com"
			supplier_secret_key.placeholder_text = "sk-..."
		2: # Ollama
			supplier_base_url.text = "http://localhost:11434"
			supplier_secret_key.text = ""
			supplier_secret_key.placeholder_text = "Ollama 不需要 API Key"

func update_current_model():
	if supplier_info.id == AlphaAgentPlugin.global_setting.model_manager.current_supplier_id:
		expend_model_button.flip_v = true
		setting_model_list.visible = true
		expend_model_button.button_pressed = true
	for model_item in setting_model_list.get_children():
		model_item.update_current_model()

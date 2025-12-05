@tool
extends Window

## 模型管理窗口

signal models_changed

@onready var model_list: VBoxContainer = %ModelList
@onready var add_model_button: Button = %AddModelButton
@onready var edit_panel: Panel = %EditPanel
@onready var model_name_edit: LineEdit = %ModelNameEdit
@onready var api_base_edit: LineEdit = %ApiBaseEdit
@onready var api_key_edit: LineEdit = %ApiKeyEdit
@onready var model_id_edit: LineEdit = %ModelIdEdit
@onready var max_tokens_edit: SpinBox = %MaxTokensEdit
@onready var provider_option: OptionButton = %ProviderOption
@onready var thinking_checkbox: CheckBox = %ThinkingCheckBox
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton

var model_manager: ModelConfig.ModelManager = null
var editing_model_id: String = ""

const MODEL_ITEM = preload("res://addons/agent/ui/models/model_item.tscn")

func _ready() -> void:
	add_model_button.pressed.connect(_on_add_model_pressed)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	edit_panel.hide()
	
	# 设置provider选项
	provider_option.clear()
	provider_option.add_item("OpenAI", 0)
	provider_option.add_item("DeepSeek", 1)
	provider_option.add_item("Ollama", 2)
	
	# 监听提供商变化以更新默认API Base
	provider_option.item_selected.connect(_on_provider_changed)

func set_model_manager(manager: ModelConfig.ModelManager):
	model_manager = manager
	_refresh_model_list()

func _refresh_model_list():
	# 清空列表
	for child in model_list.get_children():
		child.queue_free()
	
	if model_manager == null:
		return
	
	# 添加所有模型
	for model in model_manager.models:
		var item = MODEL_ITEM.instantiate()
		model_list.add_child(item)
		var is_current = model.id == model_manager.current_model_id
		item.set_model_info(model, is_current)
		item.edit_requested.connect(_on_edit_model.bind(model.id))
		item.delete_requested.connect(_on_delete_model.bind(model.id))

func _on_add_model_pressed():
	editing_model_id = ""
	_show_edit_panel()
	_clear_edit_fields()

func _on_edit_model(model_id: String):
	editing_model_id = model_id
	var model = model_manager.get_model_by_id(model_id)
	if model:
		_show_edit_panel(model)

func _on_delete_model(model_id: String):
	model_manager.remove_model(model_id)
	_refresh_model_list()
	models_changed.emit()

func _show_edit_panel(model: ModelConfig.ModelInfo = null):
	edit_panel.show()
	
	if model:
		model_name_edit.text = model.name
		api_base_edit.text = model.api_base
		api_key_edit.text = model.api_key
		model_id_edit.text = model.model_name
		max_tokens_edit.value = model.max_tokens
		thinking_checkbox.button_pressed = model.supports_thinking
		
		# 设置提供商选项
		if model.provider == "deepseek":
			provider_option.selected = 1
		elif model.provider == "ollama":
			provider_option.selected = 2
		else:
			provider_option.selected = 0

func _clear_edit_fields():
	model_name_edit.text = ""
	model_id_edit.text = ""
	max_tokens_edit.value = 8192
	provider_option.selected = 0
	thinking_checkbox.button_pressed = false  # OpenAI 默认不支持 thinking
	# 根据提供商设置默认 API Base
	_update_default_api_base(0)

func _on_provider_changed(index: int):
	# 只在添加新模型时更新 API Base（编辑时不改变）
	if editing_model_id == "":
		_update_default_api_base(index)

func _update_default_api_base(provider_index: int):
	match provider_index:
		0: # OpenAI
			api_base_edit.text = "https://api.openai.com/v1"
			api_key_edit.placeholder_text = "sk-..."
		1: # DeepSeek
			api_base_edit.text = "https://api.deepseek.com"
			api_key_edit.placeholder_text = "sk-..."
		2: # Ollama
			api_base_edit.text = "http://localhost:11434"
			api_key_edit.text = ""
			api_key_edit.placeholder_text = "Ollama 不需要 API Key"


func _on_save_pressed():
	var model_info = ModelConfig.ModelInfo.new()
	model_info.name = model_name_edit.text
	model_info.api_base = api_base_edit.text
	model_info.api_key = api_key_edit.text
	model_info.model_name = model_id_edit.text
	model_info.max_tokens = int(max_tokens_edit.value)
	# 从复选框读取是否支持 thinking
	model_info.supports_thinking = thinking_checkbox.button_pressed
	model_info.supports_tools = true
	
	# 根据选择设置提供商
	match provider_option.selected:
		1:
			model_info.provider = "deepseek"
		2:
			model_info.provider = "ollama"
		_:
			model_info.provider = "openai"
	
	if editing_model_id == "":
		# 添加新模型
		model_manager.add_model(model_info)
	else:
		# 更新现有模型
		model_manager.update_model(editing_model_id, model_info)
	
	_refresh_model_list()
	models_changed.emit()
	_hide_edit_panel()

func _on_cancel_pressed():
	_hide_edit_panel()

func _hide_edit_panel():
	edit_panel.hide()
	editing_model_id = ""

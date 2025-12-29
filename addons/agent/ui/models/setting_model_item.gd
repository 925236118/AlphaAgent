@tool
class_name AgentSettingModelItem
extends PanelContainer

@onready var model_name: Label = %ModelName
@onready var is_current_model: TextureRect = %IsCurrentModel
@onready var model_id: Label = %ModelID
@onready var support_reasoner: Label = %SupportReasoner
@onready var support_tool: Label = %SupportTool
@onready var is_active: CheckButton = %IsActive
@onready var edit_button: Button = %EditButton
@onready var remove_button: Button = %RemoveButton

var model_info: ModelConfig.ModelInfo = null
signal edit(model_info: ModelConfig.ModelInfo)
signal remove

func _ready() -> void:
	is_active.toggled.connect(on_toggled_is_active_button)
	edit_button.pressed.connect(on_edit_button_click)
	remove_button.pressed.connect(on_remove_button_click)

func set_setting_model_info(model: ModelConfig.ModelInfo):
	model_info = model
	model_name.text = model_info.name
	update_current_model()
	model_id.text = model_info.model_name
	support_reasoner.visible = model_info.supports_thinking
	support_tool.visible = model_info.supports_tools
	is_active.button_pressed = model_info.active

func on_toggled_is_active_button(toggled_on: bool):
	model_info.active = toggled_on
	AlphaAgentPlugin.global_setting.model_manager.update_model(model_info.supplier_id, model_info.id, model_info)
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.models_changed.emit()

func update_current_model():
	is_current_model.visible = model_info.id == AlphaAgentPlugin.global_setting.model_manager.current_model_id

func on_edit_button_click():
	edit.emit(model_info)

func on_remove_button_click():
	var supplier_id = model_info.supplier_id
	var model_id = model_info.id
	AlphaAgentPlugin.global_setting.model_manager.remove_model(supplier_id, model_id)
	#_refresh_model_list()
	remove.emit()

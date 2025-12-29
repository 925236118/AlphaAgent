@tool
class_name AgentSettingModelItem
extends PanelContainer

@onready var model_name: Label = %ModelName
@onready var is_current_model: TextureRect = %IsCurrentModel
@onready var model_id: Label = %ModelID
@onready var support_reasoner: Label = %SupportReasoner
@onready var support_tool: Label = %SupportTool
@onready var is_active: CheckButton = %IsActive

var model_info: ModelConfig.ModelInfo = null

func _ready() -> void:
	is_active.toggled.connect(on_toggled_is_active_button)

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
	var plugin = AlphaAgentPlugin.get_instance()
	if plugin != null:
		plugin.models_changed.emit()

func update_current_model():
	is_current_model.visible = model_info.id == AlphaAgentPlugin.global_setting.model_manager.current_model_id

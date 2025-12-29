@tool
extends PanelContainer

## 单个模型项

signal edit_requested
signal delete_requested

@onready var model_name_label: Label = %ModelNameLabel
@onready var model_info_label: Label = %ModelInfoLabel
@onready var edit_button: Button = %EditButton
@onready var delete_button: Button = %DeleteButton
@onready var current_indicator: Label = %CurrentIndicator

var model_id: String = ""

func _ready() -> void:
	edit_button.pressed.connect(func(): edit_requested.emit())
	delete_button.pressed.connect(func(): delete_requested.emit())

func set_model_info(model: ModelConfig.ModelInfo, is_current: bool = false):
	model_id = model.id
	model_name_label.text = model.name

	var info_parts = []
	info_parts.append(model.model_name)

	if model.supports_thinking:
		info_parts.append("Reasoning")
	if model.supports_tools:
		info_parts.append("Tools")

	model_info_label.text = " | ".join(info_parts)

	current_indicator.visible = is_current

@tool
extends PanelContainer
@onready var title_label: Button = %TitleLabel
@onready var tool_request: TextEdit = %ToolRequest
@onready var tool_response: TextEdit = %ToolResponse
@onready var detail_container: VBoxContainer = %DetailContainer

var id: String = ""

func update_title(title: String):
	title_label.text = title

func update_request(argument_string: String):
	var json = JSON.parse_string(argument_string)
	tool_request.text = JSON.stringify(json, "\t")

func update_response(result_string: String):
	var json = JSON.parse_string(result_string)
	tool_response.text = JSON.stringify(json, "\t")

func _on_title_label_pressed() -> void:
	detail_container.visible = not detail_container.visible

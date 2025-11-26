@tool
class_name MessageItem
extends MarginContainer

@onready var think_container: VBoxContainer = $VBoxContainer/ThinkContainer
@onready var think_content: RichTextLabel = %ThinkContent
@onready var message_container: VBoxContainer = $VBoxContainer/MessageContainer
@onready var message_content: RichTextLabel = %MessageContent
@onready var thinking_time_label: Label = %ThinkingTimeLabel
@onready var thinking_label: Label = %ThinkingLabel
@onready var expand_button: Button = %ExpandButton

@export var show_think: bool = false

var thinking: bool = false

var think_time: float = 0.0

func _ready() -> void:
	think_container.visible = show_think
	think_time = 0.0

func _process(delta: float) -> void:
	if thinking:
		think_time += delta
		thinking_time_label.text = "%.1f s" % think_time

func update_think_content(text: String):
	thinking = true
	think_container.show()
	think_content.text = text

func update_message_content(text: String):
	thinking = false
	if show_think:
		thinking_label.text = "思考了"
	message_container.show()
	message_content.show()
	message_content.text = text


func _on_expand_button_toggled(toggled_on: bool) -> void:
	print(toggled_on)
	expand_button.text = " ▲ " if toggled_on else " ▼ "
	think_content.visible = toggled_on

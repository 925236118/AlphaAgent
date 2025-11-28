@tool
class_name AgentChatMessageItem
extends MarginContainer

@onready var content_container: VBoxContainer = %ContentContainer
@onready var think_container: VBoxContainer = %ThinkContainer
@onready var think_content: RichTextLabel = %ThinkContent
@onready var message_container: VBoxContainer = %MessageContainer
@onready var message_content: RichTextLabel = %MessageContent
@onready var thinking_time_label: Label = %ThinkingTimeLabel
@onready var thinking_label: Label = %ThinkingLabel
@onready var expand_button: Button = %ExpandButton
@onready var use_tool_container: VBoxContainer = %UseToolContainer

@export var show_think: bool = false

var thinking: bool = false

var think_time: float = 0.0

func _ready() -> void:
	#expand_button.toggled.connect(_on_expand_button_toggled)
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
	message_content.text = text
	if message_content.text.trim_prefix(" ") != "":
		message_container.show()
		message_content.show()


#func _on_expand_button_toggled(toggled_on: bool) -> void:
	#expand_button.text = " ▲ " if toggled_on else " ▼ "
	#think_content.visible = toggled_on

func used_tools(tool_calls: Array[DeepSeekChatStream.ToolCallsInfo]):
	for tool in tool_calls:
		var panel = PanelContainer.new()
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color("#202020")
		panel.add_theme_stylebox_override("panel", stylebox)
		var label = Label.new()
		panel.add_child(label)
		use_tool_container.add_child(panel)
		label.text = "调用工具 " + tool.function.name

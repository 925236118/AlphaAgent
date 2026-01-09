@tool
class_name AgentChatMessageItem
extends MarginContainer

@onready var content_container: VBoxContainer = %ContentContainer
@onready var think_container: VBoxContainer = %ThinkContainer
@onready var think_content: RichTextLabel = %ThinkContent
@onready var message_container: VBoxContainer = %MessageContainer
@onready var message_content: RichTextLabel = %MessageContent
@onready var user_message_container: PanelContainer = %UserMessageContainer
@onready var user_message_content: RichTextLabel = %UserMessageContent
@onready var error_message_container: VBoxContainer = %ErrorMessageContainer
@onready var expand_icon: TextureRect = %ExpandIcon

@onready var thinking_time_label: Label = %ThinkingTimeLabel
@onready var thinking_label: Label = %ThinkingLabel
@onready var expand_button: Button = %ExpandButton
@onready var use_tool_container: VBoxContainer = %UseToolContainer
@onready var wait_using_tool: PanelContainer = %WaitUsingTool
@onready var wait_using_tool_rich_text_label: RichTextLabel = %WaitUsingTool/RichTextLabel
@onready var error_message_label: RichTextLabel = %ErrorMessageLabel

@onready var finish_message: HBoxContainer = %FinishMessage
@onready var success_message: HBoxContainer = %SuccessMessage
@onready var stop_message: HBoxContainer = %StopMessage
@onready var copy_button: Button = %CopyButton
@onready var re_send_button: Button = %ReSendButton

@export var show_think: bool = false

const USE_TOOL_ITEM = preload("uid://b7p6nfdynggrc")

var thinking: bool = false

var think_time: float = 0.0
var use_tool_list: Dictionary[String, Control] = {}

enum MessageType {
	None,
	SystemMessage,
	UserMessage,
	AssistantMessage,
	ToolMessage,
	ErrorMessage
}

var message_type: MessageType = MessageType.None

signal resend
signal copy

var message_id: String = ""

func _ready() -> void:
	expand_button.toggled.connect(_on_expand_button_toggled)
	think_container.visible = show_think
	think_time = 0.0
	message_content.meta_clicked.connect(on_click_rich_text_url)
	re_send_button.pressed.connect(resend.emit)
	copy_button.pressed.connect(copy.emit)

	var auto_expand_think = AlphaAgentPlugin.global_setting.auto_expand_think
	expand_button.button_pressed = auto_expand_think
	set_expand_icon_flip(auto_expand_think)
	think_content.visible = auto_expand_think

func _process(delta: float) -> void:
	if thinking:
		think_time += delta
		thinking_time_label.text = "%.1f s" % think_time

func update_think_content(text: String, start_timer: bool = true):
	message_type = MessageType.AssistantMessage
	# 只有在 show_think 为 true 时才更新 thinking 内容
	if not show_think:
		return

	thinking = start_timer
	think_container.show()
	think_content.text = text
	if not thinking:
		thinking_label.text = "思考了"

func update_message_content(text: String):
	message_type = MessageType.AssistantMessage
	thinking = false
	if show_think:
		thinking_label.text = "思考了"
	message_content.text = text
	if message_content.text.trim_prefix(" ") != "":
		message_container.show()
		message_content.show()

func update_user_message_content(text: String):
	message_type = MessageType.UserMessage
	user_message_container.show()
	user_message_content.show()
	user_message_content.text = text

func _on_expand_button_toggled(toggled_on: bool) -> void:
	#expand_button.text = " ▲ " if toggled_on else " ▼ "
	set_expand_icon_flip(toggled_on)
	think_content.visible = toggled_on

func set_expand_icon_flip(val: bool):
	expand_icon.flip_v = val

func response_use_tool():
	message_type = MessageType.ToolMessage
	wait_using_tool.show()

	var wait_placeholder_text = [
		" 正在等待 Agent 调用工具，请耐心等待 "
	]

	wait_using_tool_rich_text_label.text = "[agent_thinking freq=5.0 span=5.0] %s [/agent_thinking]" % wait_placeholder_text.pick_random()

func used_tools(tool_calls: Array):
	message_type = MessageType.ToolMessage
	wait_using_tool.hide()
	for tool in tool_calls:
		var use_tool_item = USE_TOOL_ITEM.instantiate()
		use_tool_container.add_child(use_tool_item)
		use_tool_item.update_title("调用工具 " + tool.function.name)
		use_tool_item.id = tool.id
		use_tool_item.update_request(tool.function.arguments)
		use_tool_list[tool.id] = use_tool_item

func update_used_tool_result(id: String, result: String):
	use_tool_list.get(id).update_response(result)

func on_click_rich_text_url(meta):
	var meta_string = str(meta)
	if meta_string.begins_with("{") and meta_string.ends_with("}"):
		var json = JSON.parse_string(meta_string)
		var path: String = json.path
		if path.ends_with(".tscn") or path.ends_with(".gd") or path.ends_with(".gdshader") or path.ends_with(".md") or path.ends_with(".txt") or path.ends_with(".res") or path.ends_with(".tres"):
			var resource = load(path)
			EditorInterface.edit_resource(resource)
	elif meta_string.begins_with("http"):
		OS.shell_open(meta_string)
	else:
		print("不支持的跳转方式，您可以复制链接后自行跳转： ", meta)

func update_error_message(error_content: String, detail: String):
	message_type = MessageType.ErrorMessage
	thinking = false
	use_tool_container.hide()
	wait_using_tool.hide()
	think_content.hide()
	message_container.hide()
	user_message_container.hide()

	error_message_container.show()
	error_message_label.text = "[color=red]错误：" + error_content + "[/color]\n" + detail

func update_finished_message(type: String):
	finish_message.show()
	if type == "Stop":
		stop_message.show()
		thinking = false
	elif type == "Success":
		success_message.show()
		thinking = false

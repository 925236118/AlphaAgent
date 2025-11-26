@tool
extends Control

@onready var user_input: TextEdit = %UserInput
@onready var send_button: Button = %SendButton
@onready var deep_seek_chat_stream: DeepSeekChatStream = %DeepSeekChatStream
@onready var message_content: Label = %MessageContent
@onready var think_content: Label = %ThinkContent
@onready var think_panel: PanelContainer = %ThinkPanel


var secret = "sk-208101f6f9fd42bbbd0cb45cd064b91a"

var message_list: Array[Dictionary] = []

func _ready() -> void:
	print(222)
	think_panel.hide()
	deep_seek_chat_stream.secret_key = secret
	init_message_list()
	deep_seek_chat_stream.think.connect(on_agent_think)
	deep_seek_chat_stream.message.connect(on_agent_message)
	deep_seek_chat_stream.generate_finish.connect(on_agent_finish)

	send_button.pressed.connect(on_click_send_message)

func init_message_list():
	message_list = [
		{
			"role": "system",
			"content": "你是一个Godot开发专家，你精通Godot 4.x版本的各种API，我将会让你根据我的需要开发一系列的功能。你需要调用各种工具或者Godot引擎的API完成我的想法。"
		}
	]

func on_click_send_message():
	user_input.editable = false
	send_button.disabled = true
	message_list.push_back({
		"role": "user",
		"content": user_input.text
	})
	deep_seek_chat_stream.post_message(message_list)

func on_agent_think(think: String):
	think_panel.show()
	think_content.text += think

func on_agent_message(msg: String):
	message_content.text += msg

func on_agent_finish():
	user_input.editable = true
	send_button.disabled = false

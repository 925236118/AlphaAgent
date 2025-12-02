@tool
extends Control

@onready var deep_seek_chat_stream: DeepSeekChatStream = %DeepSeekChatStream
@onready var title_generate_deep_seek_chat: DeepSeekChat = $TitleGenerateDeepSeekChat

@onready var message_list: VBoxContainer = %MessageList
@onready var new_chat_button: Button = %NewChatButton
@onready var chat_container: ScrollContainer = %ChatContainer
@onready var welcome_message: Control = %WelcomeMessage
@onready var input_container: MarginContainer = %InputContainer
@onready var chat_title: Label = %ChatTitle
@onready var history_container: AgentHistoryContainer = %HistoryContainer
@onready var article_container: Control = %ArticleContainer
@onready var history_button: Button = %HistoryButton
@onready var more_button: MenuButton = %MoreButton

@onready var tools: Node = $Tools

enum MoreButtonIds {
	Memory,
	Help,
	Setting
}

var help_window: Window = null

const CONFIG = preload("uid://b4bcww0bmnxt0")

const MESSAGE_ITEM = preload("uid://cjytvn2j0yi3s")

const HELP = preload("uid://b83qwags1ffo8")

var secret = CONFIG.secret_key

var messages: Array[Dictionary] = []

var current_message_item: AgentChatMessageItem = null
var current_message: String = ""
var current_think: String = ""
var current_title = "新对话":
	set(val):
		current_title = val
		chat_title.text = current_title
var first_chat: bool = true
var current_id: String = ""
var current_time: String = ""
var current_history_item: AgentHistoryContainer.HistoryItem = null

func _ready() -> void:
	# 展示欢迎语
	welcome_message.show()
	chat_container.hide()
	# 初始化AI模型相关信息
	init_message_list()
	deep_seek_chat_stream.secret_key = secret
	deep_seek_chat_stream.think.connect(on_agent_think)
	deep_seek_chat_stream.message.connect(on_agent_message)
	deep_seek_chat_stream.use_tool.connect(on_use_tool)
	deep_seek_chat_stream.generate_finish.connect(on_agent_finish)
	deep_seek_chat_stream.response_use_tool.connect(on_response_use_tool)

	new_chat_button.pressed.connect(on_click_new_chat_button)
	history_button.pressed.connect(on_click_history_button)
	input_container.send_message.connect(on_input_container_send_message)
	input_container.show_help.connect(show_help_window)

	# 初始化标题生成DeepSeek相关
	title_generate_deep_seek_chat.secret_key = secret
	title_generate_deep_seek_chat.use_thinking = false
	title_generate_deep_seek_chat.generate_finish.connect(on_title_generate_finish)

	history_container.recovery.connect(on_recovery_history)
	more_button.get_popup().id_pressed.connect(on_more_button_select)
func reset_message_info():
	current_message_item = null
	current_think = ""
	current_message = ""

# 初始化消息列表，添加系统提示词
func init_message_list():
	messages = [
		{
			"role": "system",
			"content": CONFIG.system_prompt.format({
				"project_memory": ''.join(CONFIG.memory.map(func(m): return "-" + m)),
				"global_memory": "无"
			})
		}
	]

func on_input_container_send_message(user_message: Dictionary, message_content: String):
	welcome_message.hide()
	chat_container.show()
	history_container.hide()
	article_container.show()
	reset_message_info()
	messages.push_back(user_message)

	match input_container.get_input_mode():
		"Ask":
			deep_seek_chat_stream.tools = []
			deep_seek_chat_stream.use_thinking = true
			deep_seek_chat_stream.max_tokens = 64 * 1024
		"Agent":
			deep_seek_chat_stream.tools = tools.get_tools_list()
			deep_seek_chat_stream.use_thinking = true
			deep_seek_chat_stream.max_tokens = 64 * 1024

	var user_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	user_message_item.show_think = false
	message_list.add_child(user_message_item)
	user_message_item.update_user_message_content(message_content)

	current_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	current_message_item.show_think = deep_seek_chat_stream.use_thinking
	message_list.add_child(current_message_item)

	deep_seek_chat_stream.post_message(messages)

func on_agent_think(think: String):
	current_think += think
	current_message_item.update_think_content(current_think)
	chat_container.scroll_vertical = 100000

func on_agent_message(msg: String):
	current_message += msg
	current_message_item.update_message_content(current_message)
	chat_container.scroll_vertical = 100000

func on_response_use_tool():
	current_message_item.response_use_tool()
	chat_container.scroll_vertical = 100000

func on_use_tool(tool_calls: Array[DeepSeekChatStream.ToolCallsInfo]):
	current_message_item.used_tools(tool_calls)

	# 存储调用工具信息
	messages.push_back({
		"role": "assistant",
		"content": null,
		"reasoning_content": current_think,
		"tool_calls": tool_calls.map(func (tool: DeepSeekChatStream.ToolCallsInfo): return tool.to_dict())
	})

	reset_message_info()

	for tool in tool_calls:
		#print(tool.id)
		messages.push_back({
			"role": "tool",
			"tool_call_id": tool.id,
			"content": await tools.use_tool(tool)
		})

	await get_tree().create_timer(0.5).timeout
	current_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	current_message_item.show_think = deep_seek_chat_stream.use_thinking
	message_list.add_child(current_message_item)

	deep_seek_chat_stream.post_message(messages)

	chat_container.scroll_vertical = 100000

	current_history_item.title = current_title

	history_container.update_history(current_id, current_history_item)

func on_click_new_chat_button():
	clear()
	history_container.hide()
	article_container.show()

func clear():
	welcome_message.show()
	chat_container.hide()
	init_message_list()
	reset_message_info()

	first_chat = true
	current_title = "新对话"
	current_id = ""
	current_time = ""
	current_history_item = null

	input_container.init()

	var message_count = message_list.get_child_count()
	for i in message_count:
		message_list.get_child(message_count - i - 1).queue_free()

func on_click_history_button():
	history_container.visible = not history_container.visible
	article_container.visible = not article_container.visible

func on_agent_finish(finish_reason: String, total_tokens: float):
	#print("finish_reason ", finish_reason)
	#print("total_tokens ", total_tokens)
	input_container.set_usage_label(total_tokens, 128)

	if finish_reason == "tool_calls":
		return
	input_container.disable = false
	messages.push_back({
		"role": "assistant",
		"content": current_message,
		"reasoning_content": current_think
	})
	reset_message_info()

	#print(messages)

	if first_chat:
		#print(JSON.stringify(messages))
		current_history_item = AgentHistoryContainer.HistoryItem.new()
		current_id = generate_random_string(16)
		current_time = Time.get_datetime_string_from_system()
		title_generate_deep_seek_chat.post_message([
			{
				"role": "system",
			"content": """\
你是一个标题生成专家，你需要根据给你的AI交互的对话内容，生成一个内容总结出的标题，要求不能有符号和emoji，标题应简短易读，清晰明确。
			"""
			},
			{
				"role": "user",
				"content": JSON.stringify(messages)
			}
		])

	current_history_item.mode = input_container.get_input_mode()
	current_history_item.use_thinking = deep_seek_chat_stream.use_thinking
	current_history_item.id = current_id
	current_history_item.message = messages
	current_history_item.title = current_title
	current_history_item.time = current_time

	history_container.update_history(current_id, current_history_item)

func on_title_generate_finish(message: String, _think_msg: String):
	current_title = message
	#print("标题是 ", current_title)
	first_chat = false

	current_history_item.title = current_title
	history_container.update_history(current_id, current_history_item)

# 生成随机字符串函数
func generate_random_string(length: int) -> String:
	var characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result = ""

	for i in range(length):
		var random_index = randi() % characters.length()
		result += characters[random_index]

	return result

func on_recovery_history(history_item: AgentHistoryContainer.HistoryItem):
	history_container.hide()
	article_container.show()

	clear()
	first_chat = false
	welcome_message.hide()
	chat_container.show()

	current_history_item = history_item
	current_id = history_item.id
	current_title = history_item.title
	current_time = history_item.time
	messages = history_item.message
	input_container.set_input_mode(history_item.mode)

	for message in messages:
		if message.role == "system" or message.role == "tool" :
			continue
		var message_item = null
		message_item = MESSAGE_ITEM.instantiate()
		message_item.show_think = false
		message_list.add_child(message_item)

		if message.role == "user":
			message_item.update_user_message_content(message.content)
		elif message.role == "assistant":
			if message.has("tool_calls"):
				var tool_call_array: Array[DeepSeekChatStream.ToolCallsInfo] = []
				for tool_call in message.tool_calls:
					var tool_call_info = DeepSeekChatStream.ToolCallsInfo.new()
					tool_call_info.id = tool_call.get("id")
					tool_call_info.type = tool_call.get("type")
					tool_call_info.function = DeepSeekChatStream.ToolCallsInfoFunc.new()
					tool_call_info.function.arguments = tool_call.get("function").get("arguments")
					tool_call_info.function.name = tool_call.get("function").get("name")
					tool_call_array.push_back(tool_call_info)
				message_item.update_think_content(message.reasoning_content, false)
				message_item.used_tools(tool_call_array)
			else:
				message_item.update_think_content(message.reasoning_content, false)
				message_item.update_message_content(message.content)

func on_more_button_select(id: int):
	match id:
		MoreButtonIds.Memory:
			pass
		MoreButtonIds.Help:
			show_help_window()
		MoreButtonIds.Setting:
			pass

func show_help_window():
	if help_window:
		help_window.show()
	else:
		help_window = Window.new()
		var help = HELP.instantiate()
		help_window.add_child(help)
		help_window.title = "Alpha 帮助"
		get_tree().root.add_child(help_window)
		help_window.popup_centered(Vector2(1152, 648))
		help_window.close_requested.connect(help_window.hide)

func _exit_tree() -> void:
	if help_window:
		help_window.queue_free()

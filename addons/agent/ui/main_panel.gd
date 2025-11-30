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
@onready var history_container: Control = %HistoryContainer
@onready var article_container: Control = %ArticleContainer
@onready var history_button: Button = %HistoryButton
@onready var more_button: MenuButton = %MoreButton

@onready var tools: Node = $Tools

const MESSAGE_ITEM = preload("uid://cjytvn2j0yi3s")

var secret = "sk-208101f6f9fd42bbbd0cb45cd064b91a"

var messages: Array[Dictionary] = []

var current_message_item: AgentChatMessageItem = null
var current_message: String = ""
var current_think: String = ""
var current_title = "":
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
	
	# 初始化标题生成DeepSeek相关
	title_generate_deep_seek_chat.secret_key = secret
	title_generate_deep_seek_chat.use_thinking = false
	title_generate_deep_seek_chat.generate_finish.connect(on_title_generate_finish)
	
func reset_message_info():
	current_message_item = null
	current_think = ""
	current_message = ""

# 初始化消息列表，添加系统提示词
func init_message_list():
	messages = [
		{
			"role": "system",
			"content": """\
# 角色
你是一个Godot开发专家，你精通Godot 4.x版本的各种API。
我将会让你根据我的需要开发一系列的功能。你需要调用各种工具或者Godot引擎的API完成我的想法。

# 技能
你可以根据发送给你的内容，返回逻辑代码。并说明逻辑。
项目以"res://"作为根目录，所有的路径应都为根目录下的绝对路径。操作文件不应该在根目录外。

# 输出
输出的内容应简短、准确。
输出的对话内容如果想使用标记，必须使用BBCode格式。你只能使用允许的BBCode标签，不能随便创造不存在的标签。输出列表的时候，**不要**输出前面的项目符号，例如'•'，'1.'，'a.'等。标题可以使用粗体标签和字体大小标签适当提示。BBCode的开始结尾标签应保持严格成对。
而如果是在markdown文件中，应该使用markdown语法。不应再使用bbcode。
由于当前的输出要展示在深色背景上，输出文字时应尽量选择浅色颜色，或者浅色背景加深色文字。如非必要，不要添加颜色标签。
## 允许的BBCode标签
- 字体大小: font_size 结束标签必须也是font_size
- 粗体: b
- 斜体: i
- 等宽字体: code
- 居中: center
- 居左: left
- 居右: right
- 颜色字体: color  [color={code/name}]{text}[/color]
- 背景颜色: bgcolor  [bgcolor={code/name}]{text}[/bgcolor]
- 无序列表: ul [ul]{items}[/ul]  列表项 {item} 必须以一行一个的形式提供。内部不应该出现例如li等标签
- 有序（编号）列表: ol  [ol type={type}]{items}[/ol]   {type}参数可以是： 1 - 数字，会尽量使用语言对应的数字系统。a、A - 小写和大写拉丁字母。i、I - 小写和大写罗马数字。 内部不应该出现例如li等标签
- 链接: url 作为链接标签使用
## 允许使用的颜色
- 红色 #ff7085: 用于重要错误信息等
- 橙色 #ffb373: 用于告警信息等
- 蓝色 #abc9ff: 用于提示信息、标题等
- 绿色 #42ffc2: 用于提示成功demg
- 黄色 #ffeda1: 用于需要用户确认的权限操作等
- 黑色 #000000: 用于浅色背景的文字颜色
## 标题规则
一级标题: font_size=18，粗体
二级标题: font_size=16，粗体，以大写数字加顿号空格开头，例如(一、 )
三级标题: font_size=14，粗体，以小写数字加点号空格开头，例如(1. )
## URL标签使用规则
一般情况下不应使用url标签。
如果用户希望输出某些网址，可以按照[url="链接地址"]链接名称[/url]的格式输出、
# 规则
如果要修改文件，应该尽可能多的收集信息，可以向用户询问问题以获得用户更多的想法。在最终修改内容前可以让用户确认。
如果调用工具修改了文件后，应在最后总结位置，将所有修改的文件以URL列表的形式展示出来。
列表项应保持以下格式：[url={"path": "res://path/to/file_name"}]file_name[/url]，等于号后面的内容应该是一个json字符串，必须包含大括号，如果有多个相同文件名的文件，应输出部分路径作为区分。
"""
		}
	]

func on_input_container_send_message(user_message: Dictionary, message_content: String):
	welcome_message.hide()
	chat_container.show()
	reset_message_info()
	messages.push_back(user_message)
	print(input_container.get_input_mode())
	match input_container.get_input_mode():
		"Ask":
			deep_seek_chat_stream.tools = []
			deep_seek_chat_stream.use_thinking = true
			deep_seek_chat_stream.max_tokens = 64 * 1024
		"Agent":
			deep_seek_chat_stream.tools = tools.get_tools_list()
			deep_seek_chat_stream.use_thinking = false
			deep_seek_chat_stream.max_tokens = 8 * 1024

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

	reset_message_info()
	# 存储调用工具信息
	messages.push_back({
		"role": "assistant",
		"content": null,
		"tool_calls": tool_calls.map(func (tool: DeepSeekChatStream.ToolCallsInfo): return tool.to_dict())
	})

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

func on_click_new_chat_button():
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
	pass

func on_agent_finish(finish_reason: String, total_tokens: float):
	#print("finish_reason ", finish_reason)
	#print("total_tokens ", total_tokens)
	if finish_reason != "tool_calls":
		input_container.disable = true
	input_container.set_usage_label(total_tokens, 128)
	messages.push_back({
		"role": "assistant",
		"content": current_message
	})
	reset_message_info()
	
	print(messages)
	
	if first_chat:
		print(JSON.stringify(messages))
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
	
	current_history_item.use_thinking = deep_seek_chat_stream.use_thinking
	current_history_item.id = current_id
	current_history_item.message = messages
	current_history_item.title = current_title
	current_history_item.time = current_time
	#history_container.update_history(current_id, current_history_item)

func on_title_generate_finish(message: String, _think_msg: String):
	current_title = message
	print("标题是 ", current_title)
	first_chat = false
	pass

# 生成随机字符串函数
func generate_random_string(length: int) -> String:
	var characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result = ""
	
	for i in range(length):
		var random_index = randi() % characters.length()
		result += characters[random_index]
	
	return result

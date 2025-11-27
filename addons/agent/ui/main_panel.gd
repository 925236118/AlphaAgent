@tool
extends Control

@onready var user_input: TextEdit = %UserInput
@onready var send_button: Button = %SendButton
@onready var deep_seek_chat_stream: DeepSeekChatStream = %DeepSeekChatStream
@onready var message_list: VBoxContainer = %MessageList
@onready var usage_label: Label = %UsageLabel

@onready var tools: Node = $Tools

const MESSAGE_ITEM = preload("uid://cjytvn2j0yi3s")

var secret = "sk-208101f6f9fd42bbbd0cb45cd064b91a"

var messages: Array[Dictionary] = []

var current_message_item: AgentChatMessageItem = null
var current_message: String = ""
var current_think: String = ""



func _ready() -> void:
	# 初始化AI模型相关信息
	init_message_list()
	deep_seek_chat_stream.secret_key = secret
	deep_seek_chat_stream.think.connect(on_agent_think)
	deep_seek_chat_stream.message.connect(on_agent_message)
	deep_seek_chat_stream.use_tool.connect(on_use_tool)
	deep_seek_chat_stream.generate_finish.connect(on_agent_finish)
	deep_seek_chat_stream.tools = tools.get_tools_list()

	send_button.pressed.connect(on_click_send_message)

func reset_message_info():
	current_message_item = null
	current_think = ""
	current_message = ""

# 初始化消息列表，添加系统提示词
func init_message_list():
	messages = [
		{
			"role": "system",
			"content": """
# 角色
你是一个Godot开发专家，你精通Godot 4.x版本的各种API。
我将会让你根据我的需要开发一系列的功能。你需要调用各种工具或者Godot引擎的API完成我的想法。

# 技能
你可以根据发送给你的内容，返回逻辑代码。并说明逻辑。

# 输出
输出的内容应简短、准确，文本内容如果想使用标记，可以使用BBCode格式。只能使用允许的BBCode标签。输出列表的时候，不要输出前面的项目符号，例如'•'，'1.'，'a.'等。
由于当前的输出要展示在深色背景上，输出文字时应尽量选择浅色颜色，或者浅色背景加深色文字。如非必要，不要添加颜色标签。
允许的BBCode标签有：
- 粗体: b
- 斜体: i
- 等宽字体: code
- 居中: center
- 居左: left
- 居右: right
- 颜色字体: color  [color={code/name}]{text}[/color]
- 背景颜色: bgcolor  [bgcolor={code/name}]{text}[/bgcolor]
- 无序列表: ul [ul]{items}[/ul]  列表项 {item} 必须以一行一个的形式提供。
- 有序（编号）列表: ol  [ol type={type}]{items}[/ol]   {type}参数可以是： 1 - 数字，会尽量使用语言对应的数字系统。a、A - 小写和大写拉丁字母。i、I - 小写和大写罗马数字。
"""
		}
	]

func on_click_send_message():
	reset_message_info()

	user_input.editable = false
	send_button.disabled = true
	messages.push_back({
		"role": "user",
		"content": user_input.text
	})

	current_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	current_message_item.show_think = deep_seek_chat_stream.use_thinking
	message_list.add_child(current_message_item)

	deep_seek_chat_stream.post_message(messages)

func on_agent_think(think: String):
	current_think += think
	current_message_item.update_think_content(current_think)

func on_agent_message(msg: String):
	current_message += msg
	current_message_item.update_message_content(current_message)

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
		print(tool.id)
		messages.push_back({
			"role": "tool",
			"tool_call_id": tool.id,
			"content": await tools.use_tool(tool)
		})

	await get_tree().create_timer(0.5).timeout
	current_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	current_message_item.show_think = deep_seek_chat_stream.use_thinking
	message_list.add_child(current_message_item)
	print("current_message_item: ", current_message_item)

	deep_seek_chat_stream.post_message(messages)


func on_agent_finish(finish_reason: String, total_tokens: float):
	print("finish_reason ", finish_reason)
	print("total_tokens ", total_tokens)
	user_input.editable = true
	send_button.disabled = false
	usage_label.text = "%.2f" % (total_tokens / (128 * 1024)) + "%"
	messages.push_back({
		"role": "assistant",
		"content": current_message
	})
	reset_message_info()

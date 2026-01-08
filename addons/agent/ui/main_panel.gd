@tool
class_name AgentMainPanel
extends Control

@onready var chat_models: Node = %ChatModels

@onready var message_list: VBoxContainer = %MessageList
@onready var new_chat_button: Button = %NewChatButton
@onready var welcome_message: Control = %WelcomeMessage
@onready var input_container: AgentInputContainer = %InputContainer
@onready var history_button: Button = %HistoryButton
@onready var back_chat_button: Button = %BackChatButton
@onready var top_bar_buttons: HBoxContainer = %TopBarButtons

@onready var setting_tabs: HBoxContainer = %SettingTabs
@onready var setting_tab_memory: Button = %SettingTabMemory
@onready var setting_tab_setting: Button = %SettingTabSetting
@onready var history_and_title: PanelContainer = %HistoryAndTitle

@onready var tools: AgentTools = $Tools
@onready var message_container: ScrollContainer = %MessageContainer

@onready var chat_container: VBoxContainer = %ChatContainer
@onready var setting_button: Button = %SettingButton
@onready var help_button: Button = %HelpButton

@onready var setting_container: ScrollContainer = %SettingContainer
@onready var memory_container: VBoxContainer = %MemoryContainer
@onready var plan_list: AgentPlanList = %PlanList

@onready var container_list = [
	chat_container,
	setting_container,
	memory_container
]

enum MoreButtonIds {
	Memory,
	Help,
	Setting
}

var help_window: Window = null

@onready var CONFIG = preload("uid://b4bcww0bmnxt0")

const MESSAGE_ITEM = preload("uid://cjytvn2j0yi3s")

const HELP = preload("uid://b83qwags1ffo8")

var messages: Array[Dictionary] = []

var current_message_item: AgentChatMessageItem = null
var current_message: String = ""
var current_think: String = ""
var current_title = "新对话":
	set(val):
		current_title = val
		history_and_title.set_title(current_title)
var first_chat: bool = true
var current_id: String = ""
var current_time: String = ""
var current_history_item: AgentHistoryAndTitle.HistoryItem = null
var current_random_message_id: String = ""

# 当前使用的聊天流客户端
var current_chat_stream = null
var current_title_chat = null

func _ready() -> void:
	show_container(chat_container)
	# 等待插件实例可用后再连接信号
	_connect_plugin_signals()
	# 展示欢迎语
	welcome_message.show()
	message_container.hide()

	# 初始化模型选择
	_init_model_selector()

	# 初始化角色选择
	_init_role_selector()

	back_chat_button.pressed.connect(on_click_back_chat_button)
	new_chat_button.pressed.connect(on_click_new_chat_button)
	setting_button.pressed.connect(on_show_setting)
	help_button.pressed.connect(show_help_window)
	#history_button.pressed.connect(on_click_history_button)

	input_container.send_message.connect(on_input_container_send_message)
	input_container.show_help.connect(show_help_window)
	input_container.show_setting.connect(on_show_setting)
	input_container.show_memory.connect(on_show_memory)
	input_container.stop_chat.connect(on_stop_chat)
	input_container.model_changed.connect(_on_model_selected)

	history_and_title.recovery.connect(on_recovery_history)

	setting_tab_memory.pressed.connect(func(): show_container(memory_container))
	setting_tab_setting.pressed.connect(func(): show_container(setting_container))

# 连接插件信号（使用单例，始终可用）
func _connect_plugin_signals():
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.update_plan_list.connect(on_update_plan_list)
	singleton.models_changed.connect(_on_models_changed)
	singleton.roles_changed.connect(_on_roles_changed)

# 初始化模型选择器
func _init_model_selector():
	await AlphaAgentPlugin.wait_for_scene_tree_frame()
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if model_manager == null:
		return

	var current_model = model_manager.get_current_model()
	var current_model_name = current_model.name if current_model else "Agent"

	# 更新输入容器中的模型选择器
	input_container.update_model_selector(
		model_manager.suppliers,
		model_manager.current_model_id,
		current_model_name
	)

func _init_role_selector():
	await AlphaAgentPlugin.wait_for_scene_tree_frame()
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager == null:
		return
	var current_role = role_manager.get_current_role()
	var current_role_id = current_role.id if current_role else ""
	input_container.update_role_selector(
		role_manager.roles,
		current_role_id
	)

# 模型选择回调
func _on_model_selected(supplier_id: String, model_id: String):
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if model_manager == null:
		return

	model_manager.set_current_model(supplier_id, model_id)

	# 更新输入容器的模型选择器显示
	_init_model_selector()


# 模型配置变更回调
func _on_models_changed():
	_init_model_selector()

func _on_roles_changed():
	_init_role_selector()

func reset_message_info():
	current_message_item = null
	current_think = ""
	current_message = ""

# 初始化消息列表，添加系统提示词
func init_message_list():
	CONFIG = load("uid://b4bcww0bmnxt0")
	var current_role = AlphaAgentPlugin.global_setting.role_manager.get_current_role()
	messages = [
		{
			"role": "system",
			"content": CONFIG.system_prompt.format({
				"project_memory": ''.join(AlphaAgentPlugin.project_memory.map(func(m): return "-" + m + "\n")),
				"global_memory": ''.join(AlphaAgentPlugin.global_memory.map(func(m): return "-" + m + "\n")),
				"role_prompt": current_role.prompt if current_role else "无"
			}),
			"id": generate_random_string(16)
		}
	]

func on_input_container_send_message(user_message: Dictionary, message_content: String):
	if first_chat:
		init_message_list()

	show_container(chat_container)
	welcome_message.hide()
	message_container.show()

	reset_message_info()

	var random_id = generate_random_string(16)
	user_message.id = random_id

	messages.push_back(user_message)

	var user_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	user_message_item.show_think = false
	user_message_item.message_id = random_id
	message_list.add_child(user_message_item)
	user_message_item.update_user_message_content(message_content)

	send_messages()

func send_messages():
	var use_thinking = input_container.get_use_thinking()
	var model_manager = AlphaAgentPlugin.global_setting.model_manager

	# 使用模型配置的max_tokens 和 thinking
	if model_manager:
		var supplier = model_manager.get_current_supplier()
		var model = model_manager.get_current_model()
		# 生成模型节点
		if supplier.provider == "ollama":
			current_chat_stream = OllamaChatStream.new()
			current_title_chat = OllamaChat.new()
		elif supplier.provider == "openai" or supplier.provider == "deepseek":
			current_chat_stream = OpenAIChatStream.new()
			current_title_chat = OpenAIChat.new()
			current_chat_stream.secret_key = supplier.api_key
			current_title_chat.secret_key = supplier.api_key
		else:
			printerr("不支持的供应商：", supplier.to_dict())

		# 设置属性
		current_chat_stream.api_base = supplier.base_url
		current_chat_stream.model_name = model.model_name
		current_chat_stream.max_tokens = model.max_tokens
		current_chat_stream.use_thinking = model.supports_thinking and use_thinking

		current_title_chat.api_base = supplier.base_url
		current_title_chat.model_name = model.model_name
		current_title_chat.max_tokens = model.max_tokens

	else:
		printerr("无法获取model_manager，请检查")
		return

	# 绑定模型事件
	current_chat_stream.think.connect(on_agent_think)
	current_chat_stream.message.connect(on_agent_message)
	current_chat_stream.use_tool.connect(on_use_tool)
	current_chat_stream.generate_finish.connect(on_agent_finish)
	current_chat_stream.response_use_tool.connect(on_response_use_tool)
	current_chat_stream.error.connect(on_generate_error)

	current_title_chat.generate_finish.connect(on_title_generate_finish)

	chat_models.add_child(current_chat_stream)
	chat_models.add_child(current_title_chat)

	# 根据角色设置工具列表
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	if role_manager:
		var role = role_manager.get_current_role()
		if role:
			current_chat_stream.tools = tools.get_filtered_tools_list(role.tools)
		else:
			# 没有角色时，默认使用所有工具
			current_chat_stream.tools = tools.get_tools_list()

	current_random_message_id = generate_random_string(16)
	current_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	# 始终根据用户选择的 use_thinking 来设置 show_think
	# 如果模型不支持 thinking，后续会在 on_agent_think 中跳过更新
	current_message_item.message_id = current_random_message_id
	current_message_item.show_think = use_thinking
	message_list.add_child(current_message_item)
	current_chat_stream.post_message(messages)
	await get_tree().process_frame
	scroll_message_container_to_bottom()

func on_agent_think(think: String):
	# 检查模型是否支持 thinking
	if think != "":
		var model_manager = AlphaAgentPlugin.global_setting.model_manager
		var model = model_manager.get_current_model() if model_manager else null
		var model_supports_thinking = model.supports_thinking if model else false

		# 只有模型支持 thinking 时才更新 thinking 内容
		if model_supports_thinking:
			current_think += think
			current_message_item.update_think_content(current_think)
			scroll_message_container_to_bottom()

		current_message_item.message_id = current_random_message_id

func on_agent_message(msg: String):
	current_message += msg
	if current_message_item:
		current_message_item.update_message_content(current_message)
		scroll_message_container_to_bottom()
		current_message_item.message_id = current_random_message_id

func on_response_use_tool():
	if current_message_item:
		current_message_item.response_use_tool()
		current_message_item.message_id = current_random_message_id
	scroll_message_container_to_bottom()

func on_use_tool(tool_calls: Array):
	# 兼容两种ToolCallsInfo类型
	current_message_item.used_tools(tool_calls)
	# 存储调用工具信息
	messages.push_back({
		"role": "assistant",
		"content": null,
		"reasoning_content": current_think,
		"tool_calls": tool_calls.map(func (tool): return tool.to_dict()),
		"id": current_random_message_id
	})


	for tool in tool_calls:
		#print(tool.id)
		var content = await tools.use_tool(tool)

		messages.push_back({
			"role": "tool",
			"tool_call_id": tool.id,
			"content": content,
			"id": current_random_message_id
		})

		current_message_item.update_used_tool_result(tool.id, content)

	reset_message_info()

	await get_tree().create_timer(0.5).timeout

	current_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	current_message_item.message_id = current_random_message_id
	current_message_item.show_think = current_chat_stream.use_thinking
	message_list.add_child(current_message_item)

	current_chat_stream.post_message(messages)

	scroll_message_container_to_bottom()

	current_history_item.title = current_title

	history_and_title.update_history(current_id, current_history_item)

func on_generate_error(error_info: Dictionary):
	#printerr("发生错误")
	printerr(error_info.error_msg)
	printerr(error_info.data)
	#current_message_item.update_think_content(current_think, false)
	current_message_item.update_error_message(error_info.error_msg, error_info.data)

	input_container.disable = false
	input_container.switch_button_to("Send")

func on_click_new_chat_button():
	if current_chat_stream != null and current_chat_stream.generatting:
		current_chat_stream.close()

	if current_title_chat:
		current_title_chat.queue_free()

	clear()
	input_container.disable = false
	show_container(chat_container)
	plan_list.update_list([])


func clear():
	welcome_message.show()
	message_container.hide()
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

	if current_chat_stream:
		current_chat_stream.queue_free()
	if current_title_chat:
		current_title_chat.queue_free()

func on_agent_finish(finish_reason: String, total_tokens: float):
	#print("finish_reason ", finish_reason)
	#print("total_tokens ", total_tokens)

	if finish_reason != "tool_calls":
		input_container.disable = false
		input_container.switch_button_to("Send")
		messages.push_back({
			"role": "assistant",
			"content": current_message,
			"reasoning_content": current_think,
			"id": current_random_message_id
		})
		current_message_item.update_finished_message("Success")
		await get_tree().process_frame
		scroll_message_container_to_bottom()
		current_message_item.resend.connect(on_resend_user_message.bind(current_message_item), CONNECT_ONE_SHOT)
		current_message_item.copy.connect(on_copy_output_message.bind(current_message_item))

		reset_message_info()
		if current_chat_stream:
			current_chat_stream.queue_free()

	input_container.set_usage_label(total_tokens, 128)
	#print(messages)

	if first_chat:
		#print(JSON.stringify(messages))
		current_history_item = AgentHistoryAndTitle.HistoryItem.new()
		current_id = generate_random_string(16)
		current_time = Time.get_datetime_string_from_system()
		var title_messages: Array[Dictionary] = [
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
		]
		current_title_chat.post_message(title_messages)

	#current_history_item.mode = input_container.get_input_mode()
	current_history_item.use_thinking = current_chat_stream.use_thinking
	current_history_item.id = current_id
	current_history_item.message = messages
	current_history_item.title = current_title
	current_history_item.time = current_time

	history_and_title.update_history(current_id, current_history_item)

func on_title_generate_finish(message: String, _think_msg: String):
	current_title = message
	#print("标题是 ", current_title)
	first_chat = false
	if current_history_item:
		current_history_item.title = current_title
	history_and_title.update_history(current_id, current_history_item)

	current_title_chat.queue_free()

# 生成随机字符串函数
func generate_random_string(length: int) -> String:
	var characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result = ""

	for i in range(length):
		var random_index = randi() % characters.length()
		result += characters[random_index]

	return result

func on_recovery_history(history_item: AgentHistoryAndTitle.HistoryItem):
	show_container(chat_container)

	clear()
	first_chat = false
	welcome_message.hide()
	message_container.show()

	current_history_item = history_item
	current_id = history_item.id
	current_title = history_item.title
	current_time = history_item.time
	messages = history_item.message
	#input_container.set_input_mode(history_item.mode)

	var message_item = null
	var last_message_item = null
	for message in messages:
		if message.role == "system" :
			continue
		if message.role != "tool":
			message_item = MESSAGE_ITEM.instantiate()
			# 根据历史记录中的 use_thinking 设置 show_think
			message_item.show_think = history_item.use_thinking
			message_list.add_child(message_item)

		if message.role == "user":
			if not last_message_item == null:
				last_message_item.update_finished_message("Success")
			message_item.update_user_message_content(message.content)
		elif message.role == "assistant":
			if message.has("tool_calls"):
				var tool_call_array: Array = []
				for tool_call in message.tool_calls:
					# 根据当前 chat_stream 类型创建对应的 ToolCallsInfo
					var tool_call_info
					tool_call_info = AgentModelUtils.ToolCallsInfo.new()
					tool_call_info.id = tool_call.get("id")
					tool_call_info.type = tool_call.get("type")
					tool_call_info.function = AgentModelUtils.ToolCallsInfoFunc.new()
					tool_call_info.function.arguments = tool_call.get("function").get("arguments")
					tool_call_info.function.name = tool_call.get("function").get("name")
					tool_call_array.push_back(tool_call_info)
				message_item.update_think_content(message.reasoning_content, false)
				message_item.used_tools(tool_call_array)
			else:
				message_item.update_think_content(message.reasoning_content, false)
				message_item.update_message_content(message.content)
		elif message.role == "tool":
			message_item.update_used_tool_result(message.tool_call_id, message.content)
		if message_item:
			(message_item as AgentChatMessageItem).message_id = message.get("id")
		last_message_item = message_item
	last_message_item.update_finished_message("Success")

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

func on_show_setting():
	show_container(setting_container)
	pass

func on_show_memory():
	pass

func _exit_tree() -> void:
	if help_window:
		help_window.queue_free()

func show_container(container: Control):
	back_chat_button.visible = container != chat_container
	history_and_title.visible = container == chat_container

	if container == memory_container or container == setting_container:
		setting_tabs.show()
		top_bar_buttons.hide()
		if container == memory_container:
			setting_tab_memory.button_pressed = true
		if container == setting_container:
			setting_tab_setting.button_pressed = true
	else:
		setting_tabs.hide()
		top_bar_buttons.show()

	for c: Control in container_list:
		c.visible = container == c

func on_click_back_chat_button():
	show_container(chat_container)

func on_stop_chat():
	current_chat_stream.close()
	input_container.disable = false
	input_container.switch_button_to("Send")
	if current_message_item:
		current_message_item.update_finished_message("Stop")
		current_message_item.resend.connect(on_resend_user_message.bind(current_message_item), CONNECT_ONE_SHOT)
		current_message_item.copy.connect(on_copy_output_message.bind(current_message_item))
	scroll_message_container_to_bottom()
	reset_message_info()

func on_update_plan_list(plan_array: Array[AlphaAgentSingleton.PlanItem]):
	plan_list.update_list(plan_array)

func on_resend_user_message(message_item_node: AgentChatMessageItem):
	var current_message_index = messages.find_custom(func(m): return m.id == message_item_node.message_id)

	var found_last_user_message_index = -1
	for i in current_message_index:
		var message = messages[current_message_index - i - 1]
		if message.get("role", "") == "user":
			found_last_user_message_index = current_message_index - i - 1
			break
	if found_last_user_message_index != -1:
		messages = messages.slice(0, found_last_user_message_index + 1)

	var message_count = message_list.get_child_count()
	var found_user_message_item_index = -1

	for i in range(message_item_node.get_index(), -1, -1):
		var message_item = message_list.get_child(i) as AgentChatMessageItem
		if message_item.message_type == AgentChatMessageItem.MessageType.UserMessage:
			found_user_message_item_index = i
			break

	for i in range(message_count - 1, found_user_message_item_index, -1):
		message_list.get_child(i).queue_free()

	await get_tree().process_frame

	send_messages()

func on_copy_output_message(message_item_node: AgentChatMessageItem):
	var found_user_message_item_index = -1
	for i in range(message_item_node.get_index(), -1, -1):
		var message_item = message_list.get_child(i) as AgentChatMessageItem
		if message_item.message_type == AgentChatMessageItem.MessageType.UserMessage:
			found_user_message_item_index = i
			break
	var assistant_result = []
	for i in range(found_user_message_item_index, message_item_node.get_index() + 1):
		var message_item = message_list.get_child(i) as AgentChatMessageItem
		if message_item.message_type == AgentChatMessageItem.MessageType.AssistantMessage:
			assistant_result.push_back(message_item.message_content.text)
			print("复制成功")

	DisplayServer.clipboard_set("\n".join(assistant_result))

func scroll_message_container_to_bottom():
	message_container.get_v_scroll_bar().set_as_ratio(1.0)

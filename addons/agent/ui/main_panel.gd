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
@onready var edited_files_container: AgentEditedFilesContainer = %EditedFilesContainer

@onready var setting_tabs: HBoxContainer = %SettingTabs
@onready var setting_tab_memory: Button = %SettingTabMemory
@onready var setting_tab_setting: Button = %SettingTabSetting
@onready var setting_tab_skill: Button = %SettingTabSkill

@onready var history_and_title: PanelContainer = %HistoryAndTitle

@onready var tools: AgentTools = $Tools
@onready var message_container: ScrollContainer = %MessageContainer

@onready var chat_container: VBoxContainer = %ChatContainer
@onready var setting_button: Button = %SettingButton
@onready var help_button: Button = %HelpButton

@onready var setting_container: ScrollContainer = %SettingContainer
@onready var memory_container: VBoxContainer = %MemoryContainer
@onready var skill_container: VBoxContainer = %SkillContainer

@onready var plan_list: AgentPlanList = %PlanList

@onready var footer_row1: HBoxContainer = %FooterRow1
@onready var footer_row2: HBoxContainer = %FooterRow2

@onready var container_list = [
	chat_container,
	setting_container,
	memory_container,
	skill_container
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
var auto_scroll_enabled: bool = true
var _title_generate_retry_count: int = 0
const MAX_TITLE_GENERATE_RETRY: int = 3
const MAX_TITLE_LENGTH: int = 20
const AUTO_SCROLL_BOTTOM_TOLERANCE := 10.0

var _steering_queue: Array[Dictionary] = []
var _is_tool_executing: bool = false
var _session_total_tokens: float = 0.0
var _compaction_in_progress: bool = false

func _ready() -> void:
	show_container(chat_container)
	# 等待插件实例可用后再连接信号
	_connect_plugin_signals()
	# 展示欢迎语
	welcome_message.show()
	message_container.hide()

	# 初始化模型选择和角色选择（等待 setting_ready）
	if AlphaAgentPlugin.global_setting.setting_is_ready:
		_on_setting_ready()
	else:
		AlphaAgentPlugin.global_setting.setting_ready.connect(_on_setting_ready, CONNECT_ONE_SHOT)
	_bind_message_scroll_events()
	resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")

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
	input_container.chat_mode_changed.connect(_on_chat_mode_changed)
	input_container.steering_message.connect(_on_steering_message)

	history_and_title.recovery.connect(on_recovery_history)

	setting_tab_memory.pressed.connect(func(): show_container(memory_container))
	setting_tab_setting.pressed.connect(func(): show_container(setting_container))
	setting_tab_skill.pressed.connect(func(): show_container(skill_container))

# 连接插件信号（使用单例，始终可用）
func _connect_plugin_signals():
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.update_plan_list.connect(on_update_plan_list)
	singleton.models_changed.connect(_on_models_changed)
	singleton.roles_changed.connect(_on_roles_changed)

func _on_setting_ready():
	_init_model_selector()
	_init_role_selector()

# 初始化模型选择器
func _init_model_selector():
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

	# 模型未变则跳过，打断 signal → update_model_selector → _on_model_selected 递归链
	if model_manager.current_supplier_id == supplier_id and model_manager.current_model_id == model_id:
		return

	model_manager.set_current_model(supplier_id, model_id)

	# 更新输入容器的模型选择器显示
	_init_model_selector()

# 模型配置变更回调
func _on_models_changed():
	_init_model_selector()

func _on_roles_changed():
	_init_role_selector()

func _on_chat_mode_changed(_mode: String) -> void:
	pass

func _on_steering_message(user_message: Dictionary, message_content: String) -> void:
	if current_chat_stream != null and current_chat_stream.generatting:
		_steering_queue.append({
			"message": user_message,
			"content": message_content
		})
		input_container.set_steering_count(_steering_queue.size())
		return
	on_input_container_send_message(user_message, message_content, false)

func _get_chat_mode() -> String:
	return input_container.get_chat_mode()

func _is_ask_mode() -> bool:
	return _get_chat_mode() == "ASK"

func _get_effective_tools_list() -> Array[Dictionary]:
	var role_manager = AlphaAgentPlugin.global_setting.role_manager
	var role = role_manager.get_current_role() if role_manager else null

	if _is_ask_mode():
		return tools.get_readonly_tools_list()

	if role and not role.tools.is_empty():
		return tools.get_filtered_tools_list(role.tools)

	# 无角色或角色工具列表为空时，回退只读工具集
	return tools.get_readonly_tools_list()

func _get_context_window() -> int:
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if model_manager == null:
		return AgentContextCompaction.DEFAULT_CONTEXT_WINDOW
	var model = model_manager.get_current_model()
	if model == null:
		return AgentContextCompaction.DEFAULT_CONTEXT_WINDOW
	return maxi(model.max_tokens * 16, AgentContextCompaction.DEFAULT_CONTEXT_WINDOW)

func _update_usage_label() -> void:
	var context_window := _get_context_window()
	input_container.set_usage_label(_session_total_tokens, context_window / 1024.0)


func reset_message_info():
	current_message_item = null
	current_think = ""
	current_message = ""

# 初始化消息列表，添加系统提示词
func init_message_list():
	CONFIG = load("uid://b4bcww0bmnxt0")
	var current_role = AlphaAgentPlugin.global_setting.role_manager.get_current_role()
	var skill_summary := ""
	var skill_manager = AlphaAgentPlugin.global_setting.skill_manager
	if skill_manager:
		skill_summary = skill_manager.get_skills_xml_summary()

	var mode_hint := ""
	if _is_ask_mode():
		mode_hint = "\n当前为 ASK 只读模式：仅可使用查询类工具，不可修改项目文件或执行写操作。"

	messages = [
		{
			"role": "system",
			"content": CONFIG.system_prompt.format({
				"project_memory": ''.join(AlphaAgentPlugin.project_memory.map(func(m): return "-" + m + "\n")),
				"global_memory": ''.join(AlphaAgentPlugin.global_memory.map(func(m): return "-" + m + "\n")),
				"role_prompt": current_role.prompt if current_role else "无"
			}) + ("\n\n" + skill_summary if not skill_summary.is_empty() else "") + mode_hint,
			"id": AlphaUtils.generate_random_string(16)
		}
	]

func on_input_container_send_message(user_message: Dictionary, message_content: String, allow_steering: bool = true):
	if allow_steering and current_chat_stream != null and (current_chat_stream.generatting or _is_tool_executing):
		_on_steering_message(user_message, message_content)
		return

	_clear_plan_list_if_all_finished()

	if first_chat:
		init_message_list()

	show_container(chat_container)
	welcome_message.hide()
	message_container.show()
	auto_scroll_enabled = true

	reset_message_info()

	var random_id = AlphaUtils.generate_random_string(16)
	user_message.id = random_id

	messages.push_back(user_message)

	var user_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	user_message_item.show_think = false
	user_message_item.message_id = random_id
	message_list.add_child(user_message_item)
	user_message_item.update_user_message_content(message_content)

	send_messages()

func _clear_plan_list_if_all_finished():
	if plan_list.is_all_finished():
		plan_list.update_list([])

func _maybe_compact_messages() -> void:
	if _compaction_in_progress or messages.is_empty():
		return
	if not AgentContextCompaction.should_compact(messages, _get_context_window()):
		return

	var cut_index := AgentContextCompaction.find_compaction_cut_index(messages)
	if cut_index <= 0:
		return

	var to_summarize := messages.slice(1, cut_index)
	if to_summarize.is_empty():
		return

	_compaction_in_progress = true
	input_container.show_status("正在压缩上下文...")
	var summary := await _request_compaction_summary(to_summarize)
	input_container.hide_status()
	if not summary.is_empty():
		messages = AgentContextCompaction.apply_compaction(messages, summary, cut_index)
	_compaction_in_progress = false

func _request_compaction_summary(to_summarize: Array) -> String:
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if model_manager == null:
		return _fallback_compaction_summary(to_summarize)

	var supplier = model_manager.get_current_supplier()
	var model = model_manager.get_current_model()
	if supplier == null or model == null:
		return _fallback_compaction_summary(to_summarize)

	var compaction_chat = null
	match supplier.provider:
		"openai":
			compaction_chat = OpenAIChat.new()
		"deepseek":
			compaction_chat = DeepSeekChat.new()
		"anthropic":
			compaction_chat = AnthropicChat.new()
		"gemini":
			compaction_chat = GeminiChat.new()
		"moonshot":
			compaction_chat = MoonShotChat.new()
		"minimax":
			compaction_chat = MiniMaxChat.new()
		"ollama":
			compaction_chat = OllamaChat.new()
		_:
			return _fallback_compaction_summary(to_summarize)

	compaction_chat.api_base = supplier.base_url
	compaction_chat.model_name = model.model_name
	compaction_chat.max_tokens = mini(model.max_tokens, 4096)
	if "secret_key" in compaction_chat:
		compaction_chat.secret_key = supplier.api_key

	chat_models.add_child(compaction_chat)
	var summary := ""
	var finished := false
	compaction_chat.generate_finish.connect(func(message: String, _think: String):
		summary = message
		finished = true
	, CONNECT_ONE_SHOT)
	compaction_chat.post_message(AgentContextCompaction.build_compaction_prompt(to_summarize))

	while not finished:
		await get_tree().process_frame

	compaction_chat.queue_free()
	return summary if not summary.is_empty() else _fallback_compaction_summary(to_summarize)

func _fallback_compaction_summary(to_summarize: Array) -> String:
	var lines: Array[String] = []
	for msg in to_summarize:
		if msg is Dictionary:
			var role := str(msg.get("role", ""))
			var content := str(msg.get("content", ""))
			if content.length() > 240:
				content = content.substr(0, 240) + "..."
			lines.append("%s: %s" % [role, content])
	return "\n".join(lines)

func send_messages():
	AlphaAgentPlugin.is_chat_stopped = false
	await _maybe_compact_messages()
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
		elif supplier.provider == "minimax":
			current_chat_stream = MiniMaxChatStream.new()
			current_title_chat = MiniMaxChat.new()
			current_chat_stream.secret_key = supplier.api_key
			current_title_chat.secret_key = supplier.api_key
		elif supplier.provider == "gemini":
			current_chat_stream = GeminiChatStream.new()
			current_title_chat = GeminiChat.new()
			current_chat_stream.secret_key = supplier.api_key
			current_title_chat.secret_key = supplier.api_key
		elif supplier.provider == "moonshot":
			current_chat_stream = MoonShotChatStream.new()
			current_title_chat = MoonShotChat.new()
			current_chat_stream.secret_key = supplier.api_key
			current_title_chat.secret_key = supplier.api_key
		elif supplier.provider == "openai":
			current_chat_stream = OpenAIChatStream.new()
			current_title_chat = OpenAIChat.new()
			current_chat_stream.secret_key = supplier.api_key
			current_title_chat.secret_key = supplier.api_key
		elif supplier.provider == "deepseek":
			current_chat_stream = DeepSeekChatStream.new()
			current_title_chat = DeepSeekChat.new()
			current_chat_stream.secret_key = supplier.api_key
			current_title_chat.secret_key = supplier.api_key
		elif supplier.provider == "anthropic":
			current_chat_stream = AnthropicChatStream.new()
			current_title_chat = AnthropicChat.new()
			current_chat_stream.secret_key = supplier.api_key
			current_title_chat.secret_key = supplier.api_key
		else:
			printerr("不支持的供应商：", supplier.to_dict())
			return

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

	current_chat_stream.tools = _get_effective_tools_list()

	current_random_message_id = AlphaUtils.generate_random_string(16)
	current_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	# 始终根据用户选择的 use_thinking 来设置 show_think
	# 如果模型不支持 thinking，后续会在 on_agent_think 中跳过更新
	current_message_item.message_id = current_random_message_id
	current_message_item.show_think = use_thinking
	message_list.add_child(current_message_item)
	current_message_item.show_generating_placeholder()
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
			if current_message_item:
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
	current_message_item.used_tools(tool_calls)
	messages.push_back({
		"role": "assistant",
		"content": null,
		"reasoning_content": current_think,
		"tool_calls": tool_calls.map(func (tool): return tool.to_dict()),
		"id": current_random_message_id
	})

	_is_tool_executing = true
	await _execute_tool_calls(tool_calls)
	_is_tool_executing = false

	if AlphaAgentPlugin.is_chat_stopped:
		return

	reset_message_info()

	if not _steering_queue.is_empty():
		var steering_item = _steering_queue.pop_front()
		input_container.set_steering_count(_steering_queue.size())
		var steering_message: Dictionary = steering_item.get("message", {})
		var steering_content: String = steering_item.get("content", "")
		steering_message.id = AlphaUtils.generate_random_string(16)
		messages.push_back(steering_message)

		var steering_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
		steering_message_item.show_think = false
		steering_message_item.message_id = steering_message.id
		message_list.add_child(steering_message_item)
		steering_message_item.update_user_message_content(steering_content)

	await get_tree().create_timer(0.5).timeout

	current_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	current_message_item.message_id = current_random_message_id
	current_message_item.show_think = current_chat_stream.use_thinking
	message_list.add_child(current_message_item)
	current_message_item.show_generating_placeholder()

	current_chat_stream.post_message(messages)

	scroll_message_container_to_bottom()

	if current_history_item:
		current_history_item.title = current_title
		history_and_title.update_history(current_id, current_history_item)

func _execute_tool_calls(tool_calls: Array) -> void:
	var readonly_calls: Array = []
	var write_calls: Array = []

	for tool in tool_calls:
		if tools.is_tool_readonly(tool.function.name):
			readonly_calls.append(tool)
		else:
			write_calls.append(tool)

	if not readonly_calls.is_empty():
		var readonly_results := await _execute_readonly_tools_parallel(readonly_calls)
		for item in readonly_results:
			if AlphaAgentPlugin.is_chat_stopped:
				return
			_append_tool_result(item.tool, item.content)

	for tool in write_calls:
		var content = await tools.use_tool(tool)
		if AlphaAgentPlugin.is_chat_stopped:
			return
		_append_tool_result(tool, content)

func _execute_readonly_tools_parallel(readonly_calls: Array) -> Array:
	var results: Array = []
	results.resize(readonly_calls.size())
	var done_count := 0

	for i in range(readonly_calls.size()):
		_execute_readonly_tool_at_index(i, readonly_calls[i], results, func(): done_count += 1)

	while done_count < readonly_calls.size():
		await get_tree().process_frame
	return results

func _execute_readonly_tool_at_index(index: int, tool_call: AgentModelUtils.ToolCallsInfo, results: Array, on_done: Callable) -> void:
	var content := await tools.use_tool(tool_call)
	results[index] = {"tool": tool_call, "content": content}
	on_done.call()

func _append_tool_result(tool: AgentModelUtils.ToolCallsInfo, content: String) -> void:
	messages.push_back({
		"role": "tool",
		"tool_call_id": tool.id,
		"content": content,
		"id": current_random_message_id
	})
	current_message_item.update_used_tool_result(tool.id, content)

func on_generate_error(error_info: Dictionary):
	#printerr("发生错误")
	printerr(error_info.error_msg)
	printerr(error_info.data)
	#current_message_item.update_think_content(current_think, false)
	if current_message_item:
		current_message_item.update_error_message(error_info.error_msg, error_info.data)
	AlphaAgentPlugin.is_chat_stopped = true

	input_container.disable = false
	input_container.switch_button_to("Send")
	input_container.focus_input()

func on_click_new_chat_button():
	AlphaAgentPlugin.is_chat_stopped = true
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
	auto_scroll_enabled = true

	first_chat = true
	current_title = "新对话"
	current_id = ""
	current_time = ""
	current_history_item = null
	_steering_queue.clear()
	_session_total_tokens = 0.0
	_compaction_in_progress = false

	input_container.init()
	input_container.set_steering_count(0)

	var message_count = message_list.get_child_count()
	for i in message_count:
		message_list.get_child(message_count - i - 1).queue_free()

	if current_chat_stream:
		current_chat_stream.queue_free()
	if current_title_chat:
		current_title_chat.queue_free()

func on_agent_finish(finish_reason: String, total_tokens: float):
	AlphaAgentSingleton.get_instance().emit_before_agent_finish(finish_reason, total_tokens)
	var use_thinking_for_history := false
	if current_chat_stream:
		use_thinking_for_history = current_chat_stream.use_thinking

	if total_tokens > 0:
		_session_total_tokens += total_tokens
	_update_usage_label()

	if finish_reason != "tool_calls":
		AlphaAgentPlugin.is_chat_stopped = true
		# 彻底结束，否则可能是调用工具
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
		show_edited_file_container()
		input_container.focus_input()

	input_container.set_usage_label(total_tokens, _get_context_window() / 1024.0)
	#print(messages)

	# 仅在本轮对话最终结束时生成标题，避免工具调用中间步骤重复触发并发请求
	if first_chat and finish_reason != "tool_calls":
		#print(JSON.stringify(messages))
		current_history_item = AgentHistoryAndTitle.HistoryItem.new()
		current_id = AlphaUtils.generate_random_string(16)
		current_time = Time.get_datetime_string_from_system()
		_title_generate_retry_count = 0
		current_title_chat.post_message(_build_title_messages())

	#current_history_item.mode = input_container.get_input_mode()
	if current_history_item:
		current_history_item.use_thinking = use_thinking_for_history
		current_history_item.id = current_id
		current_history_item.message = messages
		current_history_item.title = current_title
		current_history_item.time = current_time
		current_history_item.mode = _get_chat_mode()
		history_and_title.update_history(current_id, current_history_item)

func on_title_generate_finish(message: String, _think_msg: String):
	# 验证标题长度，超过20字则打回重新生成
	if message.length() > MAX_TITLE_LENGTH and _title_generate_retry_count < MAX_TITLE_GENERATE_RETRY:
		_title_generate_retry_count += 1
		#print("标题过长，重新生成: ", message)
		current_title_chat.post_message(_build_title_messages())
		return

	# 如果超过最大重试次数或标题长度合规，使用标题或回退到用户输入
	if _title_generate_retry_count >= MAX_TITLE_GENERATE_RETRY or message.length() <= MAX_TITLE_LENGTH:
		current_title = message if message.length() <= MAX_TITLE_LENGTH else _get_fallback_title()
	else:
		current_title = message

	#print("标题是 ", current_title)
	_title_generate_retry_count = 0
	first_chat = false
	if current_history_item:
		current_history_item.title = current_title
	history_and_title.update_history(current_id, current_history_item)

	current_title_chat.queue_free()

func _build_title_messages() -> Array[Dictionary]:
	return [
		{
			"role": "system",
			"content": """\
你是一个标题生成专家，你需要根据给你的AI交互的对话内容，生成一个内容总结出的标题，要求不能有符号和emoji，标题应简短易读，清晰明确，标题不能超过20个字。
			"""
		},
		{
			"role": "user",
			"content": JSON.stringify(messages)
		}
	]

func _get_fallback_title() -> String:
	# 获取用户的第一条输入作为备用标题
	for msg in messages:
		if msg.get("role") == "user":
			var content = msg.get("content", "")
			# 截取前20个字
			if content.length() > MAX_TITLE_LENGTH:
				return content.substr(0, MAX_TITLE_LENGTH) + "..."
			return content
	return "新对话"

func show_edited_file_container():
	edited_files_container.generate_edited_file_list(AgentTempFileManager.get_instance().temp_file_array)

func on_recovery_history(history_item: AgentHistoryAndTitle.HistoryItem):
	show_container(chat_container)

	clear()
	first_chat = false
	welcome_message.hide()
	message_container.show()
	auto_scroll_enabled = true

	current_history_item = history_item
	current_id = history_item.id
	current_title = history_item.title
	current_time = history_item.time
	messages = history_item.message
	if history_item.mode != "" and input_container.custom_dropdown:
		input_container.custom_dropdown.set_mode(history_item.mode, false)
		input_container.update_user_input_placeholder()

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
					tool_call_info.thought_signature = tool_call.get("thought_signature", tool_call.get("thoughtSignature", ""))
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

func _update_responsive_layout() -> void:
	var narrow := AgentUiLayoutUtils.is_narrow(size.x)
	footer_row2.visible = true
	for row: HBoxContainer in [footer_row1, footer_row2]:
		for child in row.get_children():
			if child is LinkButton:
				child.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if narrow else TextServer.OVERRUN_NO_TRIMMING
	if input_container.has_method("update_responsive_layout"):
		input_container.update_responsive_layout(size.x)

func show_help_window():
	if help_window:
		help_window.show()
	else:
		help_window = Window.new()
		var help = HELP.instantiate()
		help_window.add_child(help)
		help_window.title = "Alpha 帮助"
		get_tree().root.add_child(help_window)
		AgentUiLayoutUtils.popup_centered_clamped(help_window, Vector2i(1152, 648), self)
		help_window.close_requested.connect(help_window.hide)

func on_show_setting():
	show_container(setting_container)
	pass

func on_show_memory():
	show_container(memory_container)

func _exit_tree() -> void:
	if help_window:
		help_window.queue_free()

func show_container(container: Control):
	back_chat_button.visible = container != chat_container
	history_and_title.visible = container == chat_container

	if [memory_container, setting_container, skill_container].has(container):
		setting_tabs.show()
		top_bar_buttons.hide()
		match container:
			memory_container:
				setting_tab_memory.button_pressed = true
			setting_container:
				setting_tab_setting.button_pressed = true
			skill_container:
				setting_tab_skill.button_pressed = true
	else:
		setting_tabs.hide()
		top_bar_buttons.show()

	for c: Control in container_list:
		c.visible = container == c

	if container == chat_container:
		auto_scroll_enabled = true

func on_click_back_chat_button():
	show_container(chat_container)

func on_stop_chat():
	AlphaAgentPlugin.is_chat_stopped = true
	if current_chat_stream and is_instance_valid(current_chat_stream):
		current_chat_stream.close()
	_steering_queue.clear()
	input_container.set_steering_count(0)
	input_container.disable = false
	input_container.switch_button_to("Send")
	if current_message_item:
		current_message_item.update_finished_message("Stop")
		current_message_item.resend.connect(on_resend_user_message.bind(current_message_item), CONNECT_ONE_SHOT)
		current_message_item.copy.connect(on_copy_output_message.bind(current_message_item))
	scroll_message_container_to_bottom()
	reset_message_info()
	input_container.focus_input()

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

	DisplayServer.clipboard_set("\n".join(assistant_result))
	if not assistant_result.is_empty():
		input_container.show_status("已复制到剪贴板", 2.0)

func scroll_message_container_to_bottom():
	if not auto_scroll_enabled:
		return
	message_container.get_v_scroll_bar().set_as_ratio(1.0)

func _bind_message_scroll_events():
	var v_scroll_bar := message_container.get_v_scroll_bar()
	if v_scroll_bar:
		v_scroll_bar.value_changed.connect(_on_message_scroll_changed)

func _on_message_scroll_changed(_value: float):
	auto_scroll_enabled = _is_message_scroll_at_bottom()

func _is_message_scroll_at_bottom() -> bool:
	var v_scroll_bar := message_container.get_v_scroll_bar()
	if not v_scroll_bar:
		return true
	return (v_scroll_bar.value + v_scroll_bar.page) >= (v_scroll_bar.max_value - AUTO_SCROLL_BOTTOM_TOLERANCE)

func _unhandled_input(event: InputEvent) -> void:
	if not chat_container.visible:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE and not AlphaAgentPlugin.is_chat_stopped:
		on_stop_chat()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_N and event.ctrl_pressed:
		on_click_new_chat_button()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_L and event.ctrl_pressed:
		input_container.focus_input()
		get_viewport().set_input_as_handled()

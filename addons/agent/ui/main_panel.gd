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

const IMAGE_VIEWER = preload("res://addons/agent/ui/chat/image_viewer.tscn")

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

# 错误重试相关（仅对 retryable=true 的错误自动重试）
var _chat_retry_count: int = 0
const MAX_CHAT_RETRY: int = 3

# 上下文压缩相关
var _compressing: bool = false
var _compress_chat = null

# 余额查询相关
var balance_request: HTTPRequest = null

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

	back_chat_button.pressed.connect(on_click_back_chat_button)
	new_chat_button.pressed.connect(on_click_new_chat_button)
	setting_button.pressed.connect(on_show_setting)
	help_button.pressed.connect(show_help_window)
	#history_button.pressed.connect(on_click_history_button)

	input_container.send_message.connect(on_input_container_send_message)
	# 创建余额查询 HTTPRequest
	balance_request = HTTPRequest.new()
	add_child(balance_request)
	balance_request.request_completed.connect(_on_balance_request_completed)
	input_container.show_help.connect(show_help_window)
	input_container.show_setting.connect(on_show_setting)
	input_container.show_memory.connect(on_show_memory)
	input_container.stop_chat.connect(on_stop_chat)
	input_container.model_changed.connect(_on_model_selected)

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
	# 加载完成后获取余额
	_fetch_balance()

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
	# 刷新供应商余额
	_fetch_balance()

## 查询供应商余额（仅 DeepSeek 支持）
func _fetch_balance():
	var model_manager = AlphaAgentPlugin.global_setting.model_manager if AlphaAgentPlugin.global_setting else null
	if not model_manager:
		return
	var supplier = model_manager.get_current_supplier()
	# 仅 DeepSeek 支持余额查询
	if not supplier or supplier.provider != "deepseek":
		input_container.set_balance("")
		return
	if supplier.api_key.is_empty():
		input_container.set_balance("余额: 未配置密钥")
		return

	AgentModelUtils.apply_proxy_to_http_request(balance_request)
	var headers = ["Authorization: Bearer %s" % supplier.api_key]
	var url = supplier.base_url
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	# DeepSeek base_url 通常为 https://api.deepseek.com
	if url.ends_with("/v1") or url.ends_with("/v2") or url.ends_with("/v3"):
		url = url.substr(0, url.rfind("/v"))
	url += "/user/balance"

	var err = balance_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		input_container.set_balance("余额: 请求失败")

## 余额查询回调
func _on_balance_request_completed(_result, response_code, _headers, body: PackedByteArray):
	if response_code != 200:
		input_container.set_balance("余额: 获取失败(%d)" % response_code)
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		input_container.set_balance("余额: 解析失败")
		return

	var data = json.get_data()
	var balance_infos = data.get("balance_infos", [])
	if balance_infos is Array and balance_infos.size() > 0:
		var info = balance_infos[0]
		var currency = info.get("currency", "CNY")
		var total = info.get("total_balance", "0")
		var symbol = "¥" if currency == "CNY" else "$"
		input_container.set_balance("余额: %s%s" % [symbol, total])
	else:
		input_container.set_balance("余额: 0")

## 点击图片打开查看器
func _on_image_clicked(url: String):
	var viewer = IMAGE_VIEWER.instantiate()
	add_child(viewer)
	viewer.show_image(url)
	viewer.popup_centered()

## 长按图片触发保存
func _on_image_long_pressed(url: String):
	var img = _decode_image_from_data_url(url)
	if img == null:
		return
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.title = "保存图片"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png ;PNG 图片", "*.jpg ;JPEG 图片"])
	dialog.file_selected.connect(func(path: String):
		if path.ends_with(".jpg") or path.ends_with(".jpeg"):
			img.save_jpg(path)
		else:
			img.save_png(path)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(800, 600))

## 从 data URL 解码图片
func _decode_image_from_data_url(url: String) -> Image:
	if not url.begins_with("data:"):
		return null
	var comma_idx = url.find(",")
	if comma_idx < 0:
		return null
	var b64 = url.substr(comma_idx + 1)
	var bytes = Marshalls.base64_to_raw(b64)
	var img = Image.new()
	if bytes.size() >= 4 and bytes[0] == 0x89 and bytes[1] == 0x50:
		img.load_png_from_buffer(bytes)
	elif bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		img.load_jpg_from_buffer(bytes)
	elif bytes.size() >= 12 and bytes[0] == 0x52 and bytes[1] == 0x49:
		img.load_webp_from_buffer(bytes)
	else:
		img.load_png_from_buffer(bytes)
		if img.is_empty():
			img.load_jpg_from_buffer(bytes)
		if img.is_empty():
			img.load_webp_from_buffer(bytes)
	return img if not img.is_empty() else null

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
			"id": AlphaUtils.generate_random_string(16)
		}
	]

func on_input_container_send_message(user_message: Dictionary, message_content: String):
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
	user_message_item.image_clicked.connect(_on_image_clicked)
	user_message_item.image_long_pressed.connect(_on_image_long_pressed)
	# 如果有图片，传 content Array（message_item 会渲染图片缩略图）；否则传纯文本
	if user_message.has("content") and user_message["content"] is Array:
		user_message_item.update_user_message_content(user_message["content"])
	else:
		user_message_item.update_user_message_content(message_content)

	send_messages()

func _clear_plan_list_if_all_finished():
	if plan_list.is_all_finished():
		plan_list.update_list([])

func send_messages():
	AlphaAgentPlugin.is_chat_stopped = false
	var use_thinking = input_container.get_use_thinking()
	var model_manager = AlphaAgentPlugin.global_setting.model_manager

	# 使用模型配置的max_tokens 和 thinking
	if model_manager:
		var supplier = model_manager.get_current_supplier()
		var model = model_manager.get_current_model()
		# 生图模型走单独流程（MiniMax image-01 / image-01-live）
		if model and model.supports_image_generation:
			_send_image_generation(model, supplier)
			return
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
		elif supplier.provider == "volcengine":
			current_chat_stream = VolcengineChatStream.new()
			current_title_chat = VolcengineChat.new()
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

	# 如果配置了快速模型，用快速模型替换标题生成 chat
	var _quick_chat = _try_create_quick_chat()
	if _quick_chat:
		current_title_chat.queue_free()
		current_title_chat = _quick_chat

	current_title_chat.generate_finish.connect(on_title_generate_finish)
	if current_title_chat.has_signal("error"):
		current_title_chat.error.connect(on_title_chat_error)

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

	current_random_message_id = AlphaUtils.generate_random_string(16)
	current_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	# 始终根据用户选择的 use_thinking 来设置 show_think
	# 如果模型不支持 thinking，后续会在 on_agent_think 中跳过更新
	current_message_item.message_id = current_random_message_id
	current_message_item.show_think = use_thinking
	message_list.add_child(current_message_item)
	current_message_item.image_clicked.connect(_on_image_clicked)
	current_message_item.image_long_pressed.connect(_on_image_long_pressed)
	current_chat_stream.post_message(messages)
	await get_tree().process_frame
	scroll_message_container_to_bottom()

## 生图流程：MiniMax image-01 / image-01-live
func _send_image_generation(model, supplier):
	# 按供应商类型创建生图实例
	if supplier.provider == "volcengine":
		current_chat_stream = VolcengineImageGeneration.new()
	elif supplier.provider == "minimax":
		current_chat_stream = MiniMaxImageGeneration.new()
	else:
		printerr("不支持的生图供应商：", supplier.provider)
		return
	current_chat_stream.secret_key = supplier.api_key
	current_chat_stream.api_base = supplier.base_url
	current_chat_stream.model_name = model.model_name
	chat_models.add_child(current_chat_stream)

	# 连接信号
	current_chat_stream.image_generated.connect(_on_image_generated)
	current_chat_stream.error.connect(on_generate_error)

	# 从最后一条 user 消息提取 prompt 和 subject_refs（图生图参考图）
	var last_msg = messages[-1]
	var prompt = ""
	var subject_refs: Array = []
	var content = last_msg.get("content", "")
	if content is String:
		prompt = content
	elif content is Array:
		for part in content:
			if part is Dictionary:
				if part.get("type") == "text":
					prompt += part.get("text", "")
				elif part.get("type") == "image_url":
					# 图生图：提取图片 URL（统一存 url 字符串，各供应商在 generate 里格式化）
					var _img_dict = part.get("image_url", {})
					if _img_dict is Dictionary and _img_dict.has("url"):
						subject_refs.append(_img_dict["url"])

	# 创建 message_item
	current_random_message_id = AlphaUtils.generate_random_string(16)
	current_message_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	current_message_item.message_id = current_random_message_id
	message_list.add_child(current_message_item)
	current_message_item.image_clicked.connect(_on_image_clicked)
	current_message_item.image_long_pressed.connect(_on_image_long_pressed)
	current_message_item.update_message_content("正在生成图片...")

	# 调用生图（按供应商不同参数）
	var image_params = input_container.get_image_params()
	if supplier.provider == "volcengine":
		current_chat_stream.generate(prompt, subject_refs, "2K", "png")
	else:  # minimax
		var aspect_ratio = image_params.get("aspect_ratio", "1:1")
		var style_type = image_params.get("style_type", "")
		current_chat_stream.generate(prompt, subject_refs, aspect_ratio, 1, style_type)

	await get_tree().process_frame
	scroll_message_container_to_bottom()

## 生图完成回调：展示生成的图片
func _on_image_generated(images: Array):
	# 更新消息内容（清除"正在生成图片..."文本）
	if current_message_item:
		current_message_item.update_message_content("已生成 %d 张图片" % images.size())
		current_message_item.show_generated_images(images)
	# 保存 assistant 消息
	var content_text = "已生成 %d 张图片" % images.size()
	messages.push_back({
		"role": "assistant",
		"content": content_text,
		"generated_images": images,
		"id": current_random_message_id
	})
	# 把图片作为 user 消息加入对话历史，让后续模型能识别
	# （DeepSeek/MiniMax 限制：图片仅支持 user 消息）
	var image_content: Array = [{"type": "text", "text": "[上一轮生成的图片]"}]
	for url in images:
		image_content.append({"type": "image_url", "image_url": {"url": url}})
	messages.push_back({
		"role": "user",
		"content": image_content,
		"id": AlphaUtils.generate_random_string(16)
	})

	AlphaAgentPlugin.is_chat_stopped = true
	input_container.disable = false
	input_container.switch_button_to("Send")
	reset_message_info()

	if current_chat_stream:
		current_chat_stream.queue_free()

	# 首次对话：创建历史项 + 生成标题
	if first_chat:
		current_history_item = AgentHistoryAndTitle.HistoryItem.new()
		current_id = AlphaUtils.generate_random_string(16)
		current_time = Time.get_datetime_string_from_system()
		_title_generate_retry_count = 0
		# 创建标题生成 chat（优先用快速模型）
		current_title_chat = _try_create_quick_chat()
		if current_title_chat == null:
			var _mm = AlphaAgentPlugin.global_setting.model_manager if AlphaAgentPlugin.global_setting else null
			var _supplier = _mm.get_current_supplier() if _mm else null
			var _model = _mm.get_current_model() if _mm else null
			if _supplier and _model:
				current_title_chat = _create_chat_by_provider(_supplier, _model)
		if current_title_chat:
			chat_models.add_child(current_title_chat)
			current_title_chat.generate_finish.connect(on_title_generate_finish)
			if current_title_chat.has_signal("error"):
				current_title_chat.error.connect(on_title_chat_error)
			current_title_chat.post_message(_build_title_messages())
		first_chat = false

	# 更新历史
	if current_history_item:
		current_history_item.message = messages
		current_history_item.title = current_title
		current_history_item.time = current_time
		history_and_title.update_history(current_id, current_history_item)

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
		if AlphaAgentPlugin.is_chat_stopped:
			return

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
	current_message_item.image_clicked.connect(_on_image_clicked)
	current_message_item.image_long_pressed.connect(_on_image_long_pressed)

	current_chat_stream.post_message(messages)

	scroll_message_container_to_bottom()

	if current_history_item:
		current_history_item.title = current_title
		history_and_title.update_history(current_id, current_history_item)

func on_generate_error(error_info: Dictionary):
	# 检查火山引擎 ModelNotOpen 错误，提示用户去开通模型
	var _err_data = error_info.get("data", "")
	if _err_data is String and not _err_data.is_empty():
		var _parsed = JSON.parse_string(_err_data)
		if _parsed is Dictionary and _parsed.has("error"):
			var _err = _parsed["error"]
			if _err is Dictionary and _err.get("code") == "ModelNotOpen":
				error_info["error_msg"] = "模型未开通，请前往火山引擎控制台开通模型：\nhttps://console.volcengine.com/ark/"
	printerr("对话错误: ", error_info.get("error_msg", ""))
	printerr("错误数据: ", error_info.get("data", ""))

	var retryable: bool = error_info.get("retryable", false)
	# 兼容旧格式 error_info（无 retryable/error_type 字段）：根据 error_msg 推断网络类错误
	if not error_info.has("retryable"):
		var msg: String = error_info.get("error_msg", "")
		retryable = msg.contains("连接失败") or msg.contains("请求失败") or msg.contains("响应失败") or msg.contains("超时")

	if retryable and _chat_retry_count < MAX_CHAT_RETRY and not AlphaAgentPlugin.is_chat_stopped:
		_chat_retry_count += 1
		var delay := pow(2, _chat_retry_count - 1)  # 指数退避：1s, 2s, 4s
		if current_message_item:
			current_message_item.update_error_message("正在重试(%d/%d)... %s" % [_chat_retry_count, MAX_CHAT_RETRY, error_info.get("error_msg", "")], "")
		await get_tree().create_timer(delay).timeout
		if AlphaAgentPlugin.is_chat_stopped:
			_chat_retry_count = 0
			input_container.disable = false
			input_container.switch_button_to("Send")
			return
		# 重新发送（先关闭旧连接，再通过 post_message 重新连接）
		if current_chat_stream and is_instance_valid(current_chat_stream):
			current_chat_stream.close()
			current_chat_stream.post_message(messages)
		return

	# 不可重试或超过重试次数
	_chat_retry_count = 0
	if current_message_item:
		current_message_item.update_error_message(error_info.get("error_msg", ""), error_info.get("data", ""))
	AlphaAgentPlugin.is_chat_stopped = true

	input_container.disable = false
	input_container.switch_button_to("Send")

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

	input_container.init()

	var message_count = message_list.get_child_count()
	for i in message_count:
		message_list.get_child(message_count - i - 1).queue_free()

	if current_chat_stream:
		current_chat_stream.queue_free()
	if current_title_chat:
		current_title_chat.queue_free()

func on_agent_finish(finish_reason: String, total_tokens: float):
	# 成功结束，重置重试计数
	_chat_retry_count = 0
	#print("finish_reason ", finish_reason)
	#print("total_tokens ", total_tokens)
	var use_thinking_for_history := false
	if current_chat_stream:
		use_thinking_for_history = current_chat_stream.use_thinking

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

	var _mm = AlphaAgentPlugin.global_setting.model_manager if AlphaAgentPlugin.global_setting else null
	var _m = _mm.get_current_model() if _mm else null
	var _ctx_k = (_m.context_length / 1024.0) if _m and _m.context_length > 0 else 128.0
	input_container.set_usage_label(total_tokens, _ctx_k)
	#print(messages)

	# 检查是否需要压缩上下文（达到压缩阈值时触发）
	if finish_reason != "tool_calls":
		_check_context_compression(total_tokens)

	# 对话结束后刷新供应商余额
	if finish_reason != "tool_calls":
		_fetch_balance()

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

## 标题生成失败回调
func on_title_chat_error(error_info: Dictionary):
	printerr("标题生成错误: ", error_info.get("error_msg", ""))
	_title_generate_retry_count = 0
	first_chat = false
	# 标题回退为用户输入摘要
	current_title = _get_fallback_title()
	if current_history_item:
		current_history_item.title = current_title
		history_and_title.update_history(current_id, current_history_item)
	if current_title_chat:
		current_title_chat.queue_free()

## 检查是否需要压缩上下文（达到最大上下文的 80%）
func _check_context_compression(total_tokens: float):
	if _compressing:
		return
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if not model_manager:
		return
	var model = model_manager.get_current_model()
	if not model or model.context_length <= 0:
		return
	var threshold_ratio = AlphaAgentPlugin.global_setting.compress_threshold_ratio if AlphaAgentPlugin.global_setting else 0.8
	var threshold = int(model.context_length * threshold_ratio)
	if total_tokens >= threshold:
		_compress_context()

## 压缩上下文：将对话历史压缩成摘要，替换为新的初始上下文
func _compress_context():
	if _compressing:
		return
	_compressing = true

	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	var supplier = model_manager.get_current_supplier() if model_manager else null
	var model = model_manager.get_current_model() if model_manager else null
	if not supplier or not model:
		_compressing = false
		return

	_compress_chat = _try_create_quick_chat()
	if _compress_chat == null:
		_compress_chat = _create_compress_chat(supplier)
	if _compress_chat == null:
		printerr("上下文压缩：不支持该供应商 ", supplier.provider)
		_compressing = false
		return
	_compress_chat.secret_key = supplier.api_key
	_compress_chat.api_base = supplier.base_url
	_compress_chat.model_name = model.model_name
	_compress_chat.max_tokens = model.max_tokens

	chat_models.add_child(_compress_chat)
	_compress_chat.generate_finish.connect(_on_compress_finish)
	if _compress_chat.has_signal("error"):
		_compress_chat.error.connect(_on_compress_error)

	_compress_chat.post_message(_build_compress_messages())

## 创建压缩用非流式 chat 实例
func _create_compress_chat(supplier) -> Node:
	match supplier.provider:
		"deepseek":
			return DeepSeekChat.new()
		"minimax":
			return MiniMaxChat.new()
		"openai":
			return OpenAIChat.new()
		"moonshot":
			return MoonShotChat.new()
		"gemini":
			return GeminiChat.new()
		"ollama":
			return OllamaChat.new()
		"anthropic":
			return AnthropicChat.new()
		_:
			return null

## 构造压缩请求消息（序列化历史，丢弃图片 base64）
## 尝试用快速模型创建非流式 chat 实例，如果未配置快速模型则返回 null
func _try_create_quick_chat() -> Node:
	var model_manager = AlphaAgentPlugin.global_setting.model_manager if AlphaAgentPlugin.global_setting else null
	if not model_manager:
		return null
	var quick_id = AlphaAgentPlugin.global_setting.quick_model_model_id
	if quick_id.is_empty():
		return null
	var model = model_manager.get_model_by_id(quick_id)
	if not model:
		return null
	var supplier = model_manager.get_supplier_by_id(model.supplier_id)
	if not supplier:
		return null
	return _create_chat_by_provider(supplier, model)

## 按 provider 创建非流式 chat 实例
func _create_chat_by_provider(supplier, model) -> Node:
	var chat: Node = null
	match supplier.provider:
		"deepseek":
			chat = DeepSeekChat.new()
		"volcengine":
			chat = VolcengineChat.new()
		"minimax":
			chat = MiniMaxChat.new()
		"openai":
			chat = OpenAIChat.new()
		"moonshot":
			chat = MoonShotChat.new()
		"gemini":
			chat = GeminiChat.new()
		"ollama":
			chat = OllamaChat.new()
		"anthropic":
			chat = AnthropicChat.new()
		_:
			return null
	if "secret_key" in chat:
		chat.secret_key = supplier.api_key
	chat.api_base = supplier.base_url
	chat.model_name = model.model_name
	chat.max_tokens = model.max_tokens
	return chat

func _build_compress_messages() -> Array[Dictionary]:
	var prompt = CONFIG.compress_prompt
	if prompt.is_empty():
		prompt = """你是对话压缩专家。请将以下 AI 对话历史压缩成一份结构化的上下文摘要，供后续对话延续使用。

必须保留：
1. 【重要事实】已确定的结论、关键数据、关键文件路径与改动
2. 【待验证猜测】标注为"（待验证）"，不要当作事实
3. 【当前任务进度】已完成 / 进行中 / 待办，明确列出下一步
4. 【工具调用要点】调用了哪些工具、关键返回结果
5. 【用户偏好与约束】明确的指令、风格要求、约束条件

丢弃：寒暄、重复内容、已失效的中间尝试、图片原始数据。
输出结构化 Markdown，精简但信息无损。"""

	var history_text = ""
	for msg in messages:
		var role = msg.get("role", "")
		var content = msg.get("content", "")
		var content_str = ""
		if content is Array:
			var text_parts: Array = []
			for part in content:
				if part is Dictionary:
					if part.get("type") == "text":
						text_parts.append(part.get("text", ""))
					elif part.get("type") == "image_url":
						text_parts.append("[图片]")
			content_str = "\n".join(text_parts)
		elif content == null:
			content_str = "[调用工具]"
		else:
			content_str = str(content)
		# 附加 tool_calls 信息
		if msg.has("tool_calls") and msg["tool_calls"] is Array:
			var tool_info: Array = []
			for tc in msg["tool_calls"]:
				if tc is Dictionary and tc.has("function"):
					tool_info.append(tc["function"].get("name", "") + "(" + tc["function"].get("arguments", "") + ")")
			if tool_info.size() > 0:
				content_str += "\n调用工具: " + ", ".join(tool_info)
		history_text += "【%s】%s\n\n" % [role, content_str]

	return [
		{"role": "system", "content": prompt},
		{"role": "user", "content": "以下是需要压缩的对话历史：\n\n" + history_text}
	]

## 压缩完成回调：用摘要替换消息历史
func _on_compress_finish(message: String, _think_msg: String):
	# 保留原 system prompt + 压缩摘要
	var current_role = null
	var role_manager = AlphaAgentPlugin.global_setting.role_manager if AlphaAgentPlugin.global_setting else null
	if role_manager:
		current_role = role_manager.get_current_role()
	var system_content = CONFIG.system_prompt.format({
		"project_memory": ''.join(AlphaAgentPlugin.project_memory.map(func(m): return "-" + m + "\n")),
		"global_memory": ''.join(AlphaAgentPlugin.global_memory.map(func(m): return "-" + m + "\n")),
		"role_prompt": current_role.prompt if current_role else "无"
	})
	messages = [
		{"role": "system", "content": system_content, "id": AlphaUtils.generate_random_string(16)},
		{"role": "system", "content": "## 对话上下文摘要\n" + message, "id": AlphaUtils.generate_random_string(16)}
	]
	if current_history_item:
		current_history_item.message = messages
		history_and_title.update_history(current_id, current_history_item)
	if _compress_chat:
		_compress_chat.queue_free()
		_compress_chat = null
	_compressing = false
	# 在消息列表中展示压缩摘要
	var compress_item = MESSAGE_ITEM.instantiate() as AgentChatMessageItem
	compress_item.show_think = false
	message_list.add_child(compress_item)
	compress_item.update_message_content("## 📋 对话上下文摘要\n\n" + message)
	scroll_message_container_to_bottom()

## 压缩失败回调
func _on_compress_error(error_info: Dictionary):
	printerr("上下文压缩失败: ", error_info.get("error_msg", ""))
	if _compress_chat:
		_compress_chat.queue_free()
		_compress_chat = null
	_compressing = false

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
			message_item.image_clicked.connect(_on_image_clicked)
			message_item.image_long_pressed.connect(_on_image_long_pressed)

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
				message_item.update_think_content(message.get("reasoning_content", ""), false)
				message_item.used_tools(tool_call_array)
			else:
				message_item.update_think_content(message.get("reasoning_content", ""), false)
				message_item.update_message_content(message.content)
				if message.has("generated_images"):
					message_item.show_generated_images(message.generated_images)
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

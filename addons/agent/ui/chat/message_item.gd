@tool
class_name AgentChatMessageItem
extends MarginContainer

@onready var content_container: VBoxContainer = %ContentContainer
@onready var think_container: VBoxContainer = %ThinkContainer
@onready var think_content_panel: PanelContainer = %ThinkContentPanel
@onready var think_content: RichTextLabel = %ThinkContent
@onready var message_container: VBoxContainer = %MessageContainer
@onready var message_content: RichTextLabel = %MessageContent
@onready var generated_image_container: HFlowContainer = %GeneratedImageContainer
@onready var user_message_container: PanelContainer = %UserMessageContainer
@onready var user_message_content: RichTextLabel = %UserMessageContent
@onready var user_image_container: HFlowContainer = %UserImageContainer
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

# 长按检测
var _long_press_timer: Timer = null
var _long_press_url: String = ""

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
signal image_clicked(url: String)
signal image_long_pressed(url: String)

var message_id: String = ""

func _ready() -> void:
	expand_button.toggled.connect(_on_expand_button_toggled)
	think_container.visible = show_think
	think_time = 0.0
	message_content.meta_clicked.connect(on_click_rich_text_url)
	re_send_button.pressed.connect(resend.emit)
	copy_button.pressed.connect(copy.emit)
	# 长按检测 Timer
	_long_press_timer = Timer.new()
	_long_press_timer.wait_time = 0.5
	_long_press_timer.one_shot = true
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)

	var auto_expand_think = AlphaAgentPlugin.global_setting.auto_expand_think
	expand_button.button_pressed = auto_expand_think
	set_expand_icon_flip(auto_expand_think)
	think_content_panel.visible = auto_expand_think
	set_process(false)

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
	if start_timer and show_think:
		set_process(true)
	think_container.show()
	# 去除首尾空白和换行，避免RichTextLabel渲染出过大高度
	think_content.text = text.strip_edges()
	if not thinking:
		thinking_label.text = "思考了"

func update_message_content(text: String):
	message_type = MessageType.AssistantMessage
	thinking = false
	set_process(false)
	if show_think:
		thinking_label.text = "思考了"
	# 去除首尾空白和换行，避免RichTextLabel渲染出过大高度
	message_content.text = text.strip_edges()
	if message_content.text.trim_prefix(" ") != "":
		message_container.show()
		message_content.show()

func update_user_message_content(content: Variant):
	message_type = MessageType.UserMessage
	user_message_container.show()
	user_message_content.show()

	# 清空旧的图片
	for child in user_image_container.get_children():
		child.queue_free()
	user_image_container.hide()

	if content is String:
		user_message_content.text = content
	elif content is Array:
		# content 是 OpenAI vision 格式的块数组
		var text_parts: Array = []
		var image_urls: Array = []
		for part in content:
			if part is Dictionary:
				if part.get("type") == "text":
					text_parts.append(part.get("text", ""))
				elif part.get("type") == "image_url":
					image_urls.append(part.get("image_url", {}).get("url", ""))
		user_message_content.text = "\n".join(text_parts)
		# 渲染图片缩略图
		if image_urls.size() > 0:
			user_image_container.show()
			for url in image_urls:
				_add_image_from_data_url(url, user_image_container)

## 从 base64 data URL 解码并添加图片缩略图到指定容器
func _add_image_from_data_url(url: String, container: HFlowContainer) -> void:
	if not url.begins_with("data:"):
		return
	var comma_idx = url.find(",")
	if comma_idx < 0:
		return
	var b64 = url.substr(comma_idx + 1)
	var bytes = Marshalls.base64_to_raw(b64)
	var img = Image.new()
	var err = OK
	# 检测图片格式（magic bytes），不依赖 MIME 声明
	if bytes.size() >= 4 and bytes[0] == 0x89 and bytes[1] == 0x50:
		# PNG: \x89PNG
		err = img.load_png_from_buffer(bytes)
	elif bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		# JPEG: \xFF\xD8\xFF
		err = img.load_jpg_from_buffer(bytes)
	elif bytes.size() >= 12 and bytes[0] == 0x52 and bytes[1] == 0x49:
		# WebP: RIFF....WEBP
		err = img.load_webp_from_buffer(bytes)
	else:
		# 未知格式，依次尝试
		err = img.load_png_from_buffer(bytes)
		if err != OK:
			err = img.load_jpg_from_buffer(bytes)
		if err != OK:
			err = img.load_webp_from_buffer(bytes)
	if err != OK or img.is_empty():
		return
	# 缩放为缩略图（最大边 200px）
	var max_size = 200
	var w = img.get_width()
	var h = img.get_height()
	if w > max_size or h > max_size:
		var scale = min(float(max_size) / w, float(max_size) / h)
		img.resize(int(w * scale), int(h * scale), Image.INTERPOLATE_LANCZOS)
	var tex = ImageTexture.create_from_image(img)
	var tex_rect = TextureRect.new()
	tex_rect.texture = tex
	tex_rect.custom_minimum_size = Vector2(tex.get_width(), tex.get_height())
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	# 点击图片打开查看器，长按图片触发保存
	tex_rect.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_long_press_url = url
				_long_press_timer.start()
			else:
				if not _long_press_url.is_empty():
					_long_press_timer.stop()
					image_clicked.emit(url)
				_long_press_url = ""
		elif ev is InputEventMouseMotion and not _long_press_url.is_empty():
			_long_press_timer.stop()
			_long_press_url = ""
	)
	container.add_child(tex_rect)

## 长按超时回调：触发保存
func _on_long_press_timeout():
	var url = _long_press_url
	_long_press_url = ""
	if not url.is_empty():
		image_long_pressed.emit(url)

## 展示生成的图片（assistant 消息）
func show_generated_images(images: Array):
	generated_image_container.show()
	for url in images:
		_add_image_from_data_url(url, generated_image_container)

func _on_expand_button_toggled(toggled_on: bool) -> void:
	#expand_button.text = " ▲ " if toggled_on else " ▼ "
	set_expand_icon_flip(toggled_on)
	think_content_panel.visible = toggled_on

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
	thinking = false
	set_process(false)
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

func update_error_message(error_content: String, detail):
	message_type = MessageType.ErrorMessage
	thinking = false
	set_process(false)
	use_tool_container.hide()
	wait_using_tool.hide()
	think_content_panel.hide()
	message_container.hide()
	user_message_container.hide()

	error_message_container.show()
	var detail_text := JSON.stringify(detail) if detail is Dictionary else str(detail)
	error_message_label.text = "[color=red]错误：" + error_content + "[/color]\n" + detail_text

func update_finished_message(type: String):
	finish_message.show()
	if type == "Stop":
		stop_message.show()
		thinking = false
		set_process(false)
	elif type == "Success":
		success_message.show()
		thinking = false
		set_process(false)

@tool
class_name AgentInputContainer
extends MarginContainer

@onready var user_input: TextEdit = %UserInput
@onready var send_button: Button = %SendButton
@onready var clear_button: Button = %ClearButton
@onready var usage_label: Label = %UsageLabel
@onready var reference_list: HFlowContainer = %ReferenceList
@onready var input_mode_select: OptionButton = %InputModeSelect
@onready var input_menu_list: ItemList = %InputMenuList
@onready var use_thinking: CheckButton = %UseThinking
@onready var stop_button: Button = %StopButton
@onready var model_button: OptionButton = %ModelButton

const REFERENCE_ITEM = preload("uid://bewckbivwp036")

signal send_message(message: Dictionary, message_content: String, use_thinking: bool)
signal stop_chat
signal show_help
signal show_setting
signal show_memory
signal model_changed(model_id: String)
signal manage_models_requested

enum MenuListType {
	None,
	Command
}

var menu_list_type: MenuListType = MenuListType.None

var command_list = [
	{
		"command": "/memory",
		"description": "管理记忆"
	},
	{
		"command": "/help",
		"description": "帮助"
	},
	{
		"command": "/setting",
		"description": "显示设置"
	}
]

var disable: bool = false:
	set(value):
		disable = value
		user_input.editable = not value
		clear_button.disabled = value
		send_button.disabled = value

var menu_list = []

func _ready() -> void:
	update_user_input_placeholder()

	send_button.pressed.connect(on_click_send_message)
	clear_button.pressed.connect(on_click_clear_button)
	stop_button.pressed.connect(on_click_stop_button)

	user_input.text_changed.connect(on_user_input_text_changed)
	input_menu_list.item_selected.connect(on_input_menu_list_item_selected)

	# 初始化模型选择器
	if model_button:
		model_button.item_selected.connect(_on_model_selected)

	user_input.set_drag_forwarding(
		Callable(),
		user_input_can_drop,
		user_input_drop_data
	)

# 更新模型选择器
func update_model_selector(models: Array, current_model_id: String, current_model_name: String):
	if not model_button:
		return

	model_button.clear()

	var current_idx = 0
	var idx = 0
	for model in models:
		model_button.add_item(model.name)
		if model.id == current_model_id:
			current_idx = idx
			var supports_thinking: bool = model.supports_thinking
			use_thinking.visible = supports_thinking
			use_thinking.button_pressed = supports_thinking
		idx += 1

	# 添加分隔符和 "Manage Models..." 选项
	model_button.add_separator()
	var manage_idx = model_button.item_count
	model_button.add_item("Manage Models...")
	# 将 "Manage Models..." 设置为禁用状态（不可选中，但可点击）
	model_button.set_item_disabled(manage_idx, false)

	# 设置当前选中的模型
	model_button.selected = current_idx

# 模型选择回调
func _on_model_selected(idx: int):
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if not model_manager:
		return

	# 检查是否是最后一项（Manage Models...）
	if idx == model_button.item_count - 1:
		# 触发打开模型管理窗口
		manage_models_requested.emit()
		# 恢复之前的选择（防止选中 "Manage Models..."）
		var current_model = model_manager.get_current_model()
		if current_model:
			for i in range(model_manager.models.size()):
				if model_manager.models[i].id == current_model.id:
					model_button.selected = i
					break
	else:
		# 获取选中的模型ID
		if idx < model_manager.models.size():
			var supports_thinking: bool = model_manager.models[idx].supports_thinking
			use_thinking.visible = supports_thinking
			use_thinking.button_pressed = supports_thinking
			model_changed.emit(model_manager.models[idx].id)

## 是否可以将数据拖放到输入框
func user_input_can_drop (at_position: Vector2, data: Variant):
	var allow_types = ['files', "files_and_dirs", 'nodes', 'script_list_element', 'shader_list_element']
	return allow_types.find(data.type) != -1

## 将数据拖放到输入框后处理数据
func user_input_drop_data(at_position: Vector2, data: Variant):
	#print(data)
	var info_list = reference_list.get_children().map(func(node): return node.info)
	match data.type:
		"files":
			var file_info_list = info_list.filter(func(info): return info.type == "file")
			for file: String in data.files:
				if file_info_list.find_custom(func(info): return info.path == file) != -1:
					continue
				var reference_item = REFERENCE_ITEM.instantiate()
				reference_item.info = {
					"type": "file",
					"path": file
				}
				reference_list.add_child(reference_item)
				reference_item.set_label(file.get_file())
				reference_item.set_tooltip(file)
				if AlphaAgentPlugin.global_setting.auto_add_file_ref:
					user_input.insert_text_at_caret(file.get_file() + " ")
		"files_and_dirs":
			var file_info_list = info_list.filter(func(info): return info.type == "file")
			for file: String in data.files:
				if file_info_list.find_custom(func(info): return info.path == file) != -1:
					continue
				var reference_item = REFERENCE_ITEM.instantiate()
				reference_item.info = {
					"type": "file",
					"path": file
				}
				reference_list.add_child(reference_item)
				reference_item.set_label(file if file.ends_with("/") else file.get_file())
				reference_item.set_tooltip(file)
				if AlphaAgentPlugin.global_setting.auto_add_file_ref:
					user_input.insert_text_at_caret(file if file.ends_with("/") else file.get_file() + " ")
		"nodes":
			var node_info_list = info_list.filter(func(info): return info.type == "node")
			var root_node = EditorInterface.get_edited_scene_root()
			var current_scene = root_node.scene_file_path
			var root_node_name = root_node.name

			var nodes = data.nodes
			for node_path: String in nodes:
				var splite_array = node_path.split("/", false, 20)
				var path = splite_array[-1]

				if node_info_list.find_custom(func(info): return info.path == path and info.scene == current_scene) != -1:
					return
				var reference_item = REFERENCE_ITEM.instantiate()
				reference_item.info = {
					"type": "file",
					"node_path": path,
					"scene": current_scene
				}
				reference_list.add_child(reference_item)
				reference_item.set_label(current_scene.get_file() + "/" + path.split('/')[-1])

				reference_item.set_tooltip(current_scene + "/" + path)
				if AlphaAgentPlugin.global_setting.auto_add_file_ref:
					user_input.insert_text_at_caret(current_scene.get_file() + "/" + path.split('/')[-1] + " ")
			pass
		"script_list_element":
			var script = EditorInterface.get_script_editor().get_current_script()
			var file = ""
			if script != null:
				file = script.resource_path
			else:
				var script_editor := EditorInterface.get_script_editor()
				var editor_file_list: ItemList = script_editor.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1)
				var selected := editor_file_list.get_selected_items()
				if not selected:
					return
				var index := selected[0]
				file = editor_file_list.get_item_tooltip(index)
			var file_info_list = info_list.filter(func(info): return info.type == "file")

			if file_info_list.find_custom(func(info): return info.path == file) != -1:
				return
			var reference_item = REFERENCE_ITEM.instantiate()
			reference_item.info = {
				"type": "file",
				"path": file
			}
			reference_list.add_child(reference_item)
			reference_item.set_label(file.get_file())
			reference_item.set_tooltip(file)

			if AlphaAgentPlugin.global_setting.auto_add_file_ref:
				user_input.insert_text_at_caret(file.get_file() + " ")
		"shader_list_element":
			print("暂时不支持拖拽shader，请从文件系统中拖入。")
			#var shader_editor =
			pass

func get_input_mode():
	return input_mode_select.get_item_text(input_mode_select.get_selected_id())

func set_input_mode(name: String):
	var id = -1
	for i in input_mode_select.item_count:
		if input_mode_select.get_item_text(i) == name:
			id = input_mode_select.get_item_id(i)

	input_mode_select.select(id)

func set_input_mode_disable(disabled: bool):
	input_mode_select.disabled = disabled

func init():
	user_input.text = ""
	usage_label.text = ""
	clear_reference_list()
	set_input_mode_disable(false)
	switch_button_to("Send")
	input_menu_list.hide()

## 清空引用列表
func clear_reference_list():
	var ref_count = reference_list.get_child_count()
	for i in ref_count:
		reference_list.get_child(ref_count - i - 1).queue_free()

## 清空内容
func on_click_clear_button():
	user_input.text = ""
	clear_reference_list()

## 发送信息
func on_click_send_message():
	var message_text = user_input.text

	# 检查是否为命令
	if message_text.begins_with("/"):
		var command_parts = message_text.split(" ", false, 2)
		var command = command_parts[0]
		var args = command_parts.slice(1) if command_parts.size() > 1 else []

		# 处理命令逻辑
		handle_command(command, args)
		return

	if AlphaAgentPlugin.global_setting.auto_clear:
		init()

	# 正常消息处理
	self.disable = true
	switch_button_to("Stop")
	set_input_mode_disable(true)
	var info_list = reference_list.get_children().map(func(node): return node.info)
	var info_list_string = JSON.stringify(info_list)
	send_message.emit({
		"role": "user",
		"content": "用户输入的内容：" + message_text + "\n引用的内容信息：" + info_list_string
	}, message_text, use_thinking.button_pressed)


## 处理命令
func handle_command(command: String, args: PackedStringArray):
	#print("执行命令: ", command, " 参数: ", args)
	match command:
		"/memory":
			if args.size() == 0:
				# 执行默认memory操作
				show_memory.emit()
				init()
			elif args[0] == "project":
				# 执行memory project操作
				if args.size() == 2:
					#print("执行memory project命令")
					var CONFIG : AgentConfig = load("uid://b4bcww0bmnxt0")
					CONFIG.memory.push_back(args[1])
					ResourceSaver.save(CONFIG, "uid://b4bcww0bmnxt0")
				else:
					show_memory.emit()
					init()
			elif args[0] == "global":
				print("暂时不支持全局记忆")
			else:
				show_memory.emit()
				init()
		"/help":
			show_help.emit()
			init()
		"/setting":
			show_setting.emit()
			init()
		_:
			print("未知命令: ", command)

func set_usage_label(total_tokens: float, max_content_length: float):
	usage_label.text = "%.2f" % (total_tokens / (max_content_length * 1024)) + "%"
	usage_label.tooltip_text = ("%.2f" % (total_tokens / (max_content_length * 1024))) + "%" + " | " + ("%d / 128k usage tokens" % total_tokens)

func update_user_input_placeholder():
	match get_input_mode():
		"Ask":
			user_input.placeholder_text = "输入问题，不使用工具，获得更安全的体验。"
		"Agent":
			user_input.placeholder_text = "输入问题，或拖拽添加引用。"

func _on_input_mode_select_item_selected(index: int) -> void:
	update_user_input_placeholder()

func check_disallowed_char(text: String) -> bool:
	var disallowed_char = [" ", ",", ".", "，", "。"]
	for char in disallowed_char:
		if text.contains(char):
			return false
	return true

func on_user_input_text_changed():
	if user_input.text.begins_with("/") and check_disallowed_char(user_input.text):
		input_menu_list.show()
		input_menu_list.clear()
		menu_list = command_list.filter(func (command): return command.command.contains(user_input.text))
		for command_item in menu_list:
			input_menu_list.add_item(command_item.command + " " + command_item.description)
		menu_list_type = MenuListType.Command
	else:
		menu_list_type = MenuListType.None
		input_menu_list.hide()
		input_menu_list.clear()

func on_input_menu_list_item_selected(index: int):
	match menu_list_type:
		MenuListType.Command:
			user_input.text = menu_list[index].command
			input_menu_list.hide()
			input_menu_list.clear()

func _on_user_input_gui_input(event: InputEvent) -> void:
	var send_shortcut = AlphaAgentPlugin.global_setting.send_shortcut
	if send_shortcut == AlphaAgentPlugin.SendShotcut.None:
		return
	elif send_shortcut == AlphaAgentPlugin.SendShotcut.Enter:
		if event is InputEventKey:
			if event.keycode == KEY_ENTER and \
				not event.alt_pressed and \
				not event.shift_pressed and \
				not event.ctrl_pressed and \
				not event.meta_pressed and \
			event.pressed:
				on_click_send_message()
	elif send_shortcut == AlphaAgentPlugin.SendShotcut.CtrlEnter:
		if event is InputEventKey:
			if event.is_command_or_control_pressed() and \
				not event.alt_pressed and \
				not event.shift_pressed and \
				event.keycode == KEY_ENTER and \
				event.pressed:
				on_click_send_message()

func switch_button_to(button_name: String):
	if button_name == "Send":
		send_button.show()
		stop_button.hide()
	else:
		send_button.hide()
		stop_button.show()

func on_click_stop_button():
	stop_chat.emit()

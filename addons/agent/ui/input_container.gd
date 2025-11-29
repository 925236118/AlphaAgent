@tool
extends MarginContainer

@onready var user_input: TextEdit = %UserInput
@onready var send_button: Button = %SendButton
@onready var clear_button: Button = %ClearButton
@onready var usage_label: Label = %UsageLabel
@onready var reference_list: HFlowContainer = %ReferenceList
@onready var input_mode_select: OptionButton = %InputModeSelect

const REFERENCE_ITEM = preload("uid://bewckbivwp036")

signal send_message(message: Dictionary, message_content: String)

var disable: bool = false:
	set(value):
		disable = value
		user_input.editable = value
		send_button.disabled = not value

func _ready() -> void:
	update_user_input_placeholder()
	
	send_button.pressed.connect(on_click_send_message)
	clear_button.pressed.connect(on_click_clear_button)
	
	user_input.set_drag_forwarding(
		Callable(),
		func (at_position: Vector2, data: Variant):
			var allow_types = ['files', "files_and_dirs", 'nodes', 'script_list_element', 'shader_list_element']
			return allow_types.find(data.type) != -1,
			#return true,
		func (at_position: Vector2, data: Variant):
			print(data)
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
				"shader_list_element":
					print("暂时不支持拖拽shader，请从文件系统中拖入。")
					#var shader_editor =
					pass
	)

func get_input_mode():
	return input_mode_select.get_item_text(input_mode_select.get_selected_id())

func init():
	user_input.text = ""
	usage_label.text = ""
	clear_reference_list()
	input_mode_select.disabled = false

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
	self.disable = true
	input_mode_select.disabled = true
	var info_list = reference_list.get_children().map(func(node): return node.info)
	var info_list_string = JSON.stringify(info_list)
	send_message.emit({
		"role": "user",
		"content": "用户输入的内容：" + user_input.text + "\n引用的内容信息：" + info_list_string
	}, user_input.text)

func set_usage_label(total_tokens: float, max_content_length: float):
	usage_label.text = "%.2f" % (total_tokens / (max_content_length * 1024)) + "%"
	usage_label.tooltip_text = ("%.2f" % (total_tokens / (max_content_length * 1024))) + "%" + " | " + ("%d / 128k usage tokens" % total_tokens)

func update_user_input_placeholder():
	match get_input_mode():
		"Ask":
			user_input.placeholder_text = "输入问题，不能读取项目文件，但可以使用思考和更多上下文。"
		"Agent":
			user_input.placeholder_text = "输入问题，或拖拽添加引用。"

func _on_input_mode_select_item_selected(index: int) -> void:
	update_user_input_placeholder()

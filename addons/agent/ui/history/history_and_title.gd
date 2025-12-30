@tool
class_name AgentHistoryAndTitle
extends PanelContainer

@onready var chat_title: Label = %ChatTitle
@onready var expand_icon: TextureRect = %ExpandIcon
@onready var history_list_window: Window = $HistoryList
@onready var history_expand_button: Button = %HistoryExpandButton


@onready var project_alpha_dir = OS.get_user_data_dir() + "/.alpha/"
@onready var history_file_path = project_alpha_dir + "history.json"

@onready var today_history_container: VBoxContainer = %TodayHistoryContainer
@onready var yestoday_history_container: VBoxContainer = %YestodayHistoryContainer
@onready var toweek_history_container: VBoxContainer = %ToweekHistoryContainer
@onready var ago_history_container: VBoxContainer = %AgoHistoryContainer

const HISTORY_MESSAGE_ITEM = preload("uid://eq8fe48g3uch")
signal recovery(history_item: HistoryItem)

const popup_offset = Vector2i(0, 50)


class HistoryItem:
	var id: String = ""
	var use_thinking: bool = false
	var message: Array[Dictionary] = []
	var title: String = ""
	var time: String = ""
	var mode: String = ""
	func to_dict():
		return {
			"id": self.id,
			"use_thinking": self.use_thinking,
			"message": self.message,
			"title": self.title,
			"time": self.time,
			"mode": self.mode
		}
	static func from_dict(dict: Dictionary) -> HistoryItem:
		var item = HistoryItem.new()
		item.id = dict.get("id")
		item.use_thinking = dict.get("use_thinking")
		for m: Dictionary in dict.get("message"):
			item.message.push_back(m)
		item.title = dict.get("title")
		item.time = dict.get("time")
		item.mode = dict.get("mode")
		return item


func _ready() -> void:
	check_history_file()
	add_history_nodes()
	history_expand_button.pressed.connect(on_click_history_expand_button)
	history_list_window.close_requested.connect(on_close_history_list)
	# 监听窗口失去焦点事件
	history_list_window.focus_exited.connect(_on_window_focus_exited)

func refresh_list():
	clear_history_nodes()
	await get_tree().process_frame
	add_history_nodes()

func set_title(title: String):
	chat_title.text = title

func on_click_history_expand_button():
	var window_pos = get_tree().root.position
	var window_width = 296
	var window_height = min(162 + history_list.size() * 32 + 16, 500)
	
	var popup_pos = Vector2i(global_position) + popup_offset + window_pos
	# 判断是否在编辑器环境中
	var singleton = AlphaAgentSingleton.get_instance()
	# 如果是编辑器运行，限制位置在窗体大小内
	if singleton.editor_plugin == null:
		popup_pos = Vector2i(global_position) + popup_offset
	
	history_list_window.popup(Rect2i(popup_pos, Vector2i(window_width, window_height)))
	# 在编辑器模式下，需要手动设置窗口可获取焦点
	if singleton.editor_plugin == null:
		history_list_window.unfocusable = false
		history_list_window.grab_focus()
	expand_icon.flip_v = true

func on_close_history_list():
	history_list_window.hide()
	expand_icon.flip_v = false

# 处理窗口失去焦点事件
func _on_window_focus_exited() -> void:
	# 当窗口失去焦点时，关闭窗口
	if history_list_window.visible:
		on_close_history_list()

var history_list: Array = []

func check_history_file():
	var file_exists = FileAccess.file_exists(history_file_path)
	if file_exists:
		read_history_file()
	else:
		history_list = []
		if not DirAccess.dir_exists_absolute(project_alpha_dir):
			DirAccess.make_dir_absolute(project_alpha_dir)
	update_file_content()

func update_file_content():
	var file_content = history_list.map(func(item: HistoryItem): return item.to_dict())
	#print(file_content)
	var history_file = FileAccess.open(history_file_path, FileAccess.WRITE)
	if history_file != null:
		history_file.store_string(JSON.stringify(file_content))
		history_file.close()

func read_history_file():
	var history_file = FileAccess.open(history_file_path, FileAccess.READ)
	var file_content = JSON.parse_string(history_file.get_as_text())
	history_file.close()

	#print("file_content ", file_content)

	history_list = file_content.map(func(item_dict: Dictionary): return HistoryItem.from_dict(item_dict))

func add_history_item(histroy_item: HistoryItem):
	var history_message_item := HISTORY_MESSAGE_ITEM.instantiate()
	var time_dict = Time.get_datetime_dict_from_datetime_string(histroy_item.time, false)
	var now = Time.get_datetime_dict_from_system()
	var items_container: Control = null
	if now.year == time_dict.year and now.month == time_dict.month:
		if now.day == time_dict.day:
			items_container = today_history_container
		elif now.day - time_dict.day == 1:
			items_container = yestoday_history_container
		elif now.day - time_dict.day < 7:
			items_container = toweek_history_container
		else:
			items_container = ago_history_container
	else:
		items_container = ago_history_container

	items_container.add_child(history_message_item)
	items_container.show()
	history_message_item.set_title(histroy_item.title)
	history_message_item.set_time(histroy_item.time)
	history_message_item.recovery.connect(on_recovery_history_item.bind(histroy_item))
	history_message_item.delete.connect(on_delete_history_item.bind(histroy_item, history_message_item))

func update_history(id: String, item: HistoryItem):
	var index = history_list.find_custom(func(history_item: HistoryItem): return history_item.id == id)
	if index == -1:
		history_list.push_front(item)
	else:
		history_list[index] = item

	update_file_content()
	refresh_list()

func clear_history_nodes():
	for items_container in [
		today_history_container,
		yestoday_history_container,
		toweek_history_container,
		ago_history_container
	]:
		var item_count = items_container.get_child_count()
		for i in item_count:
			var history_item = items_container.get_child(item_count - i - 1)
			history_item.queue_free()
			for sig in history_item.get_signal_connection_list("recovery"):
				history_item.disconnect("recovery", sig.callable)
			for sig in history_item.get_signal_connection_list("delete"):
				history_item.disconnect("delete", sig.callable)

func add_history_nodes():
	if history_list.size() > 0:
		#no_message_container.hide()
		for histroy_item: HistoryItem in history_list:
			add_history_item(histroy_item)
	#else:
		#no_message_container.show()

func on_recovery_history_item(history_item: HistoryItem):
	recovery.emit(history_item)

func on_delete_history_item(history_item: HistoryItem, node: Control):
	var found_index = history_list.find_custom(func(item): return item.id == history_item.id)
	history_list.erase(history_list[found_index])
	for sig in node.get_signal_connection_list("recovery"):
		node.disconnect("recovery", sig.callable)
	for sig in node.get_signal_connection_list("delete"):
		node.disconnect("delete", sig.callable)
	node.hide()
	await get_tree().process_frame
	node.queue_free()

	update_file_content()
	refresh_list()

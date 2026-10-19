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
signal history_deleted(id: String)
var selected_id: String = ""
var _history_nodes: Dictionary = {}
var _inline: bool = false
var _can_write: bool = true

const popup_offset = Vector2i(0, 50)


class HistoryItem:
	var id: String = ""
	var use_thinking: bool = false
	var message: Array[Dictionary] = []
	var title: String = ""
	var time: String = ""
	var mode: String = ""
	var updated_at: float = 0.0
	func to_dict():
		return {
			"id": self.id,
			"use_thinking": self.use_thinking,
			"message": self.message,
			"title": self.title,
			"time": self.time,
			"mode": self.mode,
			"updated_at": self.updated_at
		}
	static func from_dict(dict: Dictionary) -> HistoryItem:
		if not dict.get("id") is String or dict["id"].is_empty() or not dict.get("message") is Array:
			return null
		var item = HistoryItem.new()
		item.id = dict["id"]
		item.use_thinking = bool(dict.get("use_thinking", false))
		for m in dict["message"]:
			if not m is Dictionary or not m.get("role") in ["system", "user", "assistant", "tool"]:
				return null
			if m.role in ["user", "assistant"] and not m.get("content") is String and not m.get("content") is Array and not m.get("tool_calls") is Array:
				return null
			if m.role == "tool" and (not m.get("tool_call_id") is String or not m.get("content") is String):
				return null
			if m.has("tool_calls"):
				if not m.tool_calls is Array:
					return null
				for call in m.tool_calls:
					if not call is Dictionary or not call.get("function") is Dictionary or not call.function.get("name") is String or not call.function.get("arguments") is String:
						return null
			item.message.push_back(m.duplicate(true))
		item.title = str(dict.get("title", "新对话"))
		item.time = str(dict.get("time", ""))
		if not valid_time(item.time):
			item.time = ""
		item.mode = str(dict.get("mode", ""))
		var updated = dict.get("updated_at", 0.0)
		item.updated_at = float(updated) if updated is int or updated is float else 0.0
		return item
	static func valid_time(value: String) -> bool:
		var pattern = RegEx.new()
		pattern.compile("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$")
		return pattern.search(value) != null


func _ready() -> void:
	check_history_file()
	add_history_nodes()
	history_expand_button.pressed.connect(on_click_history_expand_button)
	history_list_window.close_requested.connect(on_close_history_list)
	# 监听窗口失去焦点事件
	history_list_window.focus_exited.connect(_on_window_focus_exited)

func refresh_list():
	clear_history_nodes()
	add_history_nodes()
	set_selected_history(selected_id)

func set_inline_host(host: Control) -> void:
	_inline = true
	on_close_history_list()
	var list_panel = history_list_window.get_node("Panel")
	list_panel.reparent(host)
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expand_icon.hide()
	history_expand_button.hide()
	history_list_window.hide()

func set_selected_history(id: String) -> void:
	selected_id = id
	for key in _history_nodes:
		var node = _history_nodes[key]
		if is_instance_valid(node):
			node.set_selected(key == id)

func get_history_by_id(id: String) -> HistoryItem:
	for item: HistoryItem in history_list:
		if item.id == id:
			return item
	return null

func get_recent_history() -> HistoryItem:
	_sort_history()
	for item: HistoryItem in history_list:
		if item.message.any(func(message): return message.get("role") in ["user", "assistant"] or (message.get("content") is String and message.content.begins_with("## 对话上下文摘要"))):
			return item
	return null

static func history_timestamp(item: HistoryItem) -> float:
	if item.updated_at > 0:
		return item.updated_at
	if HistoryItem.valid_time(item.time):
		# 旧版保存的是无时区的本地时间，需与 UTC 的 updated_at 使用同一时间基准。
		return Time.get_unix_time_from_datetime_string(item.time) - int(Time.get_time_zone_from_system().bias) * 60
	return 0.0

func _sort_history() -> void:
	# 插入排序保持同一时间记录的原始顺序。
	for i in range(1, history_list.size()):
		var item = history_list[i]
		var j = i - 1
		while j >= 0 and history_timestamp(history_list[j]) < history_timestamp(item):
			history_list[j + 1] = history_list[j]
			j -= 1
		history_list[j + 1] = item

func set_title(title: String):
	# 替换换行符为空格，避免多行显示
	var clean_title = title.replace("\n", " ").replace("\r", " ")
	# 截断过长的标题
	if clean_title.length() > 20:
		clean_title = clean_title.substr(0, 20) + "..."
	chat_title.text = clean_title

func on_click_history_expand_button():
	if _inline:
		return
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
	if not _can_write:
		push_warning("历史文件格式异常，已保留原文件，本次不覆盖保存。")
		return
	var file_content = history_list.map(func(item: HistoryItem): return item.to_dict())
	#print(file_content)
	var history_file = FileAccess.open(history_file_path, FileAccess.WRITE)
	if history_file != null:
		history_file.store_string(JSON.stringify(file_content))
		history_file.close()

func read_history_file():
	var parser = JSON.new()
	history_list.clear()
	if parser.parse(FileAccess.get_file_as_string(history_file_path)) != OK or not parser.data is Array:
		_can_write = false
		return
	_can_write = true
	for data in parser.data:
		if data is Dictionary:
			var item = HistoryItem.from_dict(data)
			if item != null:
				history_list.append(item)
	_sort_history()

func add_history_item(histroy_item: HistoryItem):
	var history_message_item := HISTORY_MESSAGE_ITEM.instantiate()
	var now = Time.get_datetime_dict_from_system()
	var now_day = Time.get_unix_time_from_datetime_dict({"year": now.year, "month": now.month, "day": now.day}) / 86400
	var item_day = (int(history_timestamp(histroy_item)) + int(Time.get_time_zone_from_system().bias) * 60) / 86400
	var days_ago = now_day - item_day
	var items_container: Control = null
	if days_ago <= 0:
		items_container = today_history_container
	elif days_ago == 1:
		items_container = yestoday_history_container
	elif days_ago < 7:
		items_container = toweek_history_container
	else:
		items_container = ago_history_container

	items_container.add_child(history_message_item)
	_history_nodes[histroy_item.id] = history_message_item
	items_container.show()
	history_message_item.set_title(histroy_item.title)
	history_message_item.set_time(histroy_item.time)
	history_message_item.recovery.connect(on_recovery_history_item.bind(histroy_item))
	history_message_item.delete.connect(on_delete_history_item.bind(histroy_item, history_message_item))

func update_history(id: String, item: HistoryItem, content_changed: bool = true):
	if item == null or id.is_empty():
		return
	if content_changed:
		item.updated_at = Time.get_unix_time_from_system()
	var index = history_list.find_custom(func(history_item: HistoryItem): return history_item.id == id)
	if index == -1:
		history_list.push_front(item)
	else:
		history_list[index] = item

	_sort_history()
	selected_id = id
	update_file_content()
	refresh_list()

func clear_history_nodes():
	_history_nodes.clear()
	for items_container in [
		today_history_container,
		yestoday_history_container,
		toweek_history_container,
		ago_history_container
	]:
		var item_count = items_container.get_child_count()
		for i in item_count:
			var history_item = items_container.get_child(item_count - i - 1)
			items_container.remove_child(history_item)
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
	var list = today_history_container.get_parent()
	var empty = list.get_node_or_null("EmptyHistoryLabel")
	if empty == null:
		empty = Label.new()
		empty.name = "EmptyHistoryLabel"
		empty.text = "暂无对话"
		list.add_child(empty)
	empty.visible = history_list.is_empty()
	var groups = [today_history_container, yestoday_history_container, toweek_history_container, ago_history_container]
	var labels = ["Label", "Label2", "Label4", "Label3"]
	var has_previous = false
	for i in groups.size():
		var has_items = groups[i].get_child_count() > 0
		list.get_node(labels[i]).visible = has_items
		if i > 0:
			list.get_node("HSeparator" + (str(i) if i > 1 else "")).visible = has_items and has_previous
		has_previous = has_previous or has_items
	#else:
		#no_message_container.show()

func on_recovery_history_item(history_item: HistoryItem):
	recovery.emit(history_item)
	if not _inline:
		on_close_history_list()

func on_delete_history_item(history_item: HistoryItem, node: Control):
	var panel = AlphaAgentSingleton.get_instance().main_panel
	if is_instance_valid(panel) and (panel.is_busy_for_reload() or panel.reload_locked):
		return
	var found_index = history_list.find_custom(func(item): return item.id == history_item.id)
	if found_index < 0:
		return
	history_list.remove_at(found_index)
	if selected_id == history_item.id:
		selected_id = ""
	update_file_content()
	refresh_list()
	history_deleted.emit(history_item.id)

@tool
class_name AgentHistoryContainer
extends Control

@onready var items_container: VBoxContainer = %ItemsContainer
@onready var no_message_container: Control = %NoMessageContainer

signal recovery(history_item: HistoryItem)

const HISTORY_MESSAGE_ITEM = preload("uid://eq8fe48g3uch")

var history_file_dir = "res://.alpha/"
var history_file_path = "res://.alpha/history.json"

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

var history_list: Array = []

func _ready() -> void:
	check_history_file()
	visibility_changed.connect(on_visibility_changed)

func check_history_file():
	var file_exists = FileAccess.file_exists(history_file_path)
	if file_exists:
		read_history_file()
	else:
		history_list = []
		if not DirAccess.dir_exists_absolute(history_file_dir):
			DirAccess.make_dir_absolute(history_file_dir)
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
	items_container.add_child(history_message_item)
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

func clear_history_nodes():
	var item_count = items_container.get_child_count()
	for i in item_count:
		items_container.get_child(item_count - i - 1).queue_free()

func add_history_nodes():
	if history_list.size() > 0:
		no_message_container.hide()
		for histroy_item: HistoryItem in history_list:
			add_history_item(histroy_item)
	else:
		no_message_container.show()

func on_visibility_changed():
	if visible:
		add_history_nodes()
	else:
		clear_history_nodes()

func on_recovery_history_item(history_item: HistoryItem):
	recovery.emit(history_item)

func on_delete_history_item(history_item: HistoryItem, node: Control):
	var found_index = history_list.find_custom(func(item): return item.id == history_item.id)
	history_list.erase(history_list[found_index])
	node.queue_free()

	update_file_content()

@tool
class_name AgentHistoryContainer
extends Control
@onready var items_container: VBoxContainer = %ItemsContainer

const HISTORY_MESSAGE_ITEM = preload("uid://eq8fe48g3uch")

var history_file_dir = "res://.alpha/"
var history_file_path = "res://.alpha/history.tres"

class HistoryReource extends Resource:
	var messages: Array[HistoryItem]

class HistoryItem:
	var id: String = ""
	var use_thinking: bool = false
	var message: Array[Dictionary] = []
	var title: String = ""
	var time: String = ""

var history_resource: HistoryReource = null

func _ready() -> void:
	check_history_file()

func check_history_file():
	var file_exists = FileAccess.file_exists(history_file_path)
	if file_exists:
		read_history_file()
	else:
		history_resource = HistoryReource.new()
		#if not DirAccess.dir_exists_absolute(history_file_dir):
			#DirAccess.make_dir_absolute(history_file_dir)
		#ResourceSaver.save(history_resource, history_file_path)

func read_history_file():
	history_resource = ResourceLoader.load(history_file_path)
	
	for message in history_resource.messages:
		var history_message_item := HISTORY_MESSAGE_ITEM.instantiate()
		items_container.add_child(history_message_item)
		history_message_item.set_title(message.title)
		history_message_item.set_time(message.time)
		history_message_item.recovery.connect(on_recovery_history_item.bind(message))
		history_message_item.delete.connect(on_delete_history_item.bind(message))

func update_history(id: String, item: HistoryItem):
	if not history_resource:
		printerr("读取历史记录失败")
		return
	var index = history_resource.messages.find(func(history_item): return history_item.id == id)
	if index == -1:
		history_resource.messages.push_front(item)
	else:
		history_resource.messages[index] = item

	ResourceSaver.save(history_resource, history_file_path)
	
func on_recovery_history_item(history_item: HistoryItem):
	pass
func on_delete_history_item(history_item: HistoryItem):
	pass

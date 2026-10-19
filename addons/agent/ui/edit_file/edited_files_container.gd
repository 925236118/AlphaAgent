@tool
class_name AgentEditedFilesContainer
extends VBoxContainer

const EDITED_FILE_ITEM = preload("uid://c7acg0onq62p8")
const SHOW_EDITED_FILE_WINDOW = preload("uid://cga6fwmm6ifke")

@onready var file_list: VBoxContainer = %FileList
@onready var accept_all_button: Button = %AcceptAllButton
var _review_windows: Dictionary = {}

func _ready() -> void:
	accept_all_button.pressed.connect(on_accept_all)

func generate_edited_file_list(temp_file_array: Array[AgentTempFileManager.EditedFile]) -> void:
	for child in file_list.get_children():
		file_list.remove_child(child)
		child.queue_free()
	var enabled = AlphaAgentPlugin.global_setting.show_modified_files
	visible = enabled and not temp_file_array.is_empty()
	accept_all_button.disabled = not visible
	if not enabled:
		return
	for temp_file in temp_file_array:
		var item: AgentEditedFileItem = EDITED_FILE_ITEM.instantiate()
		file_list.add_child(item)
		item.set_file_name(temp_file.target_path)
		item.show_edit_file.connect(on_show_edit_file.bind(temp_file))
		item.accept.connect(on_accept_target.bind(temp_file))
		item.undo.connect(on_accept_origin.bind(temp_file))

func _refresh() -> void:
	generate_edited_file_list(AgentTempFileManager.get_instance().temp_file_array)

func on_show_edit_file(temp_file: AgentTempFileManager.EditedFile) -> void:
	if not AgentTempFileManager.get_instance().temp_file_array.has(temp_file):
		return
	var window = _review_windows.get(temp_file)
	if is_instance_valid(window):
		window.popup_centered()
		return
	window = SHOW_EDITED_FILE_WINDOW.instantiate()
	_review_windows[temp_file] = window
	window.close_requested.connect(window.queue_free)
	window.title = "Diff: " + temp_file.target_path
	window.accept_origin.connect(on_accept_origin.bind(temp_file))
	window.accept_target.connect(on_accept_target.bind(temp_file))
	AlphaAgentSingleton.get_instance().main_panel.add_child(window)
	window.origin_file_path = temp_file.origin_path if temp_file.origin_exist else ""
	window.target_file_path = temp_file.target_path
	window.load_file()
	if temp_file.origin_exist:
		window.compare_and_highlight()
	window.popup_centered()

func _close_review_window(temp_file: AgentTempFileManager.EditedFile) -> void:
	var window = _review_windows.get(temp_file)
	if is_instance_valid(window):
		window.queue_free()
	_review_windows.erase(temp_file)

func on_accept_origin(temp_file: AgentTempFileManager.EditedFile) -> void:
	var manager = AgentTempFileManager.get_instance()
	if not manager.temp_file_array.has(temp_file):
		return
	if temp_file.origin_exist:
		var origin = FileAccess.open(temp_file.origin_path, FileAccess.READ)
		if origin == null:
			push_error("无法读取文件原始快照：" + temp_file.origin_path)
			return
		var target = FileAccess.open(temp_file.target_path, FileAccess.WRITE)
		if target == null:
			push_error("无法恢复文件：" + temp_file.target_path)
			return
		target.store_buffer(origin.get_buffer(origin.get_length()))
		target.close()
		origin.close()
	elif FileAccess.file_exists(temp_file.target_path):
		var error = DirAccess.remove_absolute(temp_file.target_path)
		if error != OK:
			push_error("无法撤销新建文件：" + temp_file.target_path)
			return
	EditorInterface.get_resource_filesystem().update_file(temp_file.target_path)
	EditorInterface.get_script_editor().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	if manager.remove_temp_file(temp_file):
		_close_review_window(temp_file)
	_refresh()

func on_accept_target(temp_file: AgentTempFileManager.EditedFile) -> void:
	if AgentTempFileManager.get_instance().remove_temp_file(temp_file):
		_close_review_window(temp_file)
	_refresh()

func on_accept_all() -> void:
	if not AlphaAgentPlugin.global_setting.show_modified_files:
		return
	var manager = AgentTempFileManager.get_instance()
	# 遍历副本，删除记录时不会跳项；保留目标文件当前内容。
	for temp_file in manager.temp_file_array.duplicate():
		if manager.remove_temp_file(temp_file):
			_close_review_window(temp_file)
	_refresh()

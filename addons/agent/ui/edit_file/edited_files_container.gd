@tool
class_name AgentEditedFilesContainer
extends VBoxContainer

const EDITED_FILE_ITEM = preload("uid://c7acg0onq62p8")
const SHOW_EDITED_FILE_WINDOW = preload("uid://cga6fwmm6ifke")

 #func _ready() -> void:
 	#var file = AgentTools.EditedFile.new()
 	#file.origin_exist = true
 	#file.target_path = "res://scripts/player.gd"
 	#file.origin_path = "res://scripts/player1.gd"
 	#generate_edited_file_list([file])

func generate_edited_file_list(temp_file_array: Array[AgentTools.EditedFile]):
	#print("修改过的文件列表：", temp_file_array)
	for child in get_children():
		child.queue_free()
	for temp_file in temp_file_array:
		var edit_file_item := EDITED_FILE_ITEM.instantiate()
		edit_file_item.set_name(temp_file.origin_path)
		add_child(edit_file_item)
		edit_file_item.show_edit_file.connect(on_show_edit_file.bind(temp_file, edit_file_item))
		show()

func on_show_edit_file(temp_file: AgentTools.EditedFile, edit_file_node: AgentEditedFileItem):
	#print("显示编辑过的文件：", temp_file.target_path)
	#print("编辑过的文件临时文件路径：", temp_file.origin_path)
	#print("编辑过的文件是否存在：", temp_file.origin_exist)
	var show_window: AgentShowEditedFileWindow = SHOW_EDITED_FILE_WINDOW.instantiate()
	show_window.close_requested.connect(show_window.queue_free)
	show_window.title = "Diff: " + temp_file.origin_path
	show_window.accept_origin.connect(on_accept_origin.bind(temp_file, edit_file_node))
	show_window.accept_target.connect(on_accept_target.bind(temp_file, edit_file_node))
	AlphaAgentSingleton.instance.main_panel.add_child(show_window)
	show_window.origin_file_path = temp_file.origin_path
	show_window.target_file_path = temp_file.target_path
	show_window.load_file()
	show_window.compare_and_highlight()
	show_window.popup_centered()

# 保留源文件则需要将源文件内容复制后更新到新文件中
func on_accept_origin(temp_file: AgentTools.EditedFile, edit_file_node: AgentEditedFileItem):
	if temp_file.origin_exist:
		var origin_file = FileAccess.open(temp_file.origin_path, FileAccess.READ)
		var target_file = FileAccess.open(temp_file.target_path, FileAccess.WRITE)

		var file_buffer = origin_file.get_buffer(origin_file.get_length())
		target_file.store_buffer(file_buffer)
	else:
		var dir = DirAccess.open(temp_file.target_path.get_base_dir())
		dir.remove(temp_file.target_path.get_file())

	EditorInterface.get_resource_filesystem().update_file(temp_file.target_path)
	EditorInterface.get_script_editor().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

	var index = edit_file_node.get_index()
	AlphaAgentSingleton.instance.main_panel.tools.delete_temp_file(index)
	edit_file_node.queue_free()

# 保留目标文件则需要将源文件删除
func on_accept_target(temp_file: AgentTools.EditedFile, edit_file_node: AgentEditedFileItem):
	if temp_file.origin_exist:
		DirAccess.remove_absolute(temp_file.origin_path)

	var index = edit_file_node.get_index()
	AlphaAgentSingleton.instance.main_panel.tools.delete_temp_file(index)
	edit_file_node.queue_free()

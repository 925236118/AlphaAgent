@tool
class_name AgentEditedFilesContainer
extends VBoxContainer

const EDITED_FILE_ITEM = preload("uid://c7acg0onq62p8")

func generate_edited_file_list(temp_file_array: Array[AgentTools.EditedFile]):
	print("修改过的文件列表：", temp_file_array)
	for child in get_children():
		child.queue_free()
	for temp_file in temp_file_array:
		var edit_file_item := EDITED_FILE_ITEM.instantiate()
		edit_file_item.set_name(temp_file.origin_path)
		add_child(edit_file_item)
		edit_file_item.show_edit_file.connect(on_show_edit_file.bind(temp_file))
		show()

func on_show_edit_file(temp_file: AgentTools.EditedFile):
	print("显示编辑过的文件：", temp_file.origin_path)
	print("编辑过的文件临时文件路径：", temp_file.temp_file_path)
	print("编辑过的文件是否存在：", temp_file.origin_exist)
	pass

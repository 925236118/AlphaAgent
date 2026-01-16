@tool
class_name AgentTempFileManager
extends RefCounted

## 管理临时文件（用于“可回滚编辑文件列表”功能）
## 说明：当前阶段尚未接入 tools.gd；这里先提供可复用实现，未来接入时可共享同一份状态。

static var _instance: AgentTempFileManager = null

class EditedFile:
	var target_path := ""
	var origin_exist := false
	var origin_path := ""

var temp_file_array: Array[EditedFile] = []

static func get_instance() -> AgentTempFileManager:
	if _instance == null:
		_instance = AgentTempFileManager.new()
	return _instance

func create_temp_file(target_path: String) -> void:
	if temp_file_array.any(func(item): return item.target_path == target_path):
		return

	var result = EditedFile.new()
	result.target_path = target_path
	result.origin_exist = false

	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/.alpha/" + "temp/")

	var origin_path = OS.get_user_data_dir() + "/.alpha/" + "temp/" + target_path.get_file().get_basename() + "." + AlphaUtils.generate_random_string(16) + ".temp"
	result.origin_path = origin_path

	if FileAccess.file_exists(target_path):
		var origin_file = FileAccess.open(target_path, FileAccess.READ)
		var origin_content = origin_file.get_buffer(origin_file.get_length())
		var temp_file = FileAccess.open(origin_path, FileAccess.WRITE)
		temp_file.store_buffer(origin_content)
		temp_file.close()
		origin_file.close()
		result.origin_exist = true

	temp_file_array.append(result)

func delete_temp_file(index: int) -> void:
	var temp_file = temp_file_array[index]
	DirAccess.remove_absolute(temp_file.origin_path)
	temp_file_array.remove_at(index)

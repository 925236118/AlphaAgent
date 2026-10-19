@tool
class_name AgentTempFileManager
extends RefCounted

## 管理临时文件（用于“可回滚编辑文件列表”功能）
## 文件写入工具记录原始快照；显示设置只控制列表展示，不影响记录。

static var _instance: AgentTempFileManager = null

class EditedFile:
	# 有变化的文件目录
	var target_path := ""
	# 是否有源文件，如果为false，则是新创建的文件
	var origin_exist := false
	# 临时文件目录
	var origin_path := ""

var temp_file_array: Array[EditedFile] = []

static func get_instance() -> AgentTempFileManager:
	if _instance == null:
		_instance = AgentTempFileManager.new()
	return _instance

func init() -> void:
	temp_file_array.clear()

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
	if index >= 0 and index < temp_file_array.size():
		remove_temp_file(temp_file_array[index])

## 按记录本身删除，避免 UI 标题或批量操作改变索引后处理了错误文件。
func remove_temp_file(temp_file: EditedFile) -> bool:
	var index = temp_file_array.find(temp_file)
	if index < 0:
		return false
	if not temp_file.origin_path.is_empty() and FileAccess.file_exists(temp_file.origin_path):
		var error = DirAccess.remove_absolute(temp_file.origin_path)
		if error != OK:
			push_error("清理文件修改快照失败：%s（%s）" % [temp_file.origin_path, error_string(error)])
			return false
	temp_file_array.remove_at(index)
	return true

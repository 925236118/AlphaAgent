@tool
class_name AgentShowEditedFileWindow
extends Window

@onready var origin_code_edit: CodeEdit = %OriginCodeEdit
@onready var target_code_edit: CodeEdit = %TargetCodeEdit

@onready var sync_scroll: CheckButton = %SyncScroll

var origin_file_path: String = ""
var target_file_path: String = ""

const DELETE_LINE_COLOR = Color(0.566, 0.0, 0.0, 1.0)
const ADD_LINE_COLOR = Color(0.187, 0.337, 0.137, 1.0)

var diff_res: AgentDiffTool.DiffResult = null

func _process(delta: float) -> void:
	if sync_scroll.button_pressed:
		sync_code_edit_scroll_vertical()

func load_file():
	if target_file_path == "":
		printerr("请传入正确的target_file_path文件地址")
		return
	if not origin_file_path == "":
		origin_code_edit.text = FileAccess.get_file_as_string(origin_file_path)
	target_code_edit.text = FileAccess.get_file_as_string(target_file_path)

func compare_and_highlight():
	if origin_file_path == "" or target_file_path == "":
		printerr("请传入正确的文件地址")
		return
	diff_res = AgentDiffTool.compare_files(origin_file_path, target_file_path)
	#print(AgentDiffTool.generate_diff_report(diff_res))
	#print(diff_res.to_str())
	for deleted_line: Array in diff_res.deleted_lines:
		origin_code_edit.set_line_background_color(deleted_line[1] - 1, DELETE_LINE_COLOR)
	for added_line: Array in diff_res.added_lines:
		target_code_edit.set_line_background_color(added_line[1] - 1, ADD_LINE_COLOR)

var last_origin_code_edit_scroll_vertical = 0
var last_target_code_edit_scroll_vertical = 0

func sync_code_edit_scroll_vertical():
	# 如果源文件发生滚动，则更新目标文件的滚动
	if not last_origin_code_edit_scroll_vertical == origin_code_edit.scroll_vertical:
		# 当前滚动到的行号
		var line_num: int = floor(origin_code_edit.scroll_vertical)
		# 保留小数部分
		var line_num_float : float = origin_code_edit.scroll_vertical - line_num
		var founded = false
		#print("源文件发生滚动，新的行号：", line_num)
		# 首先查找是否未修改
		for unchanged_line: Array in diff_res.unchanged_lines:
			var old_line = unchanged_line[1] - 1
			if old_line == line_num:
				target_code_edit.scroll_vertical = unchanged_line[2] - 1 + line_num_float
				founded = true
				#print("未修改，但行号发生变化: ", unchanged_line[2] - 1)
				break
		# 查找是否是删除的行
		if not founded:
			if diff_res.deleted_lines.any(func (deleted_line: Array): return (deleted_line[1] - 1) == line_num):
				#print("删除的行")
				pass
			else:
				# 不是删除的行，说明是最开始的未修改的部分，只需要同步行数即可
				target_code_edit.scroll_vertical = origin_code_edit.scroll_vertical
				#print("未修改，行号一致: ", origin_code_edit.scroll_vertical)


	# 如果目标文件发生滚动，则更新源文件的滚动
	elif not last_target_code_edit_scroll_vertical == target_code_edit.scroll_vertical:
		# 当前滚动到的行号
		var line_num: int = floor(target_code_edit.scroll_vertical)
		# 保留小数部分
		var line_num_float : float = target_code_edit.scroll_vertical - line_num
		var founded = false
		#print("目标文件发生滚动，新的行号：", line_num)
		# 首先查找是否未修改
		for unchanged_line: Array in diff_res.unchanged_lines:
			var old_line = unchanged_line[2] - 1
			if old_line == line_num:
				origin_code_edit.scroll_vertical = unchanged_line[1] - 1 + line_num_float
				founded = true
				#print("未修改，但行号发生变化: ", unchanged_line[1] - 1)
				break
		# 查找是否是删除的行
		if not founded:
			if diff_res.added_lines.any(func (added_line: Array): return (added_line[1] - 1) == line_num):
				#print("新增的行")
				pass
			else:
				# 不是删除的行，说明是最开始的未修改的部分，只需要同步行数即可
				origin_code_edit.scroll_vertical = target_code_edit.scroll_vertical
				#print("未修改，行号一致: ", target_code_edit.scroll_vertical)

	last_origin_code_edit_scroll_vertical = origin_code_edit.scroll_vertical
	last_target_code_edit_scroll_vertical = target_code_edit.scroll_vertical

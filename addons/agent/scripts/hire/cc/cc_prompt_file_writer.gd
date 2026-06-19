@tool
class_name CCPromptFileWriter
extends RefCounted

## CC 提示词文件写入器
## 将提示词写入临时文件，并通过管道发送给 CC（解决 Windows 下中文编码问题）
##
## 工作流程:
##   1. 将提示词写入 Godot user:// 临时文件（FileAccess 自动处理 UTF-8）
##   2. 全局化路径转为绝对路径
##   3. 构造平台管道命令: type/cat <临时文件> | claude <args>

const TEMP_PROMPT_FILE: String = "user://.alpha/cc_temp_prompt.txt"

## 写入提示词到临时文件并发送给 CC
## prompt: 提示词内容
## session_id: 当前 session ID（可选，用于同 session 继续对话）
## is_new: 是否新 session（不传 --session-id）
static func write_and_send(prompt: String, session_id: String, is_new: bool, process_manager: CCProcessManager) -> void:
	# Step 1: 确保临时目录存在
	var dir_path = "user://.alpha/"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(dir_path))

	# Step 2: 将提示词写入临时文件（FileAccess 自动处理 UTF-8 编码）
	var file = FileAccess.open(TEMP_PROMPT_FILE, FileAccess.WRITE)
	if not file:
		printerr("CCPromptFileWriter: 无法写入临时提示词文件: ", TEMP_PROMPT_FILE)
		return
	file.store_string(prompt)
	file.close()

	# Step 3: 将 res:// 路径转为绝对路径
	var abs_path = ProjectSettings.globalize_path(TEMP_PROMPT_FILE)

	# Step 4: 根据平台构造管道命令
	var cc_args = "--output-format stream-json --verbose"
	if not is_new and not session_id.is_empty():
		cc_args += ' --session-id "%s"' % session_id

	var command: String
	match OS.get_name():
		"Windows":
			# cmd.exe: type 读取文件 → 管道 → claude
			command = 'type "%s" | claude %s\n' % [abs_path, cc_args]
		"Linux", "macOS":
			# /bin/sh: cat 读取文件 → 管道 → claude
			command = 'cat "%s" | claude %s\n' % [abs_path, cc_args]
		_:
			command = 'cat "%s" | claude %s\n' % [abs_path, cc_args]

	# Step 5: 写入 shell stdin
	process_manager.write_to_stdin(command)

## 清理临时文件
static func cleanup() -> void:
	if FileAccess.file_exists(TEMP_PROMPT_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PROMPT_FILE))

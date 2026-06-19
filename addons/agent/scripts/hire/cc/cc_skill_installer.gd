@tool
class_name CCSkillInstaller
extends RefCounted

## CC Skills 安装/卸载/检测管理器
## 管理项目 .claude/skills/ 目录下的预置 Godot skills
##
## Skills 模板存放在 addons/agent/cc_config/skills/
## 安装时复制到 res://.claude/skills/

# 模板存放位置（Alpha 插件自带）
const SKILL_TEMPLATES_DIR: String = "res://addons/agent/cc_config/skills/"
# 目标安装位置（项目根目录）
const TARGET_DIR: String = "res://.claude/skills/"

# 预置 Skills 清单
var skill_list: Array[Dictionary] = [
	{
		"name": "gdscript-style",
		"description": "GDScript 代码风格指南"
	},
	{
		"name": "godot-scene-structure",
		"description": "Godot 场景结构规范"
	},
	{
		"name": "godot-animation",
		"description": "Godot 动画系统操作指南"
	}
]

## 检查所有预置 Skills 的安装状态
## 返回 {skill_name: true/false}
func check_install_status() -> Dictionary:
	var status: Dictionary = {}
	for skill in skill_list:
		var skill_name = skill["name"]
		var skill_file = TARGET_DIR + skill_name + "/SKILL.md"
		status[skill_name] = FileAccess.file_exists(skill_file)
	return status

## 检查单个 Skill 是否已安装
func is_installed(skill_name: String) -> bool:
	var skill_file = TARGET_DIR + skill_name + "/SKILL.md"
	return FileAccess.file_exists(skill_file)

## 安装单个 Skill
## 将模板从 addons 复制到项目 .claude/skills/ 目录
func install_skill(skill_name: String) -> bool:
	var src_dir = SKILL_TEMPLATES_DIR + skill_name + "/"
	var dst_dir = TARGET_DIR + skill_name + "/"
	var src_abs = ProjectSettings.globalize_path(src_dir)
	var dst_abs = ProjectSettings.globalize_path(dst_dir)

	# 检查源目录是否存在
	if not DirAccess.dir_exists_absolute(src_abs):
		push_error("CCSkillInstaller: 模板目录不存在: %s" % src_abs)
		return false

	# 创建目标目录
	var err = DirAccess.make_dir_recursive_absolute(dst_abs)
	if err != OK:
		push_error("CCSkillInstaller: 无法创建目标目录: %s" % dst_abs)
		return false

	# 复制目录下所有文件
	var src_dir_obj = DirAccess.open(src_dir)
	if not src_dir_obj:
		push_error("CCSkillInstaller: 无法打开源目录: %s" % src_dir)
		return false

	src_dir_obj.list_dir_begin()
	var file_name = src_dir_obj.get_next()
	while file_name != "":
		if not src_dir_obj.current_is_dir():
			var src_file = ProjectSettings.globalize_path(src_dir + file_name)
			var dst_file = ProjectSettings.globalize_path(dst_dir + file_name)
			var copy_err = DirAccess.copy_absolute(src_file, dst_file)
			if copy_err != OK:
				push_warning("CCSkillInstaller: 复制文件失败: %s → %s" % [src_file, dst_file])
		file_name = src_dir_obj.get_next()
	src_dir_obj.list_dir_end()

	print("CCSkillInstaller: %s 安装成功" % skill_name)
	return true

## 卸载单个 Skill（删除目标目录）
func uninstall_skill(skill_name: String) -> bool:
	var dst_dir = TARGET_DIR + skill_name + "/"
	var dst_abs = ProjectSettings.globalize_path(dst_dir)

	# 目录不存在，视为已卸载
	if not DirAccess.dir_exists_absolute(dst_abs):
		return true

	# 先删除目录内的所有文件
	var dir_obj = DirAccess.open(dst_dir)
	if dir_obj:
		dir_obj.list_dir_begin()
		var file_name = dir_obj.get_next()
		while file_name != "":
			if not dir_obj.current_is_dir():
				var file_abs = dst_abs + file_name
				DirAccess.remove_absolute(file_abs)
			file_name = dir_obj.get_next()
		dir_obj.list_dir_end()

	# 删除目录
	var err = DirAccess.remove_absolute(dst_abs)
	if err != OK:
		push_warning("CCSkillInstaller: 删除目录失败: %s" % dst_abs)
		return false

	return true

## 安装所有预置 Skills
func install_all() -> Dictionary:
	var results: Dictionary = {}
	for skill in skill_list:
		var name = skill["name"]
		results[name] = install_skill(name)
	return results

## 卸载所有预置 Skills
func uninstall_all() -> Dictionary:
	var results: Dictionary = {}
	for skill in skill_list:
		var name = skill["name"]
		results[name] = uninstall_skill(name)
	return results

## 自动安装（仅在首次使用时调用）
## 如果 cc_auto_install_skills = true 且 Skills 未安装，则自动安装
func auto_install_if_needed() -> void:
	if not AlphaAgentPlugin.global_setting.cc_auto_install_skills:
		return

	var status = check_install_status()
	var need_install = false
	for name in status:
		if not status[name]:
			need_install = true
			break

	if need_install:
		print("CCSkillInstaller: 自动安装 CC Skills...")
		install_all()

## 获取预置 Skills 清单
func get_skill_list() -> Array[Dictionary]:
	return skill_list

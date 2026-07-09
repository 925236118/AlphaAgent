@tool
class_name AgentSkillConfig
extends Node

const DEFAULT_SKILLS_DIR = "res://addons/agent/skills/default_skills/"


class SkillManager:
	var skill_directory: String = ""
	var skills: Array[AgentSkillResource] = []
	var skill_map: Dictionary = {}
	var skill_folder_path_map: Dictionary = {}

	func _init(p_skill_directory: String):
		skill_directory = p_skill_directory
		_ensure_skill_dir()
		load_skills()

	func _ensure_skill_dir():
		var dir_path = skill_directory
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
			create_default_skills()

	func create_default_skills():
		var default_dir = DirAccess.open(DEFAULT_SKILLS_DIR)
		if default_dir:
			for dir_name in default_dir.get_directories():
				_copy_skill_folder(DEFAULT_SKILLS_DIR + dir_name + "/", skill_directory + dir_name + "/")

	func _copy_skill_folder(from: String, to: String) -> void:
		DirAccess.make_dir_recursive_absolute(to)
		var source_dir = DirAccess.open(from)
		if source_dir:
			# 复制所有文件
			for file_name in source_dir.get_files():
				DirAccess.copy_absolute(from + file_name, to + file_name)
			# 递归复制子目录
			for dir_name in source_dir.get_directories():
				_copy_skill_folder(from + dir_name + "/", to + dir_name + "/")

	func load_skills():
		skills.clear()
		skill_map.clear()
		skill_folder_path_map.clear()

		var dir = DirAccess.open(skill_directory)
		if dir == null:
			return

		for dir_name in dir.get_directories():
			var folder_path = skill_directory + dir_name + "/"
			var skill = AgentSkillResource.load_from_folder(folder_path)
			if skill.skill_name.is_empty():
				AlphaAgentPlugin.print_alpha_message("跳过无效技能文件夹: {0}".format([folder_path]))
				continue
			skills.append(skill)
			skill_map[skill.skill_name] = skill
			skill_folder_path_map[skill.skill_name] = folder_path

		AlphaAgentPlugin.print_alpha_message("{0}个技能加载完成".format([skills.size()]))

	func get_skill(skill_name: String) -> AgentSkillResource:
		return skill_map.get(skill_name, null)

	func get_skill_names() -> Array:
		return skill_map.keys()

	func get_skill_folder_path(skill_name: String) -> String:
		return skill_folder_path_map.get(skill_name, "")

	func get_skills_xml_summary() -> String:
		if skills.is_empty():
			return ""
		var lines: Array[String] = ["<available_skills>"]
		for skill in skills:
			lines.append('\t<skill name="%s">%s</skill>' % [
				skill.skill_name,
				skill.skill_description.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
			])
		lines.append("</available_skills>")
		lines.append("使用 load_skill 工具按需加载完整 Skill 内容。")
		return "\n".join(lines)

	func add_skill(skill: AgentSkillResource):
		var folder_path = skill_directory + skill.skill_name + "/"
		DirAccess.make_dir_recursive_absolute(folder_path)
		skill.skill_folder_path = folder_path
		skill.save_to_folder()

		skill_map[skill.skill_name] = skill
		skill_folder_path_map[skill.skill_name] = folder_path
		skills.append(skill)

	func update_skill(skill: AgentSkillResource):
		if not skill.skill_folder_path.is_empty():
			skill.save_to_folder()
		skill_map[skill.skill_name] = skill

	func delete_skill(skill: AgentSkillResource):
		var folder_path = skill_folder_path_map.get(skill.skill_name, "")
		if not folder_path.is_empty():
			_delete_folder_recursive(folder_path)

		skills.erase(skill)
		skill_map.erase(skill.skill_name)
		skill_folder_path_map.erase(skill.skill_name)

	func _delete_folder_recursive(path: String) -> void:
		var dir = DirAccess.open(path)
		if dir:
			for item in dir.get_files():
				DirAccess.remove_absolute(path + "/" + item)
			for item in dir.get_directories():
				_delete_folder_recursive(path + "/" + item)
			# 删除自身文件夹
			DirAccess.remove_absolute(path)

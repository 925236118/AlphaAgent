@tool
class_name AgentSkillConfig
extends Node

const DEFAULT_SKILLS_DIR = "res://addons/agent/skills/default_skills/"


class SkillManager:
	var skill_directory: String = ""
	var skills: Array[AgentSkillResource] = []
	var skill_map: Dictionary = {}
	var skill_file_path_map: Dictionary = {}

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
		var default_skills_dir = DirAccess.open(DEFAULT_SKILLS_DIR)
		if default_skills_dir:
			for file_name in default_skills_dir.get_files():
				DirAccess.copy_absolute(DEFAULT_SKILLS_DIR + file_name, skill_directory + file_name)

	func load_skills():
		var files = DirAccess.get_files_at(skill_directory)
		for file_name in files:
			var skill = load(skill_directory + file_name) as AgentSkillResource
			skills.append(skill)
			skill_map[skill.skill_name] = skill
			skill_file_path_map[skill_directory + file_name] = skill

		AlphaAgentPlugin.print_alpha_message("{0}个技能加载完成".format([skills.size()]))

	func get_skill(skill_name: String) -> AgentSkillResource:
		return skill_map.get(skill_name, null)

	func get_skill_names() -> Array:
		return skill_map.keys()

	func get_skill_file_path(skill: AgentSkillResource) -> String:
		for file_path in skill_file_path_map.keys():
			if skill_file_path_map[file_path] == skill:
				return file_path
		return ""

	func add_skill(skill: AgentSkillResource):
		var path = skill_directory + skill.skill_name + ".tres"
		ResourceSaver.save(skill, path)
		skill_file_path_map[path] = skill
		skills.append(skill)
		skill_map[skill.skill_name] = skill
		skill_file_path_map[path] = skill

	func update_skill(skill: AgentSkillResource):
		var old_skill = get_skill(skill.skill_name)
		old_skill.skill_description = skill.skill_description
		old_skill.skill_content = skill.skill_content

		skill_map[skill.skill_name] = skill
		ResourceSaver.save(skill, get_skill_file_path(old_skill))

	func delete_skill(skill: AgentSkillResource):
		skills.erase(skill)
		skill_map.erase(skill.skill_name)
		DirAccess.remove_absolute(get_skill_file_path(skill))
		skill_file_path_map.erase(get_skill_file_path(skill))

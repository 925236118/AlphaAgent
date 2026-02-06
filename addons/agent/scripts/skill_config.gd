@tool
class_name AgentSkillConfig
extends Node

const DEFAULT_SKILLS_DIR = "res://addons/agent/skills/default_skills/"


class SkillManager:
	var skill_directory: String = ""
	var skills: Array[AgentSkillResource] = []
	var skill_map: Dictionary = {}

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
		AlphaAgentPlugin.print_alpha_message("{0}个技能加载完成".format([skills.size()]))

	func get_skill(skill_name: String) -> AgentSkillResource:
		return skill_map.get(skill_name, null)

	func get_skill_names() -> Array:
		return skill_map.keys()

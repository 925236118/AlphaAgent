@tool
class_name AgentPromptTemplateConfig
extends RefCounted

const DEFAULT_TEMPLATES_DIR := "res://addons/agent/prompts/"

class PromptTemplate:
	var name: String = ""
	var description: String = ""
	var content: String = ""

	func _init(p_name: String = "", p_description: String = "", p_content: String = "") -> void:
		name = p_name
		description = p_description
		content = p_content

class PromptTemplateManager:
	var template_directory: String = ""
	var user_template_directory: String = ""
	var templates: Array[PromptTemplate] = []
	var template_map: Dictionary = {}

	func _init(p_user_template_directory: String) -> void:
		user_template_directory = p_user_template_directory
		_ensure_template_dir()
		load_templates()

	func _ensure_template_dir() -> void:
		if not DirAccess.dir_exists_absolute(user_template_directory):
			DirAccess.make_dir_recursive_absolute(user_template_directory)
		_copy_builtin_templates()

	func _copy_builtin_templates() -> void:
		if not DirAccess.dir_exists_absolute(DEFAULT_TEMPLATES_DIR):
			return
		var source_dir := DirAccess.open(DEFAULT_TEMPLATES_DIR)
		if source_dir == null:
			return
		for file_name in source_dir.get_files():
			if not file_name.ends_with(".md"):
				continue
			var target_path := user_template_directory + file_name
			if not FileAccess.file_exists(target_path):
				DirAccess.copy_absolute(DEFAULT_TEMPLATES_DIR + file_name, target_path)

	func load_templates() -> void:
		templates.clear()
		template_map.clear()
		_load_templates_from_dir(DEFAULT_TEMPLATES_DIR)
		_load_templates_from_dir(user_template_directory)

	func _load_templates_from_dir(dir_path: String) -> void:
		if not DirAccess.dir_exists_absolute(dir_path):
			return
		var dir := DirAccess.open(dir_path)
		if dir == null:
			return
		for file_name in dir.get_files():
			if not file_name.ends_with(".md"):
				continue
			var template := _parse_template_file(dir_path + file_name, file_name.get_basename())
			if template.name.is_empty():
				continue
			template_map[template.name] = template

		templates = []
		for key in template_map.keys():
			templates.append(template_map[key])

	func _parse_template_file(file_path: String, fallback_name: String) -> PromptTemplate:
		var content := FileAccess.get_file_as_string(file_path)
		if content.is_empty():
			return PromptTemplate.new()

		var name := fallback_name
		var description := ""
		var body := content

		if content.begins_with("---"):
			var end_idx := content.find("---", 3)
			if end_idx > 0:
				var front_matter := content.substr(3, end_idx - 3)
				body = content.substr(end_idx + 3).strip_edges()
				for line in front_matter.split("\n"):
					var parts := line.split(":", true, 1)
					if parts.size() < 2:
						continue
					var key := parts[0].strip_edges()
					var value := parts[1].strip_edges()
					if key == "name":
						name = value
					elif key == "description":
						description = value

		return PromptTemplate.new(name, description, body)

	func get_template(name: String) -> PromptTemplate:
		return template_map.get(name, null)

	func get_template_names() -> Array:
		return template_map.keys()

	func get_command_list() -> Array:
		var result: Array = []
		for template in templates:
			result.append({
				"command": "/" + template.name,
				"description": template.description if not template.description.is_empty() else "提示词模板"
			})
		return result

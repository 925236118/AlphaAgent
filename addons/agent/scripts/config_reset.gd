@tool
extends RefCounted

## 只收集当前配置版本的明确目标；先检查整棵技能目录，再执行删除。
static func loaded_version(settings) -> String:
	# 热重载可能保留没有新字段的旧对象，删除范围以已经加载的配置路径为准。
	var path = settings.get("setting_file")
	if not path is String:
		return ""
	var name: String = path.get_file()
	if not name.begins_with("setting.") or not name.ends_with(".json"):
		return ""
	var version := name.trim_prefix("setting.").trim_suffix(".json")
	return version if _valid_version(version) else ""

static func _valid_version(version) -> bool:
	return version is String and not version.is_empty() and version.validate_filename() == version and version not in [".", ".."]

static func collect_files(settings, version = null) -> Dictionary:
	if not _valid_version(version):
		return {"error": "配置版本无效，已取消初始化。"}
	var setting_dir = settings.get("setting_dir")
	if not setting_dir is String or setting_dir.is_empty():
		return {"error": "配置目录未就绪，已取消初始化。"}
	var root: String = ProjectSettings.globalize_path(setting_dir).simplify_path().trim_suffix("/")
	# 所有路径必须属于同一已加载版本，拒绝混合版本或不完整的设置对象。
	for key in ["setting", "models", "roles", "memory", "skill"]:
		var property: String = key + "_file" if key != "skill" else "skill_directory"
		var path = settings.get(property)
		var expected: String = "skills_" + version if key == "skill" else "%s.%s.json" % [key, version]
		if not path is String or ProjectSettings.globalize_path(path).simplify_path().trim_suffix("/") != root.path_join(expected):
			return {"error": "当前配置路径不完整或版本不一致，已取消初始化。请重新启用插件后重试。"}
	var directory = DirAccess.open(root)
	if directory == null:
		return {"error": "无法打开配置目录，已取消初始化。"}
	var files: Array[String] = []
	var directories: Array[String] = []
	for prefix in ["setting", "models", "roles", "memory"]:
		var name: String = "%s.%s.json" % [prefix, version]
		if directory.is_link(name) or directory.dir_exists(name):
			return {"error": "配置目标包含链接或异常目录，已取消初始化。"}
		if directory.file_exists(name):
			files.append(root.path_join(name))
	var skills: String = "skills_" + version
	if directory.is_link(skills) or directory.file_exists(skills):
		return {"error": "技能目录异常，已取消初始化。"}
	if directory.dir_exists(skills):
		var error := _collect_tree(root.path_join(skills), files, directories)
		if not error.is_empty():
			return {"error": error}
	return {"error": "", "files": files, "directories": directories}

static func _collect_tree(path: String, files: Array[String], directories: Array[String]) -> String:
	var directory := DirAccess.open(path)
	if directory == null:
		return "无法读取技能目录，已取消初始化。"
	directory.include_hidden = true
	for name in directory.get_files() + directory.get_directories():
		if directory.is_link(name):
			return "技能目录包含链接，请先移除链接再初始化。"
		var child := path.path_join(name)
		if directory.dir_exists(name):
			var error := _collect_tree(child, files, directories)
			if not error.is_empty():
				return error
		else:
			files.append(child)
	directories.append(path)
	return ""

static func execute(plan: Dictionary) -> String:
	if not str(plan.get("error", "无效的初始化计划")).is_empty():
		return plan.get("error", "无效的初始化计划")
	for path in plan.files + plan.directories:
		if DirAccess.remove_absolute(path) != OK:
			return "部分配置无法删除：%s。请检查文件权限后重试。" % path
	return ""

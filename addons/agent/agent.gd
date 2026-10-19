@tool
class_name AlphaAgentPlugin
extends EditorPlugin

const project_alpha_dir: String = "res://.alpha/"

const MAIN_PANEL = preload("uid://baqbjml8ahgng")
const CONFIG = preload("uid://b4bcww0bmnxt0")

enum PluginLayout { DOCK, MAIN_SCREEN }

# Godot 在加入场景树之前和卸载时都会查询主屏幕能力，实例布局不可随设置变化。
var instance_layout: int = PluginLayout.DOCK
var main_panel: Control = null

func _init() -> void:
	# 绕过资源缓存，并通过变量读取资源属性，避免常量属性读取保留旧值。
	var disk_config = ResourceLoader.load("res://addons/agent/config.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as AgentConfig
	var config: AgentConfig = CONFIG
	if disk_config != null:
		config.alpha_version = disk_config.alpha_version
		config.system_prompt = disk_config.system_prompt
		config.compress_prompt = disk_config.compress_prompt
		config.memory.assign(disk_config.memory)
	global_setting.refresh_version_paths()
	var settings = global_setting
	if FileAccess.file_exists(settings.setting_file):
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(settings.setting_file)) == OK and parser.data is Dictionary:
			instance_layout = clampi(int(parser.data.get("plugin_layout", 0)), 0, 1)

func _has_main_screen() -> bool:
	return instance_layout == PluginLayout.MAIN_SCREEN

func _get_plugin_name() -> String:
	return "AlphaAgent"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Script", "EditorIcons")

func _make_visible(value: bool) -> void:
	if _has_main_screen() and is_instance_valid(main_panel):
		main_panel.visible = value

static func request_layout_refresh() -> void:
	var host = EditorInterface.get_base_control()
	if host.get_node_or_null("AlphaAgentResetController") != null:
		return
	var controller = host.get_node_or_null("AlphaAgentReloadController")
	if controller == null:
		controller = load("res://addons/agent/scripts/plugin_reload_controller.gd").new()
		controller.name = "AlphaAgentReloadController"
		host.add_child(controller)
	controller.request_refresh()

func _enable_plugin() -> void:
	pass

func _disable_plugin() -> void:
	pass

func _enter_tree() -> void:
	# 每次启用插件时复位就绪标志，确保面板通过信号等待新的 load_global_setting 完成
	global_setting.setting_is_ready = false

	print_greetings()

	# 初始化临时文件管理器
	AgentTempFileManager.get_instance().init()

	main_panel = MAIN_PANEL.instantiate()
	main_panel.set_meta("plugin_layout", instance_layout)
	if _has_main_screen():
		EditorInterface.get_editor_main_screen().add_child(main_panel)
		main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_panel.hide()
	else:
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, main_panel)

	# 初始化单例并设置 main_panel（必须在 load_global_setting 之前）
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.set_main_panel(main_panel)
	singleton.set_editor_plugin(self)

	# 初始化全局设置（在 main_panel 设置完成后）
	await global_setting.load_global_setting()

	# 所有初始化完成后打印结束语
	print_alpha_message("==$==*----*===*----*===*----*==$==")
	print_alpha_message("初始化结束，欢迎使用 [b]Alpha[/b]，始于初心，无限可能。")
	print_alpha_message("更多详细信息请查看：[url href='https://godotvillage.com/#/project/8665befd-9b55-46dd-9126-5d9bffdbc006']Alpha 官方网站[/url]")


func _exit_tree() -> void:
	var singleton = AlphaAgentSingleton.get_instance()
	if is_instance_valid(main_panel):
		if not _has_main_screen():
			remove_control_from_docks(main_panel)
		main_panel.queue_free()
	main_panel = null

	# 清理单例引用
	singleton.set_main_panel(null)
	singleton.set_editor_plugin(null)

func print_greetings():
	print_alpha_message("==$==*----*===*----*===*----*==$==")
	print_alpha_message("    ___     __        __")
	print_alpha_message("   /   |   / /____   / /_   ____ _")
	print_alpha_message("  / /| |  / // __ \\ / __ \\ / __ `/")
	print_alpha_message(" / ___ | / // /_/ // / / // /_/ /")
	print_alpha_message("/_/  |_|/_// .___//_/ /_/ \\__,_/")
	print_alpha_message("		   /_/")
	print_alpha_message("==$==*----*===*----*===*----*==$==")
	print_alpha_message("初始化插件中...")

static func print_alpha_message(str):
	print_rich("[color='#478cbf']{0}[/color]".format([str]))

enum SendShotcut {
	None,
	Enter,
	CtrlEnter
}

class GlobalSetting:
	signal setting_ready
	var setting_is_ready: bool = false

	var setting_dir = ""

	var setting_file: String = ""

	var project_alpha_dir = ""

	var models_file: String = ""
	var roles_file: String = ""
	var memory_file: String = ""
	var skill_directory: String = ""
	var config_version: String = ""

	var auto_clear: bool = false
	var load_recent_chat_on_start: bool = false
	var show_modified_files: bool = false
	var plugin_layout: int = PluginLayout.DOCK
	var auto_expand_think: bool = false
	var auto_add_file_ref: bool = true
	var send_shortcut: SendShotcut = SendShotcut.None
	var http_proxy_host: String = ""
	var http_proxy_port: String = ""
	var quick_model_supplier_id: String = ""
	var quick_model_model_id: String = ""
	var compress_threshold_ratio: float = 0.8
	var search_provider: String = ""
	var search_kimi_api_key: String = ""
	var search_deepseek_api_key: String = ""
	var search_zhihu_access_secret: String = ""
	var model_manager: ModelConfig.ModelManager = null
	var role_manager: AgentRoleConfig.RoleManager = null
	var skill_manager: AgentSkillConfig.SkillManager = null

	func _init() -> void:
		if Engine.is_editor_hint():
			setting_dir = EditorInterface.get_editor_paths().get_config_dir() + "/.alpha/"
		else:
			setting_dir = OS.get_config_dir() + ("/godot/.alpha/" if OS.get_name() == "Linux" else "/Godot/.alpha/")

		refresh_version_paths()
		project_alpha_dir = OS.get_user_data_dir() + "/.alpha/"

	func refresh_version_paths() -> void:
		var config: AgentConfig = CONFIG
		config_version = config.alpha_version
		setting_file = setting_dir + "setting.{version}.json".format({"version": config_version})
		models_file = setting_dir + "models.{version}.json".format({"version": config_version})
		roles_file = setting_dir + "roles.{version}.json".format({"version": config_version})
		memory_file = setting_dir + "memory.{version}.json".format({"version": config_version})
		skill_directory = setting_dir + "skills_{version}/".format({"version": config_version})

	func load_global_setting():

		AlphaAgentPlugin.print_alpha_message("加载全局设置（配置版本：%s）..." % config_version)
		if not DirAccess.dir_exists_absolute(setting_dir):
			DirAccess.make_dir_absolute(setting_dir)

		var setting_string = FileAccess.get_file_as_string(setting_file)
		if FileAccess.get_open_error() != OK:
			setting_string = ""

		var json = {}
		if setting_string != "":
			json = JSON.parse_string(setting_string)

		self.auto_clear = json.get("auto_clear", false)
		self.load_recent_chat_on_start = bool(json.get("load_recent_chat_on_start", false))
		self.show_modified_files = bool(json.get("show_modified_files", false))
		self.plugin_layout = clampi(int(json.get("plugin_layout", 0)), 0, 1)
		self.auto_expand_think = json.get("auto_expand_think", false)
		self.auto_add_file_ref = json.get("auto_add_file_ref", true)
		self.send_shortcut = json.get("send_shortcut", SendShotcut.Enter)
		self.http_proxy_host = str(json.get("http_proxy_host", ""))
		self.http_proxy_port = str(json.get("http_proxy_port", ""))
		self.quick_model_supplier_id = str(json.get("quick_model_supplier_id", ""))
		self.quick_model_model_id = str(json.get("quick_model_model_id", ""))
		self.compress_threshold_ratio = float(json.get("compress_threshold_ratio", 0.8))
		self.search_provider = str(json.get("search_provider", ""))
		self.search_kimi_api_key = str(json.get("search_kimi_api_key", ""))
		self.search_deepseek_api_key = str(json.get("search_deepseek_api_key", ""))
		self.search_zhihu_access_secret = str(json.get("search_zhihu_access_secret", ""))

		# 初始化模型管理器
		model_manager = ModelConfig.ModelManager.new(models_file)

		# 初始化角色管理器
		role_manager = AgentRoleConfig.RoleManager.new(roles_file)

		# 如果没有角色，等待一帧确保工具列表就绪后创建默认角色
		if role_manager.roles.is_empty():
			await AlphaAgentPlugin.wait_for_scene_tree_frame()
			role_manager.add_default_roles()

		# 初始化技能管理器
		skill_manager = AgentSkillConfig.SkillManager.new(skill_directory)

		setting_is_ready = true
		setting_ready.emit()

	func save_global_setting():
		var dict = {
			"auto_clear": self.auto_clear,
			"load_recent_chat_on_start": self.load_recent_chat_on_start,
			"show_modified_files": self.show_modified_files,
			"plugin_layout": self.plugin_layout,
			"auto_expand_think": self.auto_expand_think,
			"auto_add_file_ref": self.auto_add_file_ref,
			"send_shortcut": self.send_shortcut,
			"http_proxy_host": self.http_proxy_host,
			"http_proxy_port": self.http_proxy_port,
			"quick_model_supplier_id": self.quick_model_supplier_id,
			"quick_model_model_id": self.quick_model_model_id,
			"compress_threshold_ratio": self.compress_threshold_ratio,
			"search_provider": self.search_provider,
			"search_kimi_api_key": self.search_kimi_api_key,
			"search_deepseek_api_key": self.search_deepseek_api_key,
			"search_zhihu_access_secret": self.search_zhihu_access_secret,
		}
		var file = FileAccess.open(setting_file, FileAccess.WRITE)
		file.store_string(JSON.stringify(dict))
		file.close()

static var global_setting := GlobalSetting.new()

static var project_memory: Array[String] = []
static var global_memory: Array[String] = []
# 全局对话停止状态：发送时为 false，结束/停止时为 true
static var is_chat_stopped: bool = true

# ========== 场景树辅助函数 ==========

# 安全地获取场景树（用于等待帧，兼容编辑器和插件运行）
static func get_scene_tree() -> SceneTree:
	# 优先使用单例的场景树
	var singleton = AlphaAgentSingleton.get_instance()
	return singleton.get_scene_tree()

# 等待场景树可用并等待一帧（统一处理，兼容插件和编辑器环境）
# 已迁移到 AlphaAgentSingleton，这里保留作为向后兼容的代理
static func wait_for_scene_tree_frame():
	var singleton = AlphaAgentSingleton.get_instance()
	await singleton.wait_for_scene_tree_frame()

@tool
class_name AlphaAgentPlugin
extends EditorPlugin

const project_alpha_dir: String = "res://.alpha/"

const MAIN_PANEL = preload("uid://baqbjml8ahgng")
const CONFIG = preload("uid://b4bcww0bmnxt0")

func _enable_plugin() -> void:
	pass

func _disable_plugin() -> void:
	pass

func _enter_tree() -> void:
	var main_panel = MAIN_PANEL.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, main_panel)

	# 初始化单例并设置 main_panel
	var singleton = AlphaAgentSingleton.get_instance()
	singleton.set_main_panel(main_panel)
	singleton.set_editor_plugin(self)

func _exit_tree() -> void:
	var singleton = AlphaAgentSingleton.get_instance()
	var main_panel = singleton.main_panel

	if main_panel != null:
		remove_control_from_docks(main_panel)
		main_panel.queue_free()

	# 清理单例引用
	singleton.set_main_panel(null)
	singleton.set_editor_plugin(null)

enum SendShotcut {
	None,
	Enter,
	CtrlEnter
}

class GlobalSetting:
	var setting_dir = ""
	var setting_file: String = ""
	var models_file: String = ""
	var roles_file: String = ""

	var auto_clear: bool = false
	var auto_expand_think: bool = false
	var auto_add_file_ref: bool = true
	var send_shortcut: SendShotcut = SendShotcut.None
	var model_manager: ModelConfig.ModelManager = null
	var role_manager: AgentRoleConfig.RoleManager = null

	func _init() -> void:
		if Engine.is_editor_hint():
			setting_dir = EditorInterface.get_editor_paths().get_config_dir() + "/.alpha/"
		else:
			setting_dir = OS.get_config_dir() + ("/godot/.alpha/" if OS.get_name() == "Linux" else "/Godot/.alpha/")
		setting_file = setting_dir + "setting.{version}.json".format({"version": CONFIG.alpha_version})
		models_file = setting_dir + "models.{version}.json".format({"version": CONFIG.alpha_version})
		roles_file = setting_dir + "roles.{version}.json".format({"version": CONFIG.alpha_version})


	func load_global_setting():

		if not DirAccess.dir_exists_absolute(setting_dir):
			DirAccess.make_dir_absolute(setting_dir)

		var setting_string = FileAccess.get_file_as_string(setting_file)
		if FileAccess.get_open_error() != OK:
			setting_string = ""

		var json = {}
		if setting_string != "":
			json = JSON.parse_string(setting_string)

		self.auto_clear = json.get("auto_clear", false)
		self.auto_expand_think = json.get("auto_expand_think", false)
		self.auto_add_file_ref = json.get("auto_add_file_ref", true)
		self.send_shortcut = json.get("send_shortcut", SendShotcut.Enter)

		# 初始化模型管理器
		model_manager = ModelConfig.ModelManager.new(models_file)

		# 初始化角色管理器
		role_manager = AgentRoleConfig.RoleManager.new(roles_file)

	func save_global_setting():
		var dict = {
			"auto_clear": self.auto_clear,
			"auto_expand_think": self.auto_expand_think,
			"auto_add_file_ref": self.auto_add_file_ref,
			"send_shortcut": self.send_shortcut,
		}
		var file = FileAccess.open(setting_file, FileAccess.WRITE)
		file.store_string(JSON.stringify(dict))
		file.close()

static var global_setting := GlobalSetting.new()

static var project_memory: Array[String] = []
static var global_memory: Array[String] = []

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

@tool
class_name AlphaAgentPlugin
extends EditorPlugin

static var instance: AlphaAgentPlugin = null

const project_alpha_dir: String = "res://.alpha/"

const MAIN_PANEL = preload("uid://baqbjml8ahgng")

var main_panel: AgentMainPanel = null

enum PlanState {
	Plan,
	Active,
	Finish
}

class PlanItem:
	var name: String = ""
	var state: PlanState = PlanState.Plan
	func _init(name: String, state: PlanState) -> void:
		self.name = name
		self.state = state


signal update_plan_list(plan_list)
signal models_changed
signal roles_changed

func _enable_plugin() -> void:
	pass

func _disable_plugin() -> void:
	pass

func _enter_tree() -> void:
	instance = self
	main_panel = MAIN_PANEL.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, main_panel)

func _exit_tree() -> void:
	remove_control_from_docks(main_panel)
	main_panel.queue_free()
	instance = null

enum SendShotcut {
	None,
	Enter,
	CtrlEnter
}

class GlobalSetting:
	var setting_dir = OS.get_user_data_dir() + "/.alpha/"
	var setting_file: String = setting_dir + "setting.json"
	var models_file: String = setting_dir + "models.json"
	var roles_file: String = setting_dir + "roles.json"

	var auto_clear: bool = false
	var auto_expand_think: bool = false
	var auto_add_file_ref: bool = true
	var send_shortcut: SendShotcut = SendShotcut.None
	var model_manager: ModelConfig.ModelManager = null
	var role_manager: AgentRoleConfig.RoleManager = null

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

static  var global_setting := GlobalSetting.new()

static var project_memory: Array[String] = []
static var global_memory: Array[String] = []

# ========== 统一的实例访问辅助函数 ==========

# 获取插件实例（直接返回，不等待）
static func get_instance() -> AlphaAgentPlugin:
	return instance

# 等待插件实例可用并返回（用于编辑器调试和异步初始化）
static func wait_for_instance() -> AlphaAgentPlugin:
	# 如果实例已可用，直接返回
	if instance != null:
		return instance
	
	# 等待实例初始化
	var main_loop = Engine.get_main_loop()
	if main_loop == null:
		push_error("无法获取主循环")
		return null
	
	var scene_tree = main_loop as SceneTree
	if scene_tree == null:
		push_error("主循环不是 SceneTree")
		return null
	
	# 等待实例初始化
	var max_wait_time = 10.0  # 最多等待10秒
	var elapsed_time = 0.0
	var check_interval = 0.1  # 每0.1秒检查一次
	
	var start_time = Time.get_ticks_msec()
	while instance == null:
		await scene_tree.process_frame
		elapsed_time = (Time.get_ticks_msec() - start_time) / 1000.0
		if elapsed_time >= max_wait_time:
			push_error("等待插件实例超时（已等待 " + str(elapsed_time) + " 秒）")
			return null
	
	return instance

# 安全地获取场景树（用于等待帧，兼容编辑器和插件运行）
static func get_scene_tree() -> SceneTree:
	# 优先使用 instance 的场景树
	if instance != null:
		var tree = instance.get_tree()
		if tree != null:
			return tree
	
	# 如果 instance 的场景树不可用，使用主循环的场景树
	var main_loop = Engine.get_main_loop()
	if main_loop != null:
		var scene_tree = main_loop as SceneTree
		if scene_tree != null:
			return scene_tree
	
	return null

# 等待场景树可用并等待一帧（统一处理，用于编辑器调试）
static func wait_for_scene_tree_frame():
	var tree = get_scene_tree()
	if tree == null:
		push_error("无法获取场景树")
		return
	await tree.process_frame

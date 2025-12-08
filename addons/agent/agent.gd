@tool
class_name AlphaAgentPlugin
extends EditorPlugin

static var instance: AlphaAgentPlugin = null

const project_alpha_dir: String = "res://.alpha/"

const MAIN_PANEL = preload("uid://baqbjml8ahgng")

var main_panel = null

func _enable_plugin() -> void:
	pass

func _disable_plugin() -> void:
	pass

func _enter_tree() -> void:
	main_panel = MAIN_PANEL.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, main_panel)
	instance = self

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
	var setting_dir = EditorInterface.get_editor_paths().get_config_dir() + "/.alpha/"
	var setting_file: String = setting_dir + "setting.json"

	var auto_clear: bool = false
	var auto_expand_think: bool = false
	var auto_add_file_ref: bool = true
	var secret_key: String = ""
	var send_shortcut: SendShotcut = SendShotcut.None

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
		self.auto_expand_think = json.get("auto_clear", false)
		self.auto_add_file_ref = json.get("auto_add_file_ref", true)
		self.secret_key = json.get("secret_key", "")
		self.send_shortcut = json.get("send_shortcut", SendShotcut.Enter)

	func save_global_setting():
		var dict = {
			"auto_clear": self.auto_clear,
			"auto_expand_think": self.auto_expand_think,
			"secret_key": self.secret_key,
			"auto_add_file_ref": self.auto_add_file_ref,
			"send_shortcut": self.send_shortcut,
		}
		var file = FileAccess.open(setting_file, FileAccess.WRITE)
		file.store_string(JSON.stringify(dict))
		file.close()

static var global_setting := GlobalSetting.new()

static var project_memory: Array[String] = []
static var global_memory: Array[String] = []

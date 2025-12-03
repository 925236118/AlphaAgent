@tool
class_name AlphaAgentPlugin
extends EditorPlugin

static var instance: AlphaAgentPlugin = null

const MAIN_PANEL = preload("uid://baqbjml8ahgng")

var main_panel = null

func init_completions_settings():
	var settings = EditorInterface.get_editor_settings()
	settings.set("AlphaAgent/common/secret_key", "")

	var api_key_info = {
		"name": "AlphaAgent/common/secret_key",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_PASSWORD,
		"hint_string": "请输入密钥，sk-xxx"
	}

func erase_completions_settings():
	var settings = EditorInterface.get_editor_settings()
	settings.erase("AlphaAgent/common/secret_key")

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree() -> void:
	#init_completions_settings()
	main_panel = MAIN_PANEL.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, main_panel)
	instance = self

func _exit_tree() -> void:
	#erase_completions_settings()
	remove_control_from_docks(main_panel)
	main_panel.queue_free()
	instance = null

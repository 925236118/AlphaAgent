@tool
extends EditorPlugin

const MAIN_PANEL = preload("uid://baqbjml8ahgng")

var main_panel = null

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree() -> void:
	main_panel = MAIN_PANEL.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UR, main_panel)

func _exit_tree() -> void:
	remove_control_from_docks(main_panel)

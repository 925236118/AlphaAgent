@tool
extends EditorScript


# Called when the script is executed (using File -> Run in Script Editor).
func _run() -> void:
	print("hi")
	print(get_scene())
	var current_editor = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	#EditorInterface.get_script_editor().get_current_editor().get_base_editor().editable = not EditorInterface.get_script_editor().get_current_editor().get_base_editor().editable

	#EditorInterface.get_script_editor().get_current_editor().get_base_editor().insert_line_at(0, "hi\nworld")
	#.add_gutter()
	print(current_editor.get_gutter_count())

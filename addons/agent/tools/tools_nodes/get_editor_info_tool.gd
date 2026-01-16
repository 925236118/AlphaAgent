@tool
class_name GetEditorInfoTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "get_editor_info"

func _get_tool_short_description() -> String:
	return "获取当前编辑器相关信息。"

func _get_tool_description() -> String:
	return "获取当前编辑器打开的场景信息和编辑器中打开和编辑的脚本相关信息。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {},
		"required": []
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(_tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var script_editor := EditorInterface.get_script_editor()
	var editor_file_list: ItemList = script_editor.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1)
	var selected := editor_file_list.get_selected_items()
	var item_count = editor_file_list.item_count
	var select_index = -1
	if selected:
		select_index = selected[0]

	var edit_file_list = []
	var current_opend_script = ""
	for index in item_count:
		var file_path = editor_file_list.get_item_tooltip(index)
		if file_path.begins_with("res://"):
			edit_file_list.push_back(file_path)
			if select_index == index:
				current_opend_script = file_path

	return {
		"editor": {
			"opened_scenes": EditorInterface.get_open_scenes(),
			"current_edited_scene": EditorInterface.get_edited_scene_root().get_scene_file_path(),
			"current_scene_root_node": EditorInterface.get_edited_scene_root(),
			"current_opend_script": current_opend_script,
			"opend_scripts": edit_file_list
		},
	}

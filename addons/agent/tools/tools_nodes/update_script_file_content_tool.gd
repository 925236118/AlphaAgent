@tool
class_name UpdateScriptFileContentTool
extends AgentToolBase

var special_agent_chars = {
	"newline": {"origin_char": '{$$ALPHA&AGENT&NEWLINE&CHAR$$}', "replace_char": "\n"},
	"tab": {"origin_char": '{$$ALPHA&AGENT&TAB&CHAR$$}', "replace_char": "\t"},
	"quote": {"origin_char": '{$$ALPHA&AGENT&QUOTE&CHAR$$}', "replace_char": "\""},
}

func _get_tool_name() -> String:
	return "update_script_file_content"

func _get_tool_short_description() -> String:
	return "调用编辑器接口更新脚本文件的内容。"

func _get_tool_description() -> String:
	return "直接调用编辑器接口更新脚本文件的内容。根据行号和删除的行数量，在对应行删除若干行然后插入内容。如果不删除，则会在对应行**之前**添加内容。**依赖**：使用本工具修改代码后，代码的行号会发生变化，必须使用read_file工具查看执行结果。\n\n**特殊标记系统（ALPHA_AGENT专用）**：\n为避免JSON转义问题，请使用以下特殊标记代替转义字符：\n- 换行符：`{ALPHA_AGENT_NEWLINE_CHAR}`\n- 制表符：`{ALPHA_AGENT_TAB_CHAR}`\n- 双引号：`{ALPHA_AGENT_QUOTE_CHAR}`（仅当需要在字符串字面量中时）\n\n工具会自动将这些标记转换为对应的实际字符。**注意**：这些标记仅在本工具中有效，其他工具不会识别。\n\n**示例**：\n想要插入：`\\tprint(\"hello\")` 后换行，再写 `\\tprint(\"world\")`\n应该写成：`{ALPHA_AGENT_TAB_CHAR}print({ALPHA_AGENT_QUOTE_CHAR}hello{ALPHA_AGENT_QUOTE_CHAR}){ALPHA_AGENT_NEWLINE_CHAR}{ALPHA_AGENT_TAB_CHAR}print({ALPHA_AGENT_QUOTE_CHAR}world{ALPHA_AGENT_QUOTE_CHAR})`".format({
		"ALPHA_AGENT_NEWLINE_CHAR": special_agent_chars.newline.origin_char,
		"ALPHA_AGENT_TAB_CHAR": special_agent_chars.tab.origin_char,
		"ALPHA_AGENT_QUOTE_CHAR": special_agent_chars.quote.origin_char,
	})

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "需要打开的资源路径，必须是以res://开头的绝对路径。文件必须存在。"
			},
			"content": {
				"type": "string",
				"description": "需要写入的文件内容。**必须使用ALPHA_AGENT特殊标记**：\n\n**可用标记**：\n1. `{ALPHA_AGENT_NEWLINE_CHAR}` - 表示换行（\\n）\n2. `{ALPHA_AGENT_TAB_CHAR}` - 表示制表符缩进（\\t）\n3. `{ALPHA_AGENT_QUOTE_CHAR}` - 表示双引号（\"）\n\n**重要规则**：\n- 在JSON中直接写入这些标记字符串，不要进行额外转义\n- 例如：直接写 `{ALPHA_AGENT_NEWLINE_CHAR}`，不要写 `\\\\{ALPHA_AGENT_NEWLINE_CHAR\\\\}`\n- 工具收到后会进行替换\n\n**示例代码**：\n1. 单行带缩进：`{ALPHA_AGENT_TAB_CHAR}var x = 0`\n2. 两行带缩进：`{ALPHA_AGENT_TAB_CHAR}var a = 1{ALPHA_AGENT_NEWLINE_CHAR}{ALPHA_AGENT_TAB_CHAR}var b = 2`\n3. 带字符串：`print({ALPHA_AGENT_QUOTE_CHAR}test{ALPHA_AGENT_QUOTE_CHAR})`\n4. 复杂示例（Godot脚本）：\n`{ALPHA_AGENT_TAB_CHAR}func _ready():{ALPHA_AGENT_NEWLINE_CHAR}{ALPHA_AGENT_TAB_CHAR}{ALPHA_AGENT_TAB_CHAR}print({ALPHA_AGENT_QUOTE_CHAR}Hello{ALPHA_AGENT_QUOTE_CHAR})`".format({
					"ALPHA_AGENT_NEWLINE_CHAR": special_agent_chars.newline.origin_char,
					"ALPHA_AGENT_TAB_CHAR": special_agent_chars.tab.origin_char,
					"ALPHA_AGENT_QUOTE_CHAR": special_agent_chars.quote.origin_char,
				})
			},
			"line": {
				"type": "number",
				"description": "行号，从1开始。建议使用整数（如2而不是2.0）。"
			},
			"delete_line_count": {
				"type": "number",
				"description": "需要删除的行的数量，为0表示不删除。建议使用整数。"
			}
		},
		"required": ["script_path", "content", "line", "delete_line_count"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.EDITOR

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("script_path") and json.has("content") and json.has("line") and json.has("delete_line_count"):
		var script_path = json.script_path
		var content := json.content as String
		var line := json.line as int
		var delete_line_count = json.delete_line_count
		var resource: Script = load(script_path)

		AgentTempFileManager.get_instance().create_temp_file(script_path)

		for key in special_agent_chars.keys():
			var special_agent_char = special_agent_chars[key]
			content = content.replace(special_agent_char.origin_char, special_agent_char.replace_char)

		EditorInterface.set_main_screen_editor("Script")
		EditorInterface.edit_script(resource)

		var editor: CodeEdit = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
		for i in delete_line_count:
			editor.remove_line_at(max(line - 1, 0))
		editor.insert_line_at(max(line - 1, 0), content)

		await get_tree().process_frame
		var save_input_key := InputEventKey.new()
		save_input_key.pressed = true
		save_input_key.keycode = KEY_S
		save_input_key.alt_pressed = true
		save_input_key.command_or_control_autoremap = true

		EditorInterface.get_base_control().get_viewport().push_input(save_input_key)

		return { "success": "更新成功，使用read_file工具查看结果。" }

	return { "error": "调用失败。请检查参数是否正确。" }

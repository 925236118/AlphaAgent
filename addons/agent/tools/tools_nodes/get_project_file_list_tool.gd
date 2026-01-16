@tool
class_name GetProjectFileListTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "get_project_file_list"

func _get_tool_short_description() -> String:
	return "获取当前项目中文件以及其UID列表。"

func _get_tool_description() -> String:
	return "获取当前项目中所有文件以及其UID列表。**限制**：部分项目文件会很多，非用户明确说明，不要全量读取目录列表。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"start_path": {
				"type": "string",
				"description": "可以指定读取的目录，必须是以res://开头的绝对路径。只会返回这个目录下的文件和目录",
			},
			"interation": {
				"type": "number",
				"description": "迭代的次数，只有start_path参数有值时才会生效。如果为1，就只会查询一层文件和目录。默认为-1，会查询全部层级。",
			}
		},
		"required": []
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)

	var start_path := json.get("start_path", "res://") as String
	if not start_path.ends_with("/"):
		start_path += "/"

	var interation := int(json.get("interation", -1))

	var ignore_files = [".alpha", ".godot", "*.uid", "addons", "*.import"]
	var queue = [{
		"path": start_path,
		"interation": interation
	}]

	var file_list = []
	while queue.size():
		var current_item = queue.pop_front()
		var current_interation = current_item.interation
		var current_dir = current_item.path
		if current_interation == 0:
			continue
		var dir = DirAccess.open(current_dir)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				var match_result = true
				for reg in ignore_files:
					match_result = match_result and (not file_name.match(reg))
				if match_result:
					if dir.current_is_dir():
						file_list.push_back({
							"path": current_dir + file_name,
							"type": "directory"
						})
						queue.push_back({
							"path": current_dir + file_name + '/',
							"interation": current_interation - 1
						})
					else:
						file_list.push_back({
							"path": current_dir + file_name,
							"uid": ResourceUID.path_to_uid(current_dir + file_name),
							"type": "file"
						})
				file_name = dir.get_next()
		else:
			print("尝试访问路径时出错。")

	return {
		"list": file_list
	}

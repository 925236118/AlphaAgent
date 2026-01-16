@tool
class_name AddNodeToSceneTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "add_node_to_scene"

func _get_tool_short_description() -> String:
	return "添加节点到场景中。"

func _get_tool_description() -> String:
	return "为指定场景添加节点，支持内置节点和用户自定义节点。如果需要向场景添加节点应该优先考虑本工具。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"builtin_node_name": {
				"type": "string",
				"description": "如果添加的节点是Godot内置节点，本参数传入节点类名，否则为空字符串。",
			},
			"packed_scene_path": {
				"type": "string",
				"description": "如果添加的节点是用户自定义节点，本参数传入该节点在项目文件里的路径（必须是以res://开头），否则为空字符串。",
			},
			"target_scene_path": {
				"type": "string",
				"description": "被添加的场景在项目文件里的路径，必须是以res://开头。",
			},
			"parent_node_name": {
				"type": "string",
				"description": "被挂载的父节点在场景中的路径。从场景的根节点开始，用“/”分隔。",
			},
		},
		"required": ["builtin_node_name", "packed_scene_path", "target_scene_path", "parent_node_name"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.SCENE

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("builtin_node_name") and json.has("packed_scene_path") and json.has("target_scene_path") and json.has("parent_node_name"):
		var ok = await _add_node_to_scene(json.builtin_node_name, json.packed_scene_path, json.target_scene_path, json.parent_node_name)
		if ok:
			return { "success": "节点已添加。" }
		return { "error": "节点添加失败，请检查节点和目标场景。" }

	return { "error": "调用失败。请检查参数是否正确。" }


# 向场景中添加节点的主函数（从 tools.gd 迁移）
func _add_node_to_scene(
	builtin_node_name: String = "",
	packed_scene_path: String = "",
	target_scene_path: String = "",
	parent_node_name: String = ""
) -> bool:
	# 1. 参数验证
	if builtin_node_name != "" and packed_scene_path != "":
		push_error("错误：builtin_node_name 和 packed_scene_path 不能同时非空")
		return false

	if builtin_node_name == "" and packed_scene_path == "":
		push_error("错误：builtin_node_name 和 packed_scene_path 不能同时为空")
		return false

	if target_scene_path == "":
		push_error("错误：target_scene_path 不能为空")
		return false

	# 2. 打开目标场景
	if EditorInterface.get_edited_scene_root():
		var current_scene = EditorInterface.get_edited_scene_root()
		if current_scene and current_scene.get_scene_file_path() != target_scene_path:
			print("警告：切换场景前，请确保当前场景已保存")

	await EditorInterface.get_base_control().get_tree().process_frame
	EditorInterface.open_scene_from_path(target_scene_path)
	await EditorInterface.get_base_control().get_tree().process_frame

	# 3. 获取目标场景根节点
	var target_scene_root = EditorInterface.get_edited_scene_root()
	if not target_scene_root:
		push_error("错误：无法获取目标场景根节点")
		return false

	# 4. 创建新节点
	var new_node: Node
	if builtin_node_name != "":
		if not ClassDB.class_exists(builtin_node_name):
			push_error("错误：节点类型不存在: " + builtin_node_name)
			return false

		new_node = ClassDB.instantiate(builtin_node_name)
		if not new_node:
			push_error("错误：无法创建节点: " + builtin_node_name)
			return false

		new_node.name = _get_unique_node_name(target_scene_root, builtin_node_name, parent_node_name)
	else:
		if not ResourceLoader.exists(packed_scene_path):
			push_error("错误：场景文件不存在: " + packed_scene_path)
			return false

		var packed_scene = load(packed_scene_path)
		if not packed_scene or not packed_scene is PackedScene:
			push_error("错误：无法加载场景文件: " + packed_scene_path)
			return false

		new_node = packed_scene.instantiate()
		if new_node.name == "" or new_node.name == "Root":
			new_node.name = _get_unique_node_name(
				target_scene_root,
				packed_scene_path.get_file().get_basename(),
				parent_node_name
			)

	# 5. 查找父节点
	var parent_node: Node = target_scene_root
	if parent_node_name != "":
		parent_node = target_scene_root.get_node_or_null(NodePath(parent_node_name))
		if not parent_node:
			push_error("错误：父节点不存在: " + parent_node_name)
			new_node.free()
			return false

	# 6. 添加节点
	parent_node.add_child(new_node)
	new_node.owner = target_scene_root

	# 7. 选中新添加的节点
	var selection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(new_node)

	# 8. 确保场景保存标记
	_mark_scene_as_unsaved(target_scene_root)

	return true


# 辅助函数：获取唯一的节点名称
func _get_unique_node_name(scene_root: Node, base_name: String, parent_path: String = "") -> String:
	var parent: Node = scene_root
	if parent_path != "":
		parent = scene_root.get_node_or_null(NodePath(parent_path))
		if not parent:
			parent = scene_root

	var count = 1
	var name = base_name
	while true:
		var name_exists = false
		for child in parent.get_children():
			if child.name == name:
				name_exists = true
				break
		if not name_exists:
			break
		name = base_name + str(count)
		count += 1

	return name


# 标记场景为未保存状态
func _mark_scene_as_unsaved(scene_root: Node) -> void:
	var nodes_to_check = [scene_root]
	while nodes_to_check.size() > 0:
		var node = nodes_to_check.pop_front()
		if node.owner != scene_root and node.name != scene_root.name:
			node.owner = scene_root

		for child in node.get_children():
			nodes_to_check.append(child)

	EditorInterface.get_resource_filesystem().scan()

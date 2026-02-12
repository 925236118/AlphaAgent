@tool
class_name CreateSceneOrResourceTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "create_scene_or_resource"

func _get_tool_short_description() -> String:
	return "创建场景或资源文件。"

func _get_tool_description() -> String:
	return "创建场景（PackedScene）或任意资源（Resource）并保存到指定路径。场景创建成功后会自动在编辑器中打开。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"type": {
				"type": "string",
				"enum": ["scene", "resource"],
				"description": "创建类型：scene 表示创建场景，resource 表示创建资源。"
			},
			"path": {
				"type": "string",
				"description": "目标文件路径，必须是以res://开头的绝对路径。"
			},
			"class_name": {
				"type": "string",
				"description": "当type=resource时必填，表示要创建的Resource类名。"
			},
			"root_node_class": {
				"type": "string",
				"description": "当type=scene时必填，表示场景根节点类名。"
			}
		},
		"required": ["type", "path"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.FILE

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if json == null or not (json is Dictionary):
		return { "error": "调用失败。请检查参数是否正确。" }

	var create_type: String = str(json.get("type", ""))
	var path: String = str(json.get("path", ""))

	if create_type == "" or path == "":
		return { "error": "参数缺失：type 和 path 为必填项。" }
	if not path.begins_with("res://"):
		return { "error": "path 必须是以res://开头的绝对路径。" }
	if ResourceLoader.exists(path):
		return { "error": "目标文件已存在，不允许覆盖。" }

	match create_type:
		"scene":
			var root_node_class: String = str(json.get("root_node_class", ""))
			return _create_scene(path, root_node_class)
		"resource":
			var resource_class_name: String = str(json.get("class_name", ""))
			return _create_resource(path, resource_class_name)
		_:
			return { "error": "错误的type类型，仅支持 scene 或 resource。" }


func _create_scene(path: String, root_node_class: String) -> Dictionary:
	if root_node_class == "":
		return { "error": "type=scene 时必须提供 root_node_class。" }
	if not ClassDB.class_exists(root_node_class):
		return { "error": "root_node_class 不存在: %s" % root_node_class }

	var root_object = ClassDB.instantiate(root_node_class)
	if root_object == null or not (root_object is Node):
		return { "error": "root_node_class 不是可实例化的Node类型: %s" % root_node_class }

	var root_node := root_object as Node
	if root_node.name.is_empty():
		root_node.name = root_node_class if not root_node_class.is_empty() else "Root"
	var scene := PackedScene.new()
	var pack_error := scene.pack(root_node)
	root_node.free()
	if pack_error != OK:
		return { "error": "场景打包失败: %s" % error_string(pack_error) }

	var save_error := ResourceSaver.save(scene, path)
	if save_error != OK:
		return { "error": "场景保存失败: %s" % error_string(save_error) }

	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(path)

	return {
		"success": "场景创建成功",
		"type": "scene",
		"path": path,
		"uid": ResourceUID.path_to_uid(path)
	}


func _create_resource(path: String, resource_class_name: String) -> Dictionary:
	if resource_class_name == "":
		return { "error": "type=resource 时必须提供 class_name。" }
	if not ClassDB.class_exists(resource_class_name):
		return { "error": "class_name 不存在: %s" % resource_class_name }

	var resource_object = ClassDB.instantiate(resource_class_name)
	if resource_object == null or not (resource_object is Resource):
		return { "error": "class_name 不是可实例化的Resource类型: %s" % resource_class_name }

	var resource := resource_object as Resource
	var save_error := ResourceSaver.save(resource, path)
	if save_error != OK:
		return { "error": "资源保存失败: %s" % error_string(save_error) }

	EditorInterface.get_resource_filesystem().scan()

	return {
		"success": "资源创建成功",
		"type": "resource",
		"path": path,
		"uid": ResourceUID.path_to_uid(path)
	}

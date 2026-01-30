@tool
class_name AgentToolUtils
extends RefCounted

## 说明：
## - 本文件只放“多个工具会复用”的纯工具函数/通用逻辑，避免重复（DRY）。
## - 需要状态（如临时文件列表、特殊字符表）由调用方工具脚本自己持有/管理。

const DEFAULT_IGNORE_DIRS: Array[String] = [".alpha", ".godot", "*.uid", "addons", "*.import"]

## 全局搜索（递归）
static func search_recursive(
	text: String,
	results: Array,
	path: String = "res://",
	extensions: Array[String] = [".gd", ".md", ".gdshader"],
	ignore_dirs: Array[String] = DEFAULT_IGNORE_DIRS
) -> Array:
	var dir = DirAccess.open(path)
	if not dir:
		return []

	dir.list_dir_begin()
	var item = dir.get_next()

	while item != "":
		var full_path = path.path_join(item)

		if dir.current_is_dir():
			var should_ignore = false
			for ignore_pattern in ignore_dirs:
				if item.match(ignore_pattern):
					should_ignore = true
					break

			if not item.begins_with(".") and not should_ignore:
				search_recursive(text, results, full_path, extensions, ignore_dirs)
		else:
			var file_ext = "." + item.get_extension()
			if extensions.has(file_ext):
				var file = FileAccess.open(full_path, FileAccess.READ)
				if file:
					var line_num = 1
					while not file.eof_reached():
						var line_content = file.get_line()
						if line_content.contains(text):
							results.append({
								"path": full_path,
								"line": line_num,
								"content": line_content
							})
						line_num += 1
					file.close()

		item = dir.get_next()

	dir.list_dir_end()
	return results


## 写入文件（工具侧通用版本，不处理临时文件；临时文件由调用方决定是否创建）
static func write_file(path: String, content: String) -> Error:
	var ensure_dir_error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if ensure_dir_error != OK:
		return ensure_dir_error

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file == null:
		file.store_string(content)
		file.close()

		EditorInterface.get_resource_filesystem().update_file(path)
		EditorInterface.get_script_editor().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		return OK

	return file.get_open_error()


## 通过 ScriptCreateDialog 创建脚本文件
static func create_script(inherits: String, path: String) -> bool:
	if ResourceLoader.exists(path):
		return false

	if ClassDB.class_exists(inherits) or ((inherits.begins_with("res://") and inherits.ends_with(".gd")) and ResourceLoader.exists(inherits)):
		var dialog = ScriptCreateDialog.new()
		dialog.config(inherits, path)
		EditorInterface.get_base_control().add_child(dialog)
		dialog.popup_centered()
		await EditorInterface.get_base_control().get_tree().process_frame
		dialog.get_ok_button().pressed.emit()
		return true

	return false


## 获取目标节点（会打开场景并在编辑器中选中）
static func get_target_node(scene_path: String, node_path: String) -> Node:
	if not ResourceLoader.exists(scene_path):
		return null

	var opened_scene = ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	if not opened_scene:
		printerr("错误：无法打开场景 '", scene_path, "'。请检查路径是否正确。")
		return null
	else:
		EditorInterface.open_scene_from_path(scene_path)

	var instance = opened_scene.instantiate()
	if instance is Node2D:
		EditorInterface.set_main_screen_editor("2D")
	elif instance is Node3D:
		EditorInterface.set_main_screen_editor("3D")
	else:
		EditorInterface.set_main_screen_editor("2D")
	instance.call_deferred("queue_free")

	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		printerr("错误：场景打开后，无法获取其根节点。")
		return null

	var target_node = scene_root.get_node(node_path)
	if not target_node:
		printerr("错误：在场景 '", scene_root.name, "' 中找不到路径为 '", node_path, "' 的节点。请检查节点路径是否正确。")
		return null

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(target_node)

	return target_node


## 设置场景中节点属性
static func update_scene_node_property(scene_path: String, node_path: String, property_name: String, property_value: String) -> bool:
	var target_node = get_target_node(scene_path, node_path)
	if not target_node:
		printerr("错误，未能找到"+scene_path+"内的目标节点"+node_path)
		return false

	if not property_name in target_node:
		printerr("错误：节点 '", target_node.name, "' 没有名为 '", property_name, "' 的属性。")
		return false

	target_node.set(property_name, str_to_var(property_value))
	EditorInterface.edit_node(target_node)
	return true


## 设置节点某个需要资源的属性（包括嵌套在资源内）
static func set_resource_property(resource_path: String, scene_path: String, node_path: String, property_name: String) -> bool:
	var resource = load(resource_path)
	if resource == null:
		print("错误: 无法加载资源文件: ", resource_path)
		return false

	var opened_scene = ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	if not opened_scene:
		printerr("错误：无法打开场景 '", scene_path, "'。请检查路径是否正确。")
		return false
	else:
		EditorInterface.open_scene_from_path(scene_path)

	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		print("错误：场景打开后，无法获取其根节点。")
		return false

	var target_node = scene_root.get_node(node_path)
	if target_node == null:
		print("错误: 在场景中找不到节点路径: ", node_path)
		return false

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(target_node)

	var array := property_name.split("/")
	if _set_res_recursive(target_node, array, resource):
		EditorInterface.edit_node(target_node)
		return true
	return false


static func _set_res_recursive(target: Object, property_target: Array[String], res: Resource) -> bool:
	if property_target.size() > 1:
		var property = property_target.pop_front()
		if property in target:
			return _set_res_recursive(target.get(property), property_target, res)
		printerr("路径存在问题")
		return false

	if property_target[0] in target:
		target.set(property_target[0], res)
		return true

	printerr("未找到属性", property_target[0])
	return false


## 获取 TileSet 数据
static func get_tileset_info(tileset: TileSet) -> Dictionary:
	var tileset_data = {}
	for source_index in tileset.get_source_count():
		var source = tileset.get_source(tileset.get_source_id(source_index))
		if source is TileSetAtlasSource:
			var atlas_data = {}
			for tile_index in source.get_tiles_count():
				var tile_data = source.get_tile_data(source.get_tile_id(tile_index), 0)
				atlas_data[source.get_tile_id(tile_index)] = tile_data_to_dict(tile_data, tileset)

			tileset_data[tileset.get_source_id(source_index)] = atlas_data
		tileset_data["texture/" + str(tileset.get_source_id(source_index))] = source.texture.resource_path
	return tileset_data


static func tile_data_to_dict(tile_data: TileData, tileset: TileSet) -> Dictionary:
	var dict := {}
	var physics_layers_count = tileset.get_physics_layers_count()
	var navigation_layers_count = tileset.get_navigation_layers_count()
	var custom_data_layers_count = tileset.get_custom_data_layers_count()
	var occlusion_layers_count = tileset.get_occlusion_layers_count()

	dict["flip_h"] = tile_data.flip_h
	dict["flip_v"] = tile_data.flip_v
	dict["transpose"] = tile_data.transpose
	dict["z_index"] = tile_data.get_z_index()
	dict["y_sort_origin"] = tile_data.get_y_sort_origin()
	dict["material"] = str(tile_data.material.resource_path) if tile_data.material else ""

	dict["texture_origin"] = tile_data.texture_origin
	dict["modulate"] = var_to_str(tile_data.get_modulate())

	var physics_layers := []
	for layer_index in physics_layers_count:
		var physic_layer := {}
		physic_layer["constant_angular_velocity"] = tile_data.get_constant_angular_velocity(layer_index)
		physic_layer["constant_linear_velocity"] = tile_data.get_constant_linear_velocity(layer_index)
		var polygons_count = tile_data.get_collision_polygons_count(layer_index)
		for polygons_index in polygons_count:
			var polygons_info := {}
			polygons_info["collision_polygon_points"] = tile_data.get_collision_polygon_points(layer_index, polygons_index)
			polygons_info["collision_polygon_one_way"] = tile_data.is_collision_polygon_one_way(layer_index, polygons_index)
			polygons_info["collision_polygon_one_way_margin"] = tile_data.get_collision_polygon_one_way_margin(layer_index, polygons_index)
			physic_layer["polygons:"+str(polygons_index)] = polygons_info
		physics_layers.append(physic_layer)
	dict["physics_layers"] = physics_layers

	var navigation_layers := []
	for layer_index in navigation_layers_count:
		navigation_layers.append(tile_data.get_navigation_polygon(layer_index))
	dict["navigation_layers"] = navigation_layers

	var custom_data := {}
	for layer_index in custom_data_layers_count:
		var layer_name = tileset.get_custom_data_layer_name(layer_index)
		custom_data[layer_name] = tile_data.get_custom_data(layer_name)
	dict["custom_data"] = custom_data

	dict["terrain_set"] = tile_data.terrain_set
	dict["terrain"] = tile_data.terrain
	dict["probability"] = tile_data.probability

	dict["alternative_tile"] = tile_data.alternative_tile if "alternative_tile" in tile_data else -1

	var occlusion_layers := []
	for layer_index in occlusion_layers_count:
		var occlusion_layer := {}
		var occlusion_count = tile_data.get_occluder_polygons_count(layer_index)
		for occlusion_index in occlusion_count:
			var occlusion_info := {}
			occlusion_info["occlusion_polygon_points"] = tile_data.get_occluder_polygon(layer_index, occlusion_index)
			occlusion_layer["occlusion:"+str(occlusion_index)] = occlusion_info
		occlusion_layers.append(occlusion_layer)
	dict["occlusion_layers"] = occlusion_layers

	return dict


## 命令行调用工具（同步执行）
static func execute_command(command: String, args: Array = []) -> Dictionary:
	var result = {
		"success": false,
		"output": []
	}

	var working_dir = ProjectSettings.globalize_path("res://")
	var shell = "bash" if OS.get_name() != "Windows" else "cmd"
	var shell_args = []

	if OS.get_name() != "Windows":
		var full_command = "cd '" + working_dir + "' && " + command + " " + " ".join(args)
		shell_args = ["-c", full_command]
	else:
		var full_command = "cd /d \"" + working_dir + "\" && " + command + " " + " ".join(args)
		shell_args = ["/c", full_command]

	var error_code = OS.execute(shell, shell_args, result.output, true, false)
	if error_code == -1:
		result.error = "命令执行失败"
		return result

	result.output = result.output
	result.success = true
	return result

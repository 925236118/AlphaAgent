@tool
class_name ResourceInspectorTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "resource_inspector"

func _get_tool_short_description() -> String:
	return "获取资源的文件结构。"

func _get_tool_description() -> String:
	return "指定一个路径的资源，获取其文件结构，可选额外获取meta数据（默认不需要）。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"resource_path": {
				"type": "string",
				"description": "需要资源文件路径，必须是以res://开头的绝对路径。",
			},
			"include_meta": {
				"type": "string",
				"description": "是否需要meta数据，默认为false",
			}
		},
		"required": ["resource_path"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	var resource_structure: Dictionary = {}
	if not json == null and json.has("resource_path"):
		resource_structure = get_resource_structure(load(json.resource_path), false if !json.has("include_meta") else json.include_meta)
	return resource_structure

# 主函数：获取Resource的完整结构
static func get_resource_structure(resource: Resource, include_meta: bool = false) -> Dictionary:
	var visited_ids := {}
	var structure := _recursive_inspect_resource(resource, visited_ids, include_meta, 0)
	return {
		"resource_type": resource.get_class(),
		"resource_path": resource.resource_path,
		"structure": structure,
		"visited_count": visited_ids.size()
	}

# 递归检查Resource
static func _recursive_inspect_resource(resource: Resource, visited_ids: Dictionary, 
									   include_meta: bool, depth: int, max_depth: int = 50) -> Dictionary:
	# 防止无限递归
	if depth > max_depth:
		return {"error": "Maximum recursion depth exceeded"}
	
	var resource_id := resource.get_instance_id()
	if visited_ids.has(resource_id):
		return {"reference_to": visited_ids[resource_id], "is_circular": true}
	
	visited_ids[resource_id] = resource.resource_path if resource.resource_path else str(resource_id)
	
	var result := {}
	var property_list := resource.get_property_list()
	
	for property_info in property_list:
		var property_name: String = property_info["name"]
		var property_type: int = property_info["type"]
		var usage: int = property_info["usage"]
		
		# 过滤掉内部属性和方法
		if _should_skip_property(property_name, usage):
			continue
		
		# 尝试获取属性值
		var property_value = resource.get(property_name)
		
		# 根据类型处理
		var property_data := {
			"type": _get_type_name(property_type),
			"type_code": property_type,
			"value": null,
			"is_resource": false,
			"is_array": false,
			"is_dictionary": false
		}
		
		if property_value != null:
			property_data["value"] = _process_property_value(
				property_value, 
				property_name,
				visited_ids,
				include_meta,
				depth + 1
			)
			
			# 标记特殊类型
			if property_value is Resource:
				property_data["is_resource"] = true
			elif property_value is Array:
				property_data["is_array"] = true
			elif property_value is Dictionary:
				property_data["is_dictionary"] = true
		
		result[property_name] = property_data
	
	# 包含元数据（可选）
	if include_meta:
		result["__meta"] = {
			"class": resource.get_class(),
			"base_class": resource.get_class(),
			"script": resource.get_script().resource_path if resource.get_script() else null,
			"resource_path": resource.resource_path,
			"depth": depth
		}
	
	return result

# 处理属性值
static func _process_property_value(value, property_name: String, visited_ids: Dictionary, 
								   include_meta: bool, depth: int):
	if value is Resource:
		return _recursive_inspect_resource(value, visited_ids, include_meta, depth)
	
	elif value is Array:
		var array_result := []
		for i in range(value.size()):
			var element = value[i]
			if element is Resource:
				array_result.append(_recursive_inspect_resource(element, visited_ids, include_meta, depth))
			else:
				array_result.append({
					"value": element,
					"type": typeof(element),
					"index": i
				})
		return array_result
	
	elif value is Dictionary:
		var dict_result := {}
		for key in value.keys():
			var element = value[key]
			if element is Resource:
				dict_result[key] = _recursive_inspect_resource(element, visited_ids, include_meta, depth)
			else:
				dict_result[key] = {
					"value": element,
					"type": typeof(element)
				}
		return dict_result
	
	else:
		return value

# 跳过不需要的属性
static func _should_skip_property(property_name: String, usage: int) -> bool:
	# 跳过Godot内置属性
	if property_name.begins_with("_") or property_name == "script" or property_name == "resource_local_to_scene":
		return true
	
	# 根据usage标志过滤
	var is_storage = (usage & PROPERTY_USAGE_STORAGE) != 0
	var is_editor = (usage & PROPERTY_USAGE_EDITOR) != 0
	
	# 可以根据需要调整过滤条件
	return not (is_storage or is_editor)

# 获取类型名称
static func _get_type_name(type_code: int) -> String:
	var type_names = {
		TYPE_NIL: "null",
		TYPE_BOOL: "bool",
		TYPE_INT: "int",
		TYPE_FLOAT: "float",
		TYPE_STRING: "String",
		TYPE_VECTOR2: "Vector2",
		TYPE_VECTOR2I: "Vector2i",
		TYPE_RECT2: "Rect2",
		TYPE_RECT2I: "Rect2i",
		TYPE_VECTOR3: "Vector3",
		TYPE_VECTOR3I: "Vector3i",
		TYPE_VECTOR4: "Vector4",
		TYPE_VECTOR4I: "Vector4i",
		TYPE_TRANSFORM2D: "Transform2D",
		TYPE_PLANE: "Plane",
		TYPE_QUATERNION: "Quaternion",
		TYPE_AABB: "AABB",
		TYPE_BASIS: "Basis",
		TYPE_TRANSFORM3D: "Transform3D",
		TYPE_PROJECTION: "Projection",
		TYPE_COLOR: "Color",
		TYPE_STRING_NAME: "StringName",
		TYPE_NODE_PATH: "NodePath",
		TYPE_RID: "RID",
		TYPE_OBJECT: "Object",
		TYPE_CALLABLE: "Callable",
		TYPE_SIGNAL: "Signal",
		TYPE_DICTIONARY: "Dictionary",
		TYPE_ARRAY: "Array",
		TYPE_PACKED_BYTE_ARRAY: "PackedByteArray",
		TYPE_PACKED_INT32_ARRAY: "PackedInt32Array",
		TYPE_PACKED_INT64_ARRAY: "PackedInt64Array",
		TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
		TYPE_PACKED_FLOAT64_ARRAY: "PackedFloat64Array",
		TYPE_PACKED_STRING_ARRAY: "PackedStringArray",
		TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array",
		TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array",
		TYPE_PACKED_COLOR_ARRAY: "PackedColorArray"
	}
	
	return type_names.get(type_code, "Unknown")

# 简洁版本：只获取属性名称和类型
static func get_resource_properties(resource: Resource) -> Dictionary:
	var result := {}
	var property_list := resource.get_property_list()
	
	for property_info in property_list:
		var property_name: String = property_info["name"]
		var usage: int = property_info["usage"]
		
		if _should_skip_property(property_name, usage):
			continue
		
		var property_type = property_info["type"]
		var type_name = _get_type_name(property_type)
		
		# 获取属性值
		var value = null
		if resource.get(property_name) is Resource:
			value = "[Resource]"
		else:
			value = resource.get(property_name)
		
		result[property_name] = {
			"type": type_name,
			"value": value,
			"hint": property_info.get("hint", 0),
			"hint_string": property_info.get("hint_string", "")
		}
	
	return result

# 导出为JSON字符串（便于调试）
static func resource_to_json(resource: Resource, indent: bool = true) -> String:
	var structure = get_resource_structure(resource, true)
	var json_string = JSON.stringify(structure, "\t" if indent else "")
	
	# 保存到文件（可选）
	# var file = FileAccess.open("user://resource_structure.json", FileAccess.WRITE)
	# file.store_string(json_string)
	
	return json_string

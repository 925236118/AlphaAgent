@tool
class_name GetClassDocTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "get_class_doc"

func _get_tool_short_description() -> String:
	return "获取Godot原生类的文档信息。"

func _get_tool_description() -> String:
	return "获得Godot原生的类的文档，文档中包含这个类的属性、方法以及参数和返回值、信号、枚举常量、父类、派生类等信息。直接查询为请求信息的列表。可以单独查询某些数据。**注意**：默认情况应尽量查询部分信息。除非对这个类没有了解。**限制**：只能查询Godot的原生类。如果是用户自定义的类，应读取文件内容分析。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"class_name": {
				"type": "string",
				"description": "需要查询的类名",
			},
			"signals": {
				"type": "array",
				"description": "需要查询的信号名列表",
			},
			"properties": {
				"type": "array",
				"description": "需要查询的属性名列表",
			},
			"enums": {
				"type": "array",
				"description": "需要查询的枚举列表",
			}
		},
		"required": ["class_name"]
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("class_name"):
		var cname = json.get("class_name")
		if ClassDB.class_exists(cname):
			if json.has("signals"):
				var signals_array = json.get("signals")
				return {
					"class_name": cname,
					"signals": signals_array.map(func (sig): return ClassDB.class_get_signal(cname, sig))
				}
			elif json.has("properties"):
				var properties_array = json.get("properties")
				return {
					"class_name": cname,
					"properties": properties_array.map(func (prop): return {
						"default_value": ClassDB.class_get_property_default_value(cname, prop),
						"setter": ClassDB.class_get_property_setter(cname, prop),
						"getter": ClassDB.class_get_property_getter(cname, prop),
					})
				}
			elif json.has("enums"):
				var enums_array = json.get("enums")
				return {
					"class_name": cname,
					"enums": enums_array.map(func (enum_name): return {
						"enum": enum_name,
						"values": ClassDB.class_get_enum_constants(cname, enum_name)
					})
				}
			else:
				return {
					"class_name": cname,
					"api_type": ClassDB.class_get_api_type(cname),
					"properties": ClassDB.class_get_property_list(cname),
					"methods": ClassDB.class_get_method_list(cname),
					"enums": ClassDB.class_get_enum_list(cname),
					"parent_class": ClassDB.get_parent_class(cname),
					"inheriters_class": ClassDB.get_inheriters_from_class(cname),
					"signals": ClassDB.class_get_signal_list(cname),
					"constants": ClassDB.class_get_integer_constant_list(cname)
				}
		return {
			"error": "%s 类不存在" % cname
		}

	return {
		"error": "调用失败。请检查参数是否正确。"
	}

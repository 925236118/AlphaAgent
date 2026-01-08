@tool
class_name AgentTools
extends Node

@export_tool_button("测试") var test_action = test

var thread: Thread = null

# 只读工具列表
var readonly_tools_list: Array[String] = [
	"get_project_info",
	"get_editor_info",
	"get_project_file_list",
	"get_class_doc",
	"get_image_info",
	"get_tileset_info",
	"read_file",
	"check_script_error"
]

func test():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "update_script_file_content"
	tool.function.arguments = JSON.stringify({
		"script_path": "res://new_script.gd",
		"content": "test 11111",
		"line": 10,
		"delete_line_count": 1,
	})
	#var image = load("res://icon.svg")
	print(await use_tool(tool))
	#print(ProjectSettings.get_setting("input"))
	#var process_id = OS.create_instance(["--headless", "--script", "res://game.gd"])
	pass

# 获取工具名称列表
func get_function_name_list():
	return {
		"update_plan_list": {
			"readonly": false,
			"group": "Agent",
			"description": "用于管理Agent的计划列表"
		},
		"get_project_info": {
			"readonly": true,
			"group": "查询操作",
			"description": "获取当前的引擎信息和项目配置信息。"
		},
		"get_editor_info": {
			"readonly": true,
			"group": "查询操作",
			"description": "获取当前编辑器相关信息。"
		},
		"get_project_file_list": {
			"readonly": true,
			"group": "查询操作",
			"description": "获取当前项目中文件以及其UID列表。"
		},
		"get_class_doc": {
			"readonly": true,
			"group": "查询操作",
			"description": "获取Godot原生类的文档信息。"
		},
		"get_image_info": {
			"readonly": true,
			"group": "查询操作",
			"description": "获取图片文件信息。"
		},
		"get_tileset_info": {
			"readonly": true,
			"group": "查询操作",
			"description": "获取TileSet信息。"
		},
		"read_file": {
			"readonly": true,
			"group": "文件操作",
			"description": "读取文件内容。"
		},
		"create_folder": {
			"readonly": false,
			"group": "文件操作",
			"description": "创建文件夹。"
		},
		"write_file": {
			"readonly": false,
			"group": "文件操作",
			"description": "全量替换写入文件内容。"
		},
		"add_script_to_scene": {
			"readonly": false,
			"group": "场景操作",
			"description": "将脚本加载到节点上。"
		},
		"sep_script_to_scene": {
			"readonly": false,
			"group": "场景操作",
			"description": "将节点上的脚本分离。"
		},
		"check_script_error": {
			"readonly": true,
			"group": "调试操作",
			"description": "检查脚本中的语法错误。"
		},
		"open_resource": {
			"readonly": false,
			"group": "编辑器操作",
			"description": "使用编辑器打开资源文件。"
		},
		"update_script_file_content": {
			"readonly": false,
			"group": "编辑器操作",
			"description": "调用编辑器接口更新脚本文件的内容。"
		},
		"update_scene_node_property": {
			"readonly": false,
			"group": "编辑器操作",
			"description": "调用编辑器接口设置场景中的节点的属性。"
		},
		"set_resource_property": {
			"readonly": false,
			"group": "编辑器操作",
			"description": "调用编辑器接口设置资源属性。"
		},
		"set_singleton": {
			"readonly": false,
			"group": "编辑器操作",
			"description": "调用编辑器接口设置自动加载脚本或场景。"
		},
		"execute_command": {
			"readonly": false,
			"group": "命令行操作",
			"description": "执行命令行命令。"
		},
	}

# 获取只读工具列表
func get_readonly_tools_list() -> Array[Dictionary]:
	var tool_list: Array[Dictionary] = []
	for tool in get_tools_list():
		if readonly_tools_list.has(tool.function.name):
			tool_list.push_back(tool)
	return tool_list

# 获取筛选后的工具列表
func get_filtered_tools_list(filter_list: Array) -> Array[Dictionary]:
	return get_tools_list().filter(func(tool: Dictionary) -> bool:
		return filter_list.has(tool.function.name)
	)

# 获取工具列表
func get_tools_list() -> Array[Dictionary]:
	return [
#region 生成相关
		# update_plan_list
		{
			"type": "function",
			"function": {
				"name": "update_plan_list",
				"description": "对于用户给出的复杂的任务，可以拆分成多段执行的，需要使用本工具对任务拆分成若干个阶段。还可以更新当前已有的阶段任务状态。",
				"parameters": {
					"type": "object",
					"properties": {
						"tasks": {
							"type": "array",
							"description": "拆分后的阶段任务项，数量在5到10个之间。按照执行顺序排序。**注意**:列表中应只有一个任务为active状态。",
							"items": {
								"type": "object",
								"properties": {
									"name": {
										"type": "string",
										"description": "要执行的阶段任务名称。",
									},
									"state": {
										"type": "string",
										"enum": ["plan", "active", "finish"],
										"description": "该阶段的当前状态。"
									}
								},
								"required": ["name", "state"]
							}
						},
					},
					"required": ["tasks"]
				}
			}
		},

#endregion
#region 查询
		# get_project_info
		{
			"type": "function",
			"function": {
				"name": "get_project_info",
				"description": "获取当前的Godot引擎信息。包含Godot版本，CPU型号、CPU 架构、内存信息、显卡信息、设备型号、当前系统时间等，还有当前项目的一些信息，例如项目名称、项目版本、项目描述、项目运行主场景、游戏运行窗口信息、全局的物理信息、全局的渲染设置、主题信息等。还有自动加载和输入映射，需要从project.godot中读取。",
				"parameters": {
					"type": "object",
					"properties": {},
					"required": []
				}
			}
		},
		# get_editor_info
		{
			"type": "function",
			"function": {
				"name": "get_editor_info",
				"description": "获取当前编辑器打开的场景信息和编辑器中打开和编辑的脚本相关信息。",
				"parameters": {
					"type": "object",
					"properties": {},
					"required": []
				}
			}
		},
		# get_project_file_list
		{
			"type": "function",
			"function": {
				"name": "get_project_file_list",
				"description": "获取当前项目中所有文件以及其UID列表。**限制**：部分项目文件会很多，非用户明确说明，不要全量读取目录列表。",
				"parameters": {
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
			}
		},
		# get_class_doc
		{
			"type": "function",
			"function": {
				"name": "get_class_doc",
				"description": "获得Godot原生的类的文档，文档中包含这个类的属性、方法以及参数和返回值、信号、枚举常量、父类、派生类等信息。直接查询为请求信息的列表。可以单独查询某些数据。**注意**：默认情况应尽量查询部分信息。除非对这个类没有了解。**限制**：只能查询Godot的原生类。如果是用户自定义的类，应读取文件内容分析。",
				"parameters": {
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
			}
		},
		# get_image_info
		{
			"type": "function",
			"function": {
				"name": "get_image_info",
				"description": "获取图片文件信息，可以获得图片的格式、大小、uid等信息",
				"parameters": {
					"type": "object",
					"properties": {
						"image_path": {
							"type": "string",
							"description": "需要读取的图片文件目录，必须是以res://开头的绝对路径。",
						},
					},
					"required": ["image_path"]
				}
			}
		},
		# get_tileset_info
		{
			"type": "function",
			"function": {
				"name": "get_tileset_info",
				"description": "获取TileSet的所有信息，包括纹理原点、调色、Z索引、Y排序原点、地形、概率、物理、导航、自定义数据和光照遮挡等。",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": {
							"type": "string",
							"description": "想获取的TileSet所在的场景路径，必须是以res://开头的路径。",
						},
						"tile_map_path": {
							"type": "string",
							"description": "想获取的TileSet被挂载在的TileMapLayer节点在场景树中的路径。从场景的根节点开始，用“/”分隔。",
						},
					},
					"required": ["scene_path","tile_map_path"]
				}
			}
		},
#endregion
#region 文件操作
		# read_file
		{
			"type": "function",
			"function": {
				"name": "read_file",
				"description": "读取文件内容。可以指定读取的开始行号和结束行号，默认是1和-1，表示读取到文件末尾。**限制**：此工具最多会读取500行文件内容。返回内容中包含总行数和开始行号和结束行号。",
				"parameters": {
					"type": "object",
					"properties": {
						"path": {
							"type": "string",
							"description": "需要读取的文件目录，必须是以res://开头的绝对路径。",
						},
						"start": {
							"type": "integer",
							"description": "需要读取的文件的开始行号，默认是1。",
						},
						"end": {
							"type": "integer",
							"description": "需要读取的文件的结束行号，默认是-1，表示读取到文件末尾。**注意**：返回时不会返回结束行号的内容。",
						}
					},
					"required": ["path", "start", "end"]
				}
			}
		},
		# create_folder
		{
			"type": "function",
			"function": {
				"name": "create_folder",
				"description": "创建文件夹。在给定的目录下创建一个指定称的空的文件夹。如果不给名称就叫新建文件夹，有重复的就后缀写上（数字）。**限制**：每次创建的文件夹应存在上级文件夹。",
				"parameters": {
					"type": "object",
					"properties": {
						"path": {
							"type": "string",
							"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
						}
					},
					"required": ["path"]
				}
			}
		},
		# write_file
		{
			"type": "function",
			"function": {
				"name": "write_file",
				#"description": "写入文件内容。文件格式应为资源文件(.tres)或者脚本文件(.gd)、Godot着色器(.gdshader)、场景文件(.tscn)、文本文件(.txt或.md)、CSV文件(.csv)，当明确提及创建或修改文件时再调用该工具",
				"description": "全量替换写入文件内容。文件格式应为资源文件(.tres)、Godot着色器(.gdshader)、文本文件(.txt或.md)、CSV文件(.csv)，当明确提及创建或修改文件时再调用该工具。**限制**：不应使用本工具修改脚本和场景文件。",
				"parameters": {
					"type": "object",
					"properties": {
						"path": {
							"type": "string",
							"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
						},
						"content": {
							"type": "string",
							"description": "需要写入的文件内容。以\n换行的字符串。"
						}
					},
					"required": ["path", "content"]
				}
			}
		},
#endregion
#region 场景操作
		# add_script_to_scene
		{
			"type": "function",
			"function": {
				"name": "add_script_to_scene",
				"description": "将一个脚本加载到节点上，如果需要为节点挂载脚本，应优先使用本工具",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": {
							"type": "string",
							"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
						},
						"script_path": {
							"type": "string",
							"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
						}
					},
					"required": ["scene_path","script_path"]
				}
			}
		},
		# sep_script_to_scene
		{
			"type": "function",
			"function": {
				"name": "sep_script_to_scene",
				"description": "将一个节点上的脚本分离，如果需要为节点分离脚本，应优先使用本工具",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": {
							"type": "string",
							"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
						},
					},
					"required": ["scene_path"]
				}
			}
		},
#endregion
#region 调试
		# check_script_error
		{
			"type": "function",
			"function": {
				"name": "check_script_error",
				"description": "使用Godot脚本引擎检查脚本中的语法错误，只能检查gd脚本。**依赖**：需要检查的脚本文件必须存在。",
				"parameters": {
					"type": "object",
					"properties": {
						"path": {
							"type": "string",
							"description": "需要检查的脚本路径，必须是以res://开头的绝对路径。",
						},
					},
					"required": ["name"]
				}
			}
		},
#endregion
#region 编辑器操作
		# open_resource
		{
			"type": "function",
			"function": {
				"name": "open_resource",
				"description": "使用Godot编辑器立刻打开或切换到对应资源，资源应是场景文件（.tscn）或脚本文件（.gd）。**依赖**：需要打开的场景或资源文件必须存在。",
				"parameters": {
					"type": "object",
					"properties": {
						"path": {
							"type": "string",
							"description": "需要打开的资源路径，必须是以res://开头的绝对路径。",
						},
						"type": {
							"type": "string",
							"enum": ["scene", "script"],
							"description": "打开的类型",
						},
						"line": {
							"type": "number",
							"description": "如果打开的是脚本，可以指定行号， 默认是-1",
						},
						"column": {
							"type": "number",
							"description": "如果打开的是脚本，可以指定列号，默认是0",
						},
					},
					"required": ["name", "type"]
				}
			}
		},
		# update_script_file_content
		{
			"type": "function",
			"function": {
				"name": "update_script_file_content",
				"description": "直接调用编辑器接口更新脚本文件的内容。根据行号和删除的行数量，在对应行删除若干行然后插入内容。如果不删除，则会在对应行**之前**添加内容。可以使用本工具添加、删除、替换文件中的行内容。文件内容是以转义字符回车换行的字符串。**注意**：尽量不要以全文的方式修改，而是指定最小需要修改的行号来修改内容。可以多次调用本工具。**限制**：代码修改后行号会发生变化，必须在调用后使用read_file读取修改结果。**依赖**：需要打开的脚本文件必须存在。",
				"parameters": {
					"type": "object",
					"properties": {
						"script_path": {
							"type": "string",
							"description": "需要打开的资源路径，必须是以res://开头的绝对路径。**依赖**：需要打开的脚本文件必须存在。",
						},
						"content": {
							"type": "string",
							"description": "需要写入的文件内容。多行内容应以转义字符回车分割，代码缩进应以转义制表符分割。**示例**：正确内容：\ttest line\n\ttest line 2，错误内容：\\ttest line\\n\\ttest line 2",
						},
						"line": {
							"type": "number",
							"description": "可以指定行号，从1开始，默认是1。",
						},
						"delete_line_count": {
							"type": "number",
							"description": "需要删除的行的数量，默认是0，为0表示不删除。",
						}
					},
					"required": ["script_path", "content", "line", "delete_line_count"]
				}
			}
		},
		# update_scene_node_property
		{
			"type": "function",
			"function": {
				"name": "update_scene_node_property",
				"description": "调用编辑器接口，设置某个场景内的某个节点的某个属性为某个值，可设置的值的类型参照Godot官方文档中Variant.Type枚举值对应类型。",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": {
							"type": "string",
							"description": "需要打开的场景路径，必须是以res://开头的路径。",
						},
						"node_path": {
							"type": "string",
							"description": "想修改的节点在场景树中的路径。从场景的根节点开始，用“/”分隔。",
						},
						"property_name": {
							"type": "string",
							"description": "想设置的属性的名称。",
						},
						"property_value": {
							"type": "string",
							"description": "想设置的属性的值，该字符串需要能用str_to_var方法还原对应Variant类型值",
						}
					},
					"required": ["scene_path", "node_path", "property_name", "property_value"]
				}
			}
		},
		# set_resource_property
		{
			"type": "function",
			"function": {
				"name": "set_resource_property",
				"description": "写入资源文件，并将其引用为某个场景内的某个节点的某个属性。",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": {
							"type": "string",
							"description": "需要打开的场景路径，必须是以res://开头的路径。",
						},
						"node_path": {
							"type": "string",
							"description": "想修改的节点在场景树中的路径。从场景的根节点开始，用“/”分隔。",
						},
						"property_path": {
							"type": "string",
							"description": "想设置的属性的路径，注意对于shader文件等可能会嵌套在其他资源内的属性，这个路径应该为material/shader，即格式为‘节点属性/资源属性/.../目标属性’",
						},
						"resource_path": {
							"type": "string",
							"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
						},
						"content": {
							"type": "string",
							"description": "需要写入的文件内容",
						}
					},
					"required": ["scene_path", "node_path", "property_path", "resource_path", "content"]
				}
			}
		},
#endregion
#region 配置
		# set_singleton
		{
			"type": "function",
			"function": {
				"name": "set_singleton",
				"description": "设置或删除项目自动加载脚本或场景",
				"parameters": {
					"type": "object",
					"properties": {
						"name": {
							"type": "string",
							"description": "需要设置的自动加载名称，需要以大驼峰的方式命名。一般可以和脚本或场景文件同名。**依赖**：设置的自动加载脚本或场景文件必须存在。且不能和已有的自动加载名称重复。",
						},
						"path": {
							"type": "string",
							"description": "需要设置为自动加载的脚本或场景路径，必须是以res://开头的绝对路径。如果为空时则会删除该自动加载。**依赖**：设置的自动加载脚本或场景文件必须存在。",
						},
					},
					"required": ["name"]
				}
			}
		},
#endregion

#region 命令行工具
		# execute_command
		{
			"type": "function",
			"function": {
				"name": "execute_command",
				"description": "创建一个独立于 Godot 运行的命令行工具，该工具运行在项目目录下。调用本工具需要提醒用户，以防止造成无法预料的后果。**限制**：需要预先知道当前的系统。windows中使用的是cmd命令。linux中使用的是bash命令。不要出现当前系统下没有的命令。",
				"parameters": {
					"type": "object",
					"properties": {
						"command": {
							"type": "string",
							"description": "需要执行的命令名称，不需要指定bash或者cmd，可以直接输入命令名称。",
						},
						"args": {
							"type": "array",
							"description": "需要执行的命令的参数，会按给定顺序执行。不需要/c或者-Command参数。",
						}
					},
					"required": ["command", "args"]
				}
			}
		},
#endregion
	]

# 使用工具
func use_tool(tool_call: AgentModelUtils.ToolCallsInfo) -> String:
	var result = {}
	match tool_call.function.name:
		"get_project_info":
			result = {
				"engine": {
					# 引擎信息
					"engine_version": Engine.get_version_info(),
				},
				"system": {
					# 系统以及硬件信息
					"cpu_info": OS.get_processor_name(),
					"architecture_name": Engine.get_architecture_name(),
					"memory_info": OS.get_memory_info(),
					"model_name": OS.get_model_name(),
					"platform_name": OS.get_name(),
					"system_version": OS.get_version(),
					"video_adapter_name": RenderingServer.get_video_adapter_name(),
					"video_adapter_driver": OS.get_video_adapter_driver_info(),
					"rendering_method": RenderingServer.get_current_rendering_method(),
					"system_time": Time.get_datetime_string_from_system()
				},
				"project": {
					"project_name": ProjectSettings.get_setting("application/config/name"),
					"project_version": ProjectSettings.get_setting("application/config/version"),
					"project_description": ProjectSettings.get_setting("application/config/description"),
					"main_scene": ProjectSettings.get_setting("application/run/main_scene"),
					"features": ProjectSettings.get_setting("config/features"),
					"project.godot": FileAccess.get_file_as_string("res://project.godot"),
					"window": {
						"viewport_width": ProjectSettings.get_setting("display/window/size/viewport_width"),
						"viewport_height": ProjectSettings.get_setting("display/window/size/viewport_height"),
						"mode": ProjectSettings.get_setting("display/window/size/mode"),
						"borderless": ProjectSettings.get_setting("display/window/size/borderless"),
						"always_on_top": ProjectSettings.get_setting("display/window/size/always_on_top"),
						"transparent": ProjectSettings.get_setting("display/window/size/transparent"),
						"window_width_override": ProjectSettings.get_setting("display/window/size/window_width_override"),
						"window_height_override": ProjectSettings.get_setting("display/window/size/window_height_override"),
						"embed_subwindows": ProjectSettings.get_setting("display/window/subwindows/embed_subwindows"),
						"per_pixel_transparency": ProjectSettings.get_setting("display/window/per_pixel_transparency/allowed"),
						"stretch_mode": ProjectSettings.get_setting("display/window/stretch/mode"),
					},
					"physics": {
						"physics_ticks_per_second": ProjectSettings.get_setting("physics/common/physics_ticks_per_second"),
						"physics_interpolation": ProjectSettings.get_setting("physics/common/physics_interpolation"),
					},
					"rendering": {
						"default_texture_filter": ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"),
					}
				}
			}
		"get_editor_info":
			var script_editor := EditorInterface.get_script_editor()
			var editor_file_list: ItemList = script_editor.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1)
			var selected := editor_file_list.get_selected_items()
			var item_count = editor_file_list.item_count
			var select_index = -1
			if selected:
				select_index = selected[0]
				#print(il.get_item_tooltip(index))
			var edit_file_list = []
			var current_opend_script = ""
			for index in item_count:
				var file_path = editor_file_list.get_item_tooltip(index)
				if file_path.begins_with("res://"):
					edit_file_list.push_back(file_path)
					if select_index == index:
						current_opend_script = file_path
			result = {
				"editor": {
					# 当前编辑器信息
					"opened_scenes": EditorInterface.get_open_scenes(),
					"current_edited_scene": EditorInterface.get_edited_scene_root().get_scene_file_path(),
					"current_scene_root_node": EditorInterface.get_edited_scene_root(),
					"current_opend_script": current_opend_script,
					"opend_scripts": edit_file_list
				},
			}
		"get_project_file_list":
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
			result = {
				"list": file_list
			}
		"read_file":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("path") and json.has("start") and json.has("end"):
				var path: String = json.path
				var start: int = json.get("start", 0)
				var end: int = json.get("end", -1)

				var file_string = FileAccess.get_file_as_string(path)
				if file_string == "":
					result = {
						"file_path": path,
						"file_uid": ResourceUID.path_to_uid(path),
						"file_content": "",
						"start": 1,
						"end": 1,
						"total_lines": 1,
						"open_error": error_string(FileAccess.get_open_error())
					}
				else:
					var file_lines = file_string.split("\n")
					var total_lines = file_lines.size()
					var start_line = max(1, start)
					start_line = min(start_line, total_lines)
					if end == -1:
						end = total_lines
					else:
						end = min(total_lines, end)
					end = min(total_lines + 1, end + 1, start_line + 501)

					var file_content = file_lines.slice(max(start_line - 1, 0), end)
					result = {
						"file_path": path,
						"file_uid": ResourceUID.path_to_uid(path),
						"file_content": file_content,
						"start": start_line,
						"end": end,
						"total_lines": total_lines
					}

		"create_folder":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("path"): # 如果有路径就执行
				var path = json.path
				var has_folder = DirAccess.dir_exists_absolute(path)
				if has_folder:
					result = {
						"error":"文件夹已存在，无需创建"
					}
				else:
					var error = DirAccess.make_dir_absolute(path)
					if error == OK:
						result = {
							"success":"文件创建成功"
						}
					else:
						result = {
							"error":"文件夹创建失败，%s" % error_string(error)
						}
				EditorInterface.get_resource_filesystem().scan()
		"get_class_doc":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("class_name"):
				var cname = json.get("class_name")
				if ClassDB.class_exists(cname):
					if json.has("signals"):
						var signals_array = json.get("signals")
						result = {
							"class_name": cname,
							"signals": signals_array.map(func (sig): return ClassDB.class_get_signal(cname, sig))
						}
					elif json.has("properties"):
						var properties_array = json.get("properties")
						result = {
							"class_name": cname,
							"properties": properties_array.map(func (prop): return {
								"default_value": ClassDB.class_get_property_default_value(cname, prop),
								"setter": ClassDB.class_get_property_setter(cname, prop),
								"getter": ClassDB.class_get_property_getter(cname, prop),
							})
						}
					elif json.has("enums"):
						var enums_array = json.get("enums")
						result = {
							"class_name": cname,
							"enums": enums_array.map(func (enum_name): return {
								"enum": enum_name,
								"values": ClassDB.class_get_enum_constants(cname, enum_name)
							})
						}
					else:
						result = {
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
				else:
					result = {
						"error": "%s 类不存在" % cname
					}
		"add_script_to_scene":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("scene_path") and json.has("script_path"):
				var scene_path = json.scene_path
				var script_path = json.script_path
				var has_scene_file = FileAccess.file_exists(scene_path)
				var has_script_file = FileAccess.file_exists(script_path)
				if has_scene_file and has_script_file:
					#var scene_file = FileAccess.open(scene_path, FileAccess.READ)
					#var script_file = FileAccess.open(script_path, FileAccess.READ)
					#var scene_node =
					var scene_file = ResourceLoader.load(scene_path)
					var root_node = scene_file.instantiate()
					var has_script = root_node.get_script()
					var script_file = ResourceLoader.load(script_path)
					var script = script_file.new()
					if has_script == null:
						if root_node is PackedScene and script is GDScript:
							scene_file.set_script(script_file)
							var scene_class = scene_file.get_class()
							var script_class = script_file.get_instance_base_type()
							var is_same_class:bool = false
							result = {
								"scene_class":scene_class,
								"script_class":script_class,
							}
							if scene_class == script_class:
								is_same_class = true
								result["success"] = "脚本加载成功"
							else:
								result["error"] = "场景节点类型与脚本继承类型不符"
						else:
							result["error"] = "文件非场景节点和脚本的关系"
					else:
						result = {
							"error":"该场景节点已挂载脚本"
						}
				else:
					if not has_scene_file:
						result = {
							"error":"场景文件不存在，询问是否需要新建该场景"
						}
					if not has_script_file:
						result = {
							"error":"脚本文件不存在，询问是否需要新建该脚本"
						}
				EditorInterface.get_resource_filesystem().scan()
		"sep_script_to_scene":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("scene_path"):
				var scene_path = json.scene_path
				var has_scene_file = FileAccess.file_exists(scene_path)
				if has_scene_file:
					var scene_file = ResourceLoader.load(scene_path)
					var root_node = scene_file.instantiate()
					var has_script = root_node.get_script()
					if has_script != null and root_node is PackedScene:
						scene_file.set_script(null)
					else:
						result = {
							"error":"场景文件并未挂在脚本"
						}
				else:
					if not has_scene_file:
						result = {
							"error":"场景文件不存在，询问是否需要新建该场景"
						}

				EditorInterface.get_resource_filesystem().scan()
		"write_file":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("path") and json.has("content"):
				var path: String = json.path
				var content = json.content
				# var is_new_file = not FileAccess.file_exists(path)
				#var file = FileAccess.open(path, FileAccess.WRITE)
				if write_file(path, content):

					if path.get_file().get_extension() == "tscn":
						EditorInterface.reload_scene_from_path(path)

					result = {
						"file_path": path,
						"file_uid": ResourceUID.path_to_uid(path),
						"file_content": FileAccess.get_file_as_string(path),
						"open_error": error_string(FileAccess.get_open_error())
					}
				else:
					result = {
						"open_error": error_string(FileAccess.get_open_error())
					}
		"get_image_info":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("image_path"):
				var image_path := json.image_path as String
				var texture := load(image_path) as Texture2D
				var image = texture.get_image() as Image
				result = {
					"uid": ResourceUID.path_to_uid(image_path),
					"image_path": image_path,
					"image_file_type": image_path.get_extension(),
					"image_width": image.get_width(),
					"image_height": image.get_height(),
					"image_format": image.get_format(),
					"image_format_name": image.data.format,
					"data_size": image.get_data_size()
				}
		"get_tileset_info":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("scene_path") and json.has("tile_map_path"):
				var node = get_target_node(json.scene_path, json.tile_map_path)
				if node:
					result = get_tileset_info(node.tile_set)
				else:
					result = {
						"error": "没有找到对应TileMapLayer节点"
					}

		"set_singleton":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("name"):
				var singleton_name = json.name
				var singleton_path = json.get("path", "")
				if singleton_path:
					var singleton = AlphaAgentSingleton.get_instance()
					singleton.add_autoload_singleton(singleton_name, singleton_path)
					result = {
						"name": singleton_name,
						"path": singleton_path,
						"success": "添加自动加载成功"
					}
				else:
					var singleton = AlphaAgentSingleton.get_instance()
					singleton.remove_autoload_singleton(singleton_name)
					result = {
						"name": singleton_name,
						"success": "删除自动加载成功"
					}
		"check_script_error":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("path"):
				var log_file_path = AlphaAgentPlugin.project_alpha_dir + "check_script.temp"
				var path = json.path
				if FileAccess.file_exists(log_file_path):
					DirAccess.remove_absolute(log_file_path)

				var instance_pid = OS.create_instance(["--head-less", "--script", path, "--check-only", "--log-file", log_file_path])

				await get_tree().create_timer(3.0).timeout
				OS.kill(instance_pid)

				var script_check_result = FileAccess.get_file_as_string(log_file_path)

				DirAccess.remove_absolute(log_file_path)
				result = {
					"script_path": path,
					"script_check_result": script_check_result
				}
		"open_resource":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("path") and json.has("type"):
				var path = json.path
				var type = json.type
				match type:
					"scene":
						EditorInterface.open_scene_from_path(path)
						result = {
							"success": "打开成功"
						}
					"script":
						var resource = load(path)
						var line = json.get('line', -1)
						var column = json.get('column', 0)
						EditorInterface.edit_script(resource, line, column)
						result = {
							"success": "打开成功"
						}
					_:
						result = {
							"error": "错误的type类型"
						}
		"update_script_file_content":
			var json = JSON.parse_string(tool_call.function.arguments)

			if not json == null and json.has("script_path") and json.has("content") and json.has("line") and json.has("delete_line_count"):
				var script_path = json.script_path
				var content := json.content as String
				var line := json.line as int
				var delete_line_count = json.delete_line_count
				var resource: Script = load(script_path)

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

				result = {
					#"file_content": editor.text,
					"success": "更新成功，使用read_file工具查看结果。"
				}
		"update_scene_node_property":
			var json = JSON.parse_string(tool_call.function.arguments)

			if not json == null and json.has("scene_path") and json.has("node_path") and json.has("property_name") and json.has("property_value"):
				if update_scene_node_property(json.scene_path, json.node_path, json.property_name, json.property_value):
					result = {
					"success": "属性更新成功"
					}
				else:
					result = {
					"error":"操作失败"
					}
		"set_resource_property":
			var json = JSON.parse_string(tool_call.function.arguments)

			if not json == null and json.has("scene_path") and json.has("node_path") and json.has("property_path") and json.has("resource_path") and json.has("content"):
				if write_file(json.resource_path, json.content):
					if set_resource_property(json.resource_path, json.scene_path, json.node_path, json.property_path):
						result = {
						"success": "更新成功"
						}
					else:
						result = {
						"error": "资源挂载失败"
						}
				else:
					result = {
					"error": "资源写入失败"
					}

		"execute_command":
			var json = JSON.parse_string(tool_call.function.arguments)

			if not json == null and json.has("command") and json.has("args"):
				var is_timeout: bool = false
				thread = Thread.new()
				thread.start(execute_command.bind(json.command, json.args))
				while not thread.is_started():
					# 等待线程启动
					await get_tree().process_frame

				get_tree().create_timer(30.0).timeout.connect(func():
					#print("计时结束")
					#print(thread)
					if thread and thread.is_alive():
						is_timeout = true
						thread = Thread.new()
					)
				while thread.is_alive():
					# 等待线程结束
					#print("thread alive")
					await get_tree().process_frame
				#print(is_timeout)
				if is_timeout or !thread.is_started():
					result = {
							"error": "命令行执行因超时停止"
						}
					#thread.free()
					thread = null
				else:
					# 获取结果并释放线程
					var command_result = thread.wait_to_finish()
					# 清除数据，防止内存泄漏
					thread = null
					# print("command_result: ", command_result)

					result = command_result

		#本工具目前具有较大不确定性，暂不提供调用
		"editor_script_feature":
			var json = JSON.parse_string(tool_call.function.arguments)

			if not json == null and json.has("path") and json.has("content"):
				if write_file(json.path, json.content):
					if run_editor_script(json.path):
						result = {
							"success": "已运行EditorScript:" + json.path
						}
					else:
						result = {
							"error": "运行EditorScript失败:" + json.path
						}
				else:
					result = {
							"error": "创建脚本失败:" + json.path
						}

		"update_plan_list":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("tasks"):
				var tasks = json.get("tasks")
				var list: Array[AlphaAgentSingleton.PlanItem] = []
				var active_index = -1
				var all_finished = true
				var all_plan = true
				for index in tasks.size():
					var task: Dictionary = tasks[index]
					var task_name = task.get("name", "")
					var task_state = task.get("state", "plan")
					var plan_state: AlphaAgentSingleton.PlanState
					match task_state:
						"plan":
							plan_state = AlphaAgentSingleton.PlanState.Plan
							all_finished = false
						"active":
							plan_state = AlphaAgentSingleton.PlanState.Active
							all_finished = false
							active_index = index
							all_plan = false
						"finish":
							plan_state = AlphaAgentSingleton.PlanState.Finish
							all_plan = false
					list.push_back(AlphaAgentSingleton.PlanItem.new(task_name, plan_state))
				var singleton = AlphaAgentSingleton.get_instance()
				singleton.update_plan_list.emit(list)
				if active_index == 0:
					result = {
						"success": "更新任务列表成功。开始执行当前任务。"
					}
				elif all_finished:
					result = {
						"success": "更新任务列表成功。所有任务均已完成，回复用户。"
					}
				elif all_plan:
					result = {
						"success": "更新任务列表成功。开始执行第一项任务。"
					}
				else:
					result = {
						"success": "更新任务列表成功。停止输出，等待用户确认。"
					}
		_:
			result = {
				"error": "错误的function.name"
			}
	if result == {}:
		result = {
			"error": "调用失败。请检查参数是否正确。"
		}
	return JSON.stringify(result)

#写入文件
func write_file(path: String, content: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file == null:
		file.store_string(content)
		file.close()

		EditorInterface.get_resource_filesystem().update_file(path)

		EditorInterface.get_script_editor().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		return true
	else:
		return false

#设置某个场景中的某个节点的某个属性为某个值
func update_scene_node_property(scene_path: String, node_path: String, property_name: String, property_value: String) -> bool:
	var target_node = get_target_node(scene_path, node_path)
	if not target_node:
		printerr("错误，未能找到"+scene_path+"内的目标节点"+node_path)
		return false

	print("正在设置属性 '", property_name, "' 的值为 '", property_value, "'...")

	# 检查属性是否存在
	if not property_name in target_node:
		printerr("错误：节点 '", target_node.name, "' 没有名为 '", property_name, "' 的属性。")
		return false

	target_node.set(property_name, str_to_var(property_value))

	# 通知编辑器属性已更改，以便更新UI（如检查器）
	EditorInterface.edit_node(target_node)

	return true

#设置节点某个需要资源的属性（包括嵌套在资源内）
func set_resource_property(resource_path: String, scene_path: String, node_path: String, property_name: String) -> bool:
	# 加载资源文件
	var resource = load(resource_path)
	if resource == null:
		print("错误: 无法加载资源文件: ", resource_path)
		return false

	# 加载场景
	var opened_scene = ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	if not opened_scene:
		printerr("错误：无法打开场景 '", scene_path, "'。请检查路径是否正确。")
		return false# 如果场景打开失败，则终止脚本
	else:
		EditorInterface.open_scene_from_path(scene_path)

	# 获取场景的根节点
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		print("错误：场景打开后，无法获取其根节点。")
		return false

	# 获取目标节点
	var target_node = scene_root.get_node(node_path)
	if target_node == null:
		print("错误: 在场景中找不到节点路径: ", node_path)
		return false

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(target_node)

	var array := property_name.split("/")
	if set_res(target_node, array, resource):
		# 刷新编辑器以显示更改
		EditorInterface.edit_node(target_node)

		print("成功在编辑器中将资源挂载到节点属性")
		return true
	else:
		return false

#通过递归尝试查找属性并设置
func set_res(target: Object, property_target: Array[String], res: Resource):
	if property_target.size() > 1:
		var property = property_target.pop_front()
		if property in target:
			return set_res(target.get(property), property_target, res)
		else:
			printerr("路径存在问题")
			return false
	else:
		if property_target[0] in target:
			target.set(property_target[0], res)
			return true
		else:
			printerr("未找到属性", property_target[0])
			return false

#命令行调用工具
func execute_command(command: String, args: Array = []) -> Dictionary:
	var result = {
		"success": false,
		"output": []
	}

	# 获取项目目录
	var working_dir = ProjectSettings.globalize_path("res://")

	# 在Linux/Mac上使用bash，Windows上使用cmd
	var shell = "bash" if OS.get_name() != "Windows" else "cmd"
	var shell_args = []

	if OS.get_name() != "Windows":
		 # 使用bash，先切换目录，然后执行命令
		var full_command = "cd '" + working_dir + "' && " + command + " " + " ".join(args)
		shell_args = ["-c", full_command]
	else:
		# 使用cmd，先切换目录，然后执行命令
		var full_command = "cd /d \"" + working_dir + "\" && " + command + " " + " ".join(args)
		shell_args = ["/c", full_command]

	# 执行命令
	var error_code = OS.execute(shell, shell_args, result.output, true, false)

	if error_code == -1:
		result.error = "命令执行失败"
		return result
	else:
		result.output = result.output
		result.success = true

		return result

#运行EditorScript
func run_editor_script(script_path: String) -> bool:
	# 加载脚本资源
	var script = load(script_path) as Script
	# 检查脚本是否成功加载
	if not script:
		push_error("无法加载脚本: " + script_path)
		return false
	# 创建脚本实例
	var script_instance = script.new()

	# 检查实例是否成功创建
	if not script_instance:
		push_error("无法创建脚本实例: " + script_path)
		return false

	#检查是否EditorScript
	if not script_instance is EditorScript:
		printerr("脚本非EditorScript：" + script_path)
		return false

	# 如果脚本有_run方法，则调用它
	if script_instance.has_method("_run"):
		script_instance._run()
		return true
	else:
		push_error("脚本没有_run方法: " + script_path)
		return false

#获取TileSet数据工具
func get_tileset_info(tileset: TileSet) -> Dictionary:

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

# 将 TileData 转换为字典的核心函数
func tile_data_to_dict(tile_data: TileData, tileset: TileSet, source_texture: Texture2D = null) -> Dictionary:
	var dict := {}
	var physics_layers_count = tileset.get_physics_layers_count()
	var navigation_layers_count = tileset.get_navigation_layers_count()
	var custom_data_layers_count = tileset.get_custom_data_layers_count()
	var occlusion_layers_count = tileset.get_occlusion_layers_count()

	# 1. 基础属性
	dict["flip_h"] = tile_data.flip_h
	dict["flip_v"] = tile_data.flip_v
	dict["transpose"] = tile_data.transpose
	dict["z_index"] = tile_data.get_z_index()
	dict["y_sort_origin"] = tile_data.get_y_sort_origin()
	dict["material"] = str(tile_data.material.resource_path) if tile_data.material else ""

	# 2. 纹理相关
	dict["texture_origin"] = tile_data.texture_origin

	# 3. 颜色
	dict["modulate"] = var_to_str(tile_data.get_modulate())

	# 4. 物理层（碰撞形状）
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

	# 5. 导航层
	var navigation_layers := []
	for layer_index in navigation_layers_count:
		navigation_layers.append(tile_data.get_navigation_polygon(layer_index))
	dict["navigation_layers"] = navigation_layers

	# 6. 自定义数据层
	var custom_data := {}
	for layer_index in custom_data_layers_count:
		var layer_name = tileset.get_custom_data_layer_name(layer_index)
		custom_data[layer_name] = tile_data.get_custom_data(layer_name)
	dict["custom_data"] = custom_data

	# 7. 地形与翻转
	dict["terrain_set"] = tile_data.terrain_set
	dict["terrain"] = tile_data.terrain
	dict["probability"] = tile_data.probability

	# 8. 备用属性（备用贴图）
	dict["alternative_tile"] = tile_data.alternative_tile if "alternative_tile" in tile_data else -1

	# 9. 光照遮挡
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

#获取目标节点
func get_target_node(scene_path: String, node_path: String) -> Node:
	if not ResourceLoader.exists(scene_path):
		return null

	var opened_scene = ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	if not opened_scene:
		printerr("错误：无法打开场景 '", scene_path, "'。请检查路径是否正确。")
		return null# 如果场景打开失败，则终止脚本
	else:
		EditorInterface.open_scene_from_path(scene_path)

	var instance = opened_scene.instantiate()
	if instance is Node2D:
		print("这是一个2D场景")
		EditorInterface.set_main_screen_editor("2D")
	elif instance is Node3D:
		print("这是一个3D场景")
		EditorInterface.set_main_screen_editor("3D")
	else:
		print("该场景非2D也非3D")
		EditorInterface.set_main_screen_editor("2D")
	instance.call_deferred("queue_free")

	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		printerr("错误：场景打开后，无法获取其根节点。")
		return null

	# 3. 根据节点路径查找并选中目标节点
	var target_node = scene_root.get_node(node_path)
	if not target_node:
		printerr("错误：在场景 '", scene_root.name, "' 中找不到路径为 '", node_path, "' 的节点。请检查节点路径是否正确。")
		return null

	print("成功找到节点: ", target_node)

	# 选中节点，这会自动在检查器中显示它
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(target_node)

	return target_node

func _exit_tree():
	if thread != null:
		thread.wait_to_finish()
		thread = null

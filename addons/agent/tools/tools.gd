@tool
extends Node

@export_tool_button("测试") var test_action = test

func test():
	var tool = DeepSeekChatStream.ToolCallsInfo.new()
	tool.function.name = "update_script_file_content"
	tool.function.arguments = JSON.stringify({"script_path": "res://game.gd", "content": "# test_text", "line": 0, "delete_line_count": 0})
	#var image = load("res://icon.svg")
	print(await use_tool(tool))
	#print(ProjectSettings.get_setting("input"))
	#var process_id = OS.create_instance(["--headless", "--script", "res://game.gd"])
	pass



func get_tools_list() -> Array[Dictionary]:
	return [
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
				"description": "获取当前项目中所有文件以及其UID列表。尽量不要使用全量读取目录",
				"parameters": {
					"type": "object",
					"properties": {
						"start_path": {
							"type": "string",
							"description": "可以指定读取的目录，必须是以res://开头的绝对路径。只会返回这个目录下的文件和目录",
						},
						"interation": {
							"type": "number",
							"description": "迭代的次数，只有start_path参数有值时才会生效。如果返回1，就只会查询一层文件。默认为-1，查询全部层级",
						}
					},
					"required": []
				}
			}
		},
		# read_file
		{
			"type": "function",
			"function": {
				"name": "read_file",
				"description": "读取文件内容。",
				"parameters": {
					"type": "object",
					"properties": {
						"path": {
							"type": "string",
							"description": "需要读取的文件目录，必须是以res://开头的绝对路径。",
						}
					},
					"required": ["path"]
				}
			}
		},

		# create_folder
		{
			"type": "function",
			"function": {
				"name": "create_folder",
				"description": "创建文件夹。在给定的目录下创建一个指定称的空的文件夹。如果不给名称就叫新建文件夹，有重复的就后缀写上（数字），每次创建的文件夹应存在上级。",
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
		# get_class_doc
		{
			"type": "function",
			"function": {
				"name": "get_class_doc",
				"description": "获得Godot原生的类的文档，文档中包含这个类的属性、方法以及参数和返回值、信号、枚举常量、父类、派生类等信息。直接查询为请求信息的列表。可以单独查询某些数据。",
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
		# write_file
		{
			"type": "function",
			"function": {
				"name": "write_file",
				#"description": "写入文件内容。文件格式应为资源文件(.tres)或者脚本文件(.gd)、Godot着色器(.gdshader)、场景文件(.tscn)、文本文件(.txt或.md)、CSV文件(.csv)，当明确提及创建或修改文件时再调用该工具",
				"description": "全量替换写入文件内容。文件格式应为资源文件(.tres)、Godot着色器(.gdshader)、文本文件(.txt或.md)、CSV文件(.csv)，当明确提及创建或修改文件时再调用该工具。不应使用本工具处理脚本和场景文件。",
				"parameters": {
					"type": "object",
					"properties": {
						"path": {
							"type": "string",
							"description": "需要写入的文件目录，必须是以res://开头的绝对路径。",
						},
						"content": {
							"type": "string",
							"description": "需要写入的文件内容。"
						}
					},
					"required": ["path", "content"]
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
							"description": "需要设置的自动加载名称，需要以大驼峰的方式命名。一般可以和脚本或场景文件同名。",
						},
						"path": {
							"type": "string",
							"description": "需要设置为自动加载的脚本或场景路径，必须是以res://开头的绝对路径。如果为空时则会删除该自动加载",
						},
					},
					"required": ["name"]
				}
			}
		},
		# check_script_error
		{
			"type": "function",
			"function": {
				"name": "check_script_error",
				"description": "使用Godot脚本引擎检查脚本中的语法错误，只能检查gd脚本。",
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
		# open_resource
		{
			"type": "function",
			"function": {
				"name": "open_resource",
				"description": "使用Godot编辑器立刻打开或切换到对应资源，资源应是场景文件（.tscn）或脚本文件（.gd）。",
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
				"description": "直接调用编辑器接口更新脚本文件的内容。根据行号和删除的行数量，在对应位置删除若干行后插入内容。如果不删除，则会在对应行之前添加一行内容。可以使用本工具添加、删除、替换文件中的行内容。文件内容是以\n换行的字符串。",
				"parameters": {
					"type": "object",
					"properties": {
						"script_path": {
							"type": "string",
							"description": "需要打开的资源路径，必须是以res://开头的绝对路径。",
						},
						"content": {
							"type": "string",
							"description": "需要写入的文件内容。",
						},
						"line": {
							"type": "number",
							"description": "可以指定行号， 默认是0。",
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
	]


func use_tool(tool_call: DeepSeekChatStream.ToolCallsInfo):
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

			var ignore_files = [".godot", "*.uid", "addons"]
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
							#print(reg, file_name)
							#print(file_name.match(reg))
							match_result = match_result and (not file_name.match(reg))
						if match_result:
							if dir.current_is_dir():
								#print("发现目录：" + current_dir + file_name + '/')
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
								#print("发现文件" + current_dir + file_name)
						file_name = dir.get_next()
				else:
					print("尝试访问路径时出错。")
			result = {
				"list": file_list
			}
		"read_file":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("path"):
				var path: String = json.path
				var file_string = FileAccess.get_file_as_string(path)
				if file_string == "":
					result = {
						"file_path": path,
						"file_uid": ResourceUID.path_to_uid(path),
						"file_content": "",
						"open_error": FileAccess.get_open_error()
					}
				else:
					result = {
						"file_path": path,
						"file_uid": ResourceUID.path_to_uid(path),
						"file_content": file_string
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
				var file = FileAccess.open(path, FileAccess.WRITE)
				if not file == null:
					file.store_string(content)
					file.close()

					EditorInterface.get_resource_filesystem().update_file(path)

					EditorInterface.get_script_editor().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

					if path.get_file().get_extension() == "tscn":
						EditorInterface.reload_scene_from_path(path)

					result = {
						"file_path": path,
						"file_uid": ResourceUID.path_to_uid(path),
						"file_content": FileAccess.get_file_as_string(path),
						"open_error": FileAccess.get_open_error()
					}
				else:
					result = {
						"open_error": FileAccess.get_open_error()
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

		"set_singleton":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("name"):
				var singleton_name = json.name
				var singleton_path = json.get("path", "")
				if singleton_path:
					AlphaAgentPlugin.instance.add_autoload_singleton(singleton_name, singleton_path)
					result = {
						"name": singleton_name,
						"path": singleton_path,
						"success": "添加自动加载成功"
					}
				else:
					AlphaAgentPlugin.instance.remove_autoload_singleton(singleton_name)
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
				var content = json.content
				var line = json.line
				var delete_line_count = json.delete_line_count
				var resource: Script = load(script_path)

				EditorInterface.set_main_screen_editor("Script")
				EditorInterface.edit_script(resource)

				var editor: CodeEdit = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
				for i in delete_line_count:
					editor.remove_line_at(line)
				editor.insert_line_at(line, content)

				await get_tree().process_frame
				var save_input_key := InputEventKey.new()
				save_input_key.pressed = true
				save_input_key.keycode = KEY_S
				save_input_key.alt_pressed = true
				save_input_key.command_or_control_autoremap = true

				EditorInterface.get_base_control().get_viewport().push_input(save_input_key)

				result = {
					"file_content": editor.text,
					"success": "更新成功"
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

@tool
extends Node

@export_tool_button("测试") var test_action = test

func test():

	var tool = DeepSeekChatStream.ToolCallsInfo.new()
	tool.function.name = "write_file"
	tool.function.arguments = JSON.stringify({"path": "res://create_test.md", "content": """extends Node"""
	})


	print(use_tool(tool))


func get_tools_list() -> Array[Dictionary]:
	return [
		# get_project_info
		{
			"type": "function",
			"function": {
				"name": "get_project_info",
				"description": "获取当前的Godot引擎信息。包含Godot版本，CPU型号、CPU 架构、内存信息、显卡信息、设备型号、当前系统时间等，还有当前项目的一些信息，例如项目名称、项目版本、项目描述、项目运行主场景、游戏运行窗口信息、全局的物理信息、全局的渲染设置、主题信息等。",
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
				"description": "获取当前项目中所有文件以及其UID列表。",
				"parameters": {
					"type": "object",
					"properties": {},
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
		# write_file
		{
			"type": "function",
			"function": {
				"name": "write_file",
				"description": "写入文件内容。文件格式应为资源文件(.tres)或者脚本文件(.gd)、Godot着色器(.gdshader)、场景文件(.tscn)、文本文件(.txt或.md)、CSV文件(.csv)",
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
			var start_dir = "res://"
			var ignore_files = [".godot", "*.uid", "addons"]
			var queue = [start_dir]
			var file_list = []
			while queue.size():
				var current_dir = queue.pop_front()
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
								queue.push_back(current_dir + file_name + '/')
							else:
								file_list.push_back(current_dir + file_name)
								#print("发现文件" + current_dir + file_name)
						file_name = dir.get_next()
				else:
					print("尝试访问路径时出错。")
			result = {
				"list": file_list.map(func (file_path: String): return {
					"path": file_path,
					"uid": ResourceUID.path_to_uid(file_path)
				})
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
		"write_file":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("path") and json.has("content"):
				var path = json.path
				var content = json.content
				# var is_new_file = not FileAccess.file_exists(path)
				var file = FileAccess.open(path, FileAccess.WRITE)
				if not file == null:
					file.store_string(content)
					file.close()
					
					EditorInterface.get_resource_filesystem().update_file(path)

					EditorInterface.get_script_editor().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

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


		_:
			result = {
				"error": "错误的function.name"
			}
	return JSON.stringify(result)

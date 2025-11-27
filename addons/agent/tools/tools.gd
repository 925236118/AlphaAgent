@tool
extends Node

@export_tool_button("测试") var test_action = test

func test():
	var tool = DeepSeekChatStream.ToolCallsInfo.new()
	tool.function.name = "read_file"
	tool.function.arguments = JSON.stringify({"path": "res://addons/agent/tools/tools.tscn"})
	print(use_tool(tool))

func get_tools_list() -> Array[Dictionary]:
	return [
		{
			"type": "function",
			"function": {
				"name": "get_engine_info",
				"description": "获取当前的Godot引擎信息。包含Godot版本，CPU型号、CPU 架构、内存信息、显卡信息、设备型号等，也可以获取当前编辑器打开的场景信息和编辑器中打开和编辑的脚本相关信息。",
				"parameters": {
					"type": "object",
					"properties": {},
					"required": []
				}
			}
		},
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
	]


func use_tool(tool_call: DeepSeekChatStream.ToolCallsInfo):
	var result = {}
	match tool_call.function.name:
		"get_engine_info":
			result = {
				# 引擎信息
				"engine_version": Engine.get_version_info(),
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
				# 当前编辑器信息
				"opened_scenes": EditorInterface.get_open_scenes(),
				"current_scene_root_node": EditorInterface.get_edited_scene_root(),
				"current_opend_script": EditorInterface.get_script_editor().get_current_script().resource_path,
				"opend_scripts": EditorInterface.get_script_editor().get_open_scripts().map(func (script: Script): return script.resource_path)
			}

		"read_file":
			var json = JSON.parse_string(tool_call.function.arguments)
			if not json == null and json.has("path"):
				var path: String = json.path
				var file_string = FileAccess.get_file_as_string(path)

				result = {
					"file_path": path,
					"file_uid": ResourceUID.path_to_uid(path),
					"file_content": file_string
				}
		_:
			result = {
				"error": "错误的function.name"
			}
	return JSON.stringify(result)

@tool
class_name GetProjectInfoTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "get_project_info"

func _get_tool_short_description() -> String:
	return "获取当前的引擎信息和项目配置信息。"

func _get_tool_description() -> String:
	return "获取当前的Godot引擎信息。包含Godot版本，CPU型号、CPU 架构、内存信息、显卡信息、设备型号、当前系统时间等，还有当前项目的一些信息，例如项目名称、项目版本、项目描述、项目运行主场景、游戏运行窗口信息、全局的物理信息、全局的渲染设置、主题信息等。还有自动加载和输入映射，需要从project.godot中读取。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {},
		"required": []
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	return {
		"engine": {
			"engine_version": Engine.get_version_info(),
		},
		"system": {
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

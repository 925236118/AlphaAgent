@tool
extends Node

# 可调用的tools
@onready var tools: AgentTools = $Tools

@export_group("读工具", "read_")
@export_tool_button("测试 update_plan_list") var read_test_update_plan_list_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "update_plan_list"
	tool.function.arguments = JSON.stringify({"tasks": [{"name": "测试任务1", "state": "finished"}, {"name": "测试任务2", "state": "finished"}, {"name": "测试任务3", "state": "finished"}, {"name": "测试任务4", "state": "finished"}]}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_project_info") var read_test_get_project_info_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_project_info"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_editor_info") var read_test_get_editor_info_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_editor_info"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_project_file_list") var read_test_get_project_file_list_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_project_file_list"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_class_doc") var read_test_get_class_doc_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_class_doc"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_image_info") var read_test_get_image_info_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_image_info"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_tileset_info") var read_test_get_tileset_info_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_tileset_info"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 read_file") var read_test_read_file_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "read_file"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 global_search") var read_test_global_search_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "global_search"
	tool.function.arguments = JSON.stringify({"text": "vertex"}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 check_script_error") var read_test_check_script_error_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "check_script_error"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 open_resource") var read_test_open_resource_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "open_resource"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 resource_inspector") var resource_inspector_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "resource_inspector"
	tool.function.arguments = JSON.stringify({"resource_path": "res://test/color_change.gdshader"}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_group("写工具", "write_")
@export_tool_button("测试 create_folder") var write_test_create_folder_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "create_folder"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 write_file") var write_test_write_file_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "write_file"
	tool.function.arguments = JSON.stringify({
	"content": "extends CharacterBody2D\n\n# 玩家控制参数\n@export var move_speed: float = 300.0  # 移动速度（像素/秒）\n@export var jump_velocity: float = -400.0  # 跳跃速度（向上为负）\n@export var gravity: float = 980.0  # 重力（像素/秒²）\n\nfunc _physics_process(delta: float) -> void:\n\t# 应用重力（如果没有在地面上）\n\tif not is_on_floor():\n\t\tvelocity.y += gravity * delta\n\t\n\t# 处理水平移动输入\n\tvar horizontal_input: float = Input.get_axis(\"ui_left\", \"ui_right\")\n\tvelocity.x = horizontal_input * move_speed\n\t\n\t# 处理跳跃输入（只有在地面上才能跳跃）\n\tif Input.is_action_just_pressed(\"ui_select\") and is_on_floor():\n\t\tvelocity.y = jump_velocity\n\t\n\t# 应用移动\n\tmove_and_slide()",
	"path": "res://scripts/player.gd"
}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 create_script") var write_test_create_script_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "create_script"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 add_script_to_scene") var write_test_add_script_to_scene_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "add_script_to_scene"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 sep_script_to_scene") var write_test_sep_script_to_scene_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "sep_script_to_scene"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 add_node_to_scene") var write_test_add_node_to_scene_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "add_node_to_scene"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 update_script_file_content") var write_test_update_script_file_content_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "update_script_file_content"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 update_scene_node_property") var write_test_update_scene_node_property_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "update_scene_node_property"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 set_resource_property") var write_test_set_resource_property_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "set_resource_property"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 set_singleton") var write_test_set_singleton_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "set_singleton"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 execute_command") var write_test_execute_command_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "execute_command"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@tool
extends Node

# 可调用的tools
@onready var tools: AgentTools = $Tools

@export_tool_button("测试 update_plan_list") var test_update_plan_list_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "update_plan_list"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_project_info") var test_get_project_info_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_project_info"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_editor_info") var test_get_editor_info_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_editor_info"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_project_file_list") var test_get_project_file_list_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_project_file_list"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_class_doc") var test_get_class_doc_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_class_doc"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_image_info") var test_get_image_info_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_image_info"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 get_tileset_info") var test_get_tileset_info_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "get_tileset_info"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 read_file") var test_read_file_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "read_file"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 global_search") var test_global_search_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "global_search"
	tool.function.arguments = JSON.stringify({"text": "global_search"}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 create_folder") var test_create_folder_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "create_folder"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 write_file") var test_write_file_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "write_file"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 create_script") var test_create_script_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "create_script"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 add_script_to_scene") var test_add_script_to_scene_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "add_script_to_scene"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 sep_script_to_scene") var test_sep_script_to_scene_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "sep_script_to_scene"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 add_node_to_scene") var test_add_node_to_scene_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "add_node_to_scene"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 check_script_error") var test_check_script_error_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "check_script_error"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 open_resource") var test_open_resource_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "open_resource"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 update_script_file_content") var test_update_script_file_content_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "update_script_file_content"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 update_scene_node_property") var test_update_scene_node_property_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "update_scene_node_property"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 set_resource_property") var test_set_resource_property_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "set_resource_property"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 set_singleton") var test_set_singleton_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "set_singleton"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

@export_tool_button("测试 execute_command") var test_execute_command_action = func():
	var tool = AgentModelUtils.ToolCallsInfo.new()
	tool.function.name = "execute_command"
	tool.function.arguments = JSON.stringify({}) # 填写测试参数
	print(await tools.use_tool(tool))

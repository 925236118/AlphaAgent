@tool
class_name GetTilesetInfoTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "get_tileset_info"

func _get_tool_short_description() -> String:
	return "获取TileSet信息。"

func _get_tool_description() -> String:
	return "获取TileSet的所有信息，包括纹理原点、调色、Z索引、Y排序原点、地形、概率、物理、导航、自定义数据和光照遮挡等。"

func _get_tool_parameters() -> Dictionary:
	return {
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

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("scene_path") and json.has("tile_map_path"):
		var node = AgentToolUtils.get_target_node(json.scene_path, json.tile_map_path)
		if node:
			return AgentToolUtils.get_tileset_info(node.tile_set)
		return {
			"error": "没有找到对应TileMapLayer节点"
		}

	return {
		"error": "调用失败。请检查参数是否正确。"
	}

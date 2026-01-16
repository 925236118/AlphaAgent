@tool
class_name GetImageInfoTool
extends AgentToolBase

func _get_tool_name() -> String:
	return "get_image_info"

func _get_tool_short_description() -> String:
	return "获取图片文件信息。"

func _get_tool_description() -> String:
	return "获取图片文件信息，可以获得图片的格式、大小、uid等信息"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"image_path": {
				"type": "string",
				"description": "需要读取的图片文件目录，必须是以res://开头的绝对路径。",
			},
		},
		"required": ["image_path"]
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("image_path"):
		var image_path := json.image_path as String
		var texture := load(image_path) as Texture2D
		var image = texture.get_image() as Image
		return {
			"uid": ResourceUID.path_to_uid(image_path),
			"image_path": image_path,
			"image_file_type": image_path.get_extension(),
			"image_width": image.get_width(),
			"image_height": image.get_height(),
			"image_format": image.get_format(),
			"image_format_name": image.data.format,
			"data_size": image.get_data_size()
		}

	return {
		"error": "调用失败。请检查参数是否正确。"
	}

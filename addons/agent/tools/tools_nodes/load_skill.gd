@tool
class_name LoadSkillTool
extends AgentToolBase


func _get_tool_name() -> String:
	return "load_skill"

func _get_tool_short_description() -> String:
	return "加载技能。"

func _get_tool_description() -> String:
	return "为AI添加技能，技能是指导你完成某件事情的一系列方法。你需要调用本工具获得某项技能的内容。例如，当你想知道如何编写godot脚本时，你可以加载`godot-gdscript-patterns`技能，它会告诉你在遇到一些常见功能时，应如何编写对应的脚本。"

func _get_tool_parameters() -> Dictionary:
	var skill_names = AlphaAgentPlugin.global_setting.skill_manager.get_skill_names()
	return {
		"type": "object",
		"properties": {
			"skill_name": {
				"type": "string",
				"enum": skill_names,
				"description": "需要加载的技能名称，不能为空。",
			},
		},
		"required": ["skill_name"]
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("skill_name"):
		var skill_name = json.skill_name
		var skill := AlphaAgentPlugin.global_setting.skill_manager.get_skill(skill_name) as AgentSkillResource
		if skill:
			return {
				"result": skill.get_skill_markdown()
			}
		else:
			return {
				"error": "技能不存在"
			}
	return {
		"error": "调用失败。请检查参数是否正确。"
	}

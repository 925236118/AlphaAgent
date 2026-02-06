@tool
class_name AgentSkillResource
extends Resource

# 技能名称
@export var skill_name: String = ""
# 技能描述
@export var skill_description: String = ""
# 技能内容
@export_multiline var skill_content: String = ""

# 获取技能的markdown格式内容
func get_skill_markdown() -> String:
	return "---\nname: {skill_name}\ndescription:{skill_description}\n---\n\n{skill_content}".format({
		"skill_name": skill_name,
		"skill_description": skill_description,
		"skill_content": skill_content
	})

@tool
class_name AgentSkillItem
extends HBoxContainer


signal edit
signal delete

@onready var skill_name: Label = %SkillName
@onready var edit_button: Button = %EditButton
@onready var delete_button: Button = %DeleteButton

var skill: AgentSkillResource = null

func _ready() -> void:
	edit_button.pressed.connect(edit.emit)
	delete_button.pressed.connect(delete.emit)

func set_skill(p_skill: AgentSkillResource):
	self.skill = p_skill
	skill_name.text = p_skill.skill_name

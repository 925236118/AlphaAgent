@tool
class_name AgentSkillItem
extends HBoxContainer


signal edit
signal delete

@onready var skill_name_label: Label = %SkillName
@onready var edit_button: Button = %EditButton
@onready var delete_button: Button = %DeleteButton

var skill: AgentSkillResource = null

func _ready() -> void:
	edit_button.pressed.connect(edit.emit)
	delete_button.pressed.connect(delete.emit)
	if not skill_name_label == null and not skill == null:
		skill_name_label.text = skill.skill_name

func set_skill(p_skill: AgentSkillResource):
	self.skill = p_skill
	if not skill_name_label == null and not skill == null:
		skill_name_label.text = p_skill.skill_name

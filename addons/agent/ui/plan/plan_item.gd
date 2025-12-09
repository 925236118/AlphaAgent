@tool
class_name AgentPlanItem
extends HBoxContainer

@onready var label: Label = $Label

func set_text(text: String):
	label.text = text

func set_state(state: AlphaAgentPlugin.PlanState):
	pass

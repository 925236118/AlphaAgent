@tool
class_name AgentPlanItem
extends HBoxContainer

@onready var state_plan: TextureRect = %StatePlan
@onready var state_active: TextureRect = %StateActive
@onready var state_finish: TextureRect = %StateFinish
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: RichTextLabel = $RichTextLabel

#@onready var label: Label = $Label

func set_text(text: String):
	label.text = text

func set_state(state: AlphaAgentSingleton.PlanState):
	state_plan.hide()
	state_active.hide()
	state_finish.hide()
	label.modulate = Color("#ffffff")
	animation_player.stop()
	match state:
		AlphaAgentSingleton.PlanState.Plan:
			state_plan.show()
		AlphaAgentSingleton.PlanState.Active:
			state_active.show()
			animation_player.play("loop")
		AlphaAgentSingleton.PlanState.Finish:
			state_finish.show()
			label.modulate = Color("#5B5B5B")

@tool
class_name AgentPlanItem
extends HBoxContainer

@onready var state_plan: TextureRect = %StatePlan
@onready var state_active: TextureRect = %StateActive
@onready var state_finish: TextureRect = %StateFinish
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: RichTextLabel = $RichTextLabel

var state: AlphaAgentSingleton.PlanState = AlphaAgentSingleton.PlanState.Plan
var _pending_text: String = ""
var _has_pending_text: bool = false
var _has_pending_state: bool = false

func _ready() -> void:
	if _has_pending_text:
		_apply_text(_pending_text)
	if _has_pending_state:
		_apply_state(state)

func set_text(text: String):
	_pending_text = text
	_has_pending_text = true
	if is_node_ready():
		_apply_text(text)

func set_state(state: AlphaAgentSingleton.PlanState):
	self.state = state
	_has_pending_state = true
	if not is_node_ready():
		return
	_apply_state(state)

func _apply_text(text: String):
	label.text = text

func _apply_state(new_state: AlphaAgentSingleton.PlanState):
	state_plan.hide()
	state_active.hide()
	state_finish.hide()
	label.modulate = Color("#ffffff")
	animation_player.stop()
	match new_state:
		AlphaAgentSingleton.PlanState.Plan:
			state_plan.show()
		AlphaAgentSingleton.PlanState.Active:
			state_active.show()
			animation_player.play("loop")
		AlphaAgentSingleton.PlanState.Finish:
			state_finish.show()
			label.modulate = Color("#5B5B5B")

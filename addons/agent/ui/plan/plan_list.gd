@tool
class_name AgentPlanList
extends MarginContainer

@onready var plan_item_container: VBoxContainer = %PlanItemContainer
@onready var expand_button: Button = %ExpandButton
const PLAN_ITEM = preload("uid://58ryyxbn0dby")

func _ready() -> void:
	expand_button.pressed.connect(func (): plan_item_container.visible = not plan_item_container.visible)

func update_list(list: Array[AlphaAgentPlugin.PlanItem]):
	if list.size():
		show()
	else:
		hide()

	var active_index = 0
	clear_items()

	for index in list.size():
		var item = list[index]
		var plan_item = PLAN_ITEM.instantiate()
		plan_item_container.add_child(plan_item)
		plan_item.set_text(item.name)
		plan_item.set_state(item.state)
		if item.state == AlphaAgentPlugin.PlanState.Active:
			active_index = index
	expand_button.text = "正在执行任务 %d / %d" % [active_index + 1, list.size()]

func clear_items():
	var count = plan_item_container.get_child_count()
	for i in count:
		plan_item_container.get_child(count - i - 1).queue_free()

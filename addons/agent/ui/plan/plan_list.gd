@tool
class_name AgentPlanList
extends PanelContainer

@onready var plan_item_scroll_container: ScrollContainer = %PlanItemScrollContainer
@onready var show_plan: VBoxContainer = %ShowPlan
@onready var plan_item_container: VBoxContainer = %PlanItemContainer
@onready var expand_button: Button = %ExpandButton
@onready var all_finished_icon: TextureRect = %AllFinishedIcon
@onready var plan_text: Label = %PlanText
@onready var expand_icon: TextureRect = %ExpandIcon

const PLAN_ITEM = preload("uid://58ryyxbn0dby")

func _ready() -> void:
	expand_button.pressed.connect(show_plan_list)

func update_list(list: Array[AlphaAgentSingleton.PlanItem]):
	if list.size():
		show()
	else:
		hide()
	var all_finished = true

	var active_index = -1
	clear_items()

	if list.size() <= 4:
		plan_item_scroll_container.custom_minimum_size.y = list.size() * (32 + 4) - 4
	else:
		plan_item_scroll_container.custom_minimum_size.y = 4 * (25 + 4) + 12

	for index in list.size():
		var item = list[index]
		var plan_item = PLAN_ITEM.instantiate()
		plan_item_container.add_child(plan_item)
		plan_item.set_text(item.name)
		plan_item.set_state(item.state)
		if item.state == AlphaAgentSingleton.PlanState.Active:
			active_index = index
			all_finished = false
		elif item.state == AlphaAgentSingleton.PlanState.Plan:
			all_finished = false

	if all_finished:
		plan_text.text = "任务完成"
		all_finished_icon.show()
	else:
		plan_text.text = "正在执行任务 %d / %d" % [active_index + 1, list.size()]
		all_finished_icon.hide()

func clear_items():
	var count = plan_item_container.get_child_count()
	for i in count:
		plan_item_container.get_child(count - i - 1).queue_free()

func show_plan_list():
	show_plan.visible = not show_plan.visible
	expand_icon.flip_v = not show_plan.visible

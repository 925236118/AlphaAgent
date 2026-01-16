@tool
class_name UpdatePlanListTool
extends AgentToolBase

func _get_tool_description() -> String:
	return "对于用户给出的复杂的任务，可以拆分成多段执行的，需要使用本工具对任务拆分成若干个阶段。还可以更新当前已有的阶段任务状态。"

func _get_tool_name() -> String:
	return "update_plan_list"

func _get_tool_short_description() -> String:
	return "用于管理Agent的计划列表"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"tasks": {
				"type": "array",
				"description": "拆分后的阶段任务项，数量在5到10个之间。按照执行顺序排序。**注意**:列表中应只有一个任务为active状态。",
				"items": {
					"type": "object",
					"properties": {
						"name": {
							"type": "string",
							"description": "要执行的阶段任务名称。",
						},
						"state": {
							"type": "string",
							"enum": ["plan", "active", "finish"],
							"description": "该阶段的当前状态。"
						}
					},
					"required": ["name", "state"]
				}
			},
		},
		"required": ["tasks"]
	}

func _get_tool_readonly() -> bool:
	return false

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.EDITOR

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var result: Dictionary = {}
	var json = JSON.parse_string(tool_call.function.arguments)
	if not json == null and json.has("tasks"):
		var tasks = json.get("tasks")
		var list: Array[AlphaAgentSingleton.PlanItem] = []
		var active_index = -1
		var all_finished = true
		var all_plan = true
		for index in tasks.size():
			var task: Dictionary = tasks[index]
			var task_name = task.get("name", "")
			var task_state = task.get("state", "plan")
			var plan_state: AlphaAgentSingleton.PlanState
			match task_state:
				"plan":
					plan_state = AlphaAgentSingleton.PlanState.Plan
					all_finished = false
				"active":
					plan_state = AlphaAgentSingleton.PlanState.Active
					all_finished = false
					active_index = index
					all_plan = false
				"finish":
					plan_state = AlphaAgentSingleton.PlanState.Finish
					all_plan = false
			list.push_back(AlphaAgentSingleton.PlanItem.new(task_name, plan_state))
		var singleton = AlphaAgentSingleton.get_instance()
		singleton.update_plan_list.emit(list)
		if active_index == 0:
			result = {
				"success": "更新任务列表成功。开始执行当前任务。"
			}
		elif all_finished:
			result = {
				"success": "更新任务列表成功。所有任务均已完成，回复用户。"
			}
		elif all_plan:
			result = {
				"success": "更新任务列表成功。开始执行第一项任务。"
			}
		else:
			result = {
				"success": "更新任务列表成功。停止输出，等待用户确认。"
			}

	return result

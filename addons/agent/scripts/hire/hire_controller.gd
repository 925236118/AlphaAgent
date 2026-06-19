@tool
class_name HireController
extends RefCounted

## 雇佣模式主控制器
## 管理完整的 Research → Plan → Hire → Verify → Fix Loop 状态机
##
## 通过 AgentAdapter 多态支持 CC 和 Pi，与具体 Agent 实现解耦

# -- 状态枚举 --
enum Phase {
	IDLE,
	RESEARCH,    # Phase 1: 调研（Alpha 使用只读工具）
	PLAN,        # Phase 2: 规划（Alpha 拆分步骤，等待用户确认）
	HIRE,        # Phase 3: 执行（外部 Agent 执行步骤）
	VERIFY,      # Phase 4: 验证（Alpha 使用只读工具验证）
	FIX,         # 修复循环
	COMPLETE,    # 全部完成
	CANCELLED    # 已取消
}

# -- 信号 --
signal phase_changed(phase: int, message: String)
signal step_started(step_index: int, step_title: String)
signal step_progress(step_index: int, progress: float)
signal step_completed(step_index: int, result: Dictionary)
signal step_failed(step_index: int, reason: String, retry: int)
signal text_output(text: String)
signal tool_started(tool_name: String, tool_args: Dictionary)
signal tool_finished(tool_name: String, result: Dictionary)
signal verification_result(report: Dictionary)
signal all_complete(summary: Dictionary)

# -- 成员 --
var _adapter: AgentAdapter = null      # CCAdapter 或 PiAdapter
var _verification: VerificationEngine = null
var _current_phase: int = Phase.IDLE
var _steps: Array[Dictionary] = []     # [{title, description, context, acceptance_criteria, expected_files, depends_on}]
var _current_step_index: int = -1
var _retry_count: int = 0
var _max_retries: int = 2
var _results: Array[Dictionary] = []   # 每步骤的执行结果
var _is_running: bool = false
var _is_cancelled: bool = false

func _init() -> void:
	_verification = VerificationEngine.new()

## 初始化，选择 Agent 类型
func initialize(agent_type: String) -> void:
	match agent_type:
		"cc":
			_adapter = CCAdapter.new()
			_max_retries = AlphaAgentPlugin.global_setting.cc_max_fix_retries
		"pi":
			_adapter = PiAdapter.new()
			_max_retries = AlphaAgentPlugin.global_setting.pi_max_fix_retries
		_:
			push_error("HireController: 不支持的 Agent 类型: %s" % agent_type)
			return

	_current_phase = Phase.IDLE
	_current_step_index = -1
	_retry_count = 0
	_steps.clear()
	_results.clear()
	_is_running = false
	_is_cancelled = false

## 检查 Agent 是否可用
func check_agent_available() -> bool:
	if not _adapter:
		return false
	return _adapter.check_availability()

## 设置执行步骤（从 Phase 2 PLAN 产出）
func set_steps(steps: Array[Dictionary]) -> void:
	_steps = steps
	_results.clear()
	for _i in steps.size():
		_results.push_back({"status": "pending"})

## 获取当前阶段
func get_current_phase() -> int:
	return _current_phase

## 获取当前步骤索引
func get_current_step_index() -> int:
	return _current_step_index

## 获取当前 Adapter
func get_adapter() -> AgentAdapter:
	return _adapter

## 开始执行所有步骤
func execute_all_steps() -> void:
	if _steps.is_empty():
		push_error("HireController: 没有步骤可执行，请先调用 set_steps()")
		return

	_is_running = true
	_is_cancelled = false

	for i in _steps.size():
		if _is_cancelled:
			break

		_current_step_index = i
		var step = _steps[i]
		_retry_count = 0

		step_started.emit(i, step.get("title", "Step %d" % i))
		set_phase(Phase.HIRE)

		# 执行步骤（含修复循环）
		var result = await _execute_step_with_retry(step, i)
		_results[i] = result

		match result["status"]:
			"pass", "pass_with_warnings":
				step_completed.emit(i, result)
			"logic_error":
				step_failed.emit(i, "逻辑错误，等待用户重新规划", _retry_count)
				set_phase(Phase.IDLE)
				return
			"failed_max_retries":
				step_failed.emit(i, "超过最大重试次数", _max_retries)
				set_phase(Phase.IDLE)
				return
			"cancelled":
				set_phase(Phase.CANCELLED)
				return

	set_phase(Phase.COMPLETE)
	_is_running = false
	all_complete.emit(_build_summary())

## 执行单个步骤（含验证失败后的修复循环）
func _execute_step_with_retry(step: Dictionary, step_index: int) -> Dictionary:
	while _retry_count <= _max_retries:
		if _is_cancelled:
			return {"status": "cancelled"}

		# Phase 3: HIRE — 启动 Agent 并发送任务
		var hire_ok = await _hire_to_agent(step, step_index, _retry_count > 0)
		if not hire_ok:
			return {"status": "failed", "reason": "Agent 启动失败"}

		# Phase 4: VERIFY — 验证执行结果
		set_phase(Phase.VERIFY)
		await _wait_frame()
		var report = _verification.verify_step(step, step_index)
		verification_result.emit(report.to_dict())

		match report.overall_verdict:
			VerificationEngine.Verdict.PASS:
				return {"status": "pass", "step_index": step_index, "report": report.to_dict()}

			VerificationEngine.Verdict.WARN:
				return {"status": "pass_with_warnings", "step_index": step_index, "report": report.to_dict()}

			VerificationEngine.Verdict.LOGIC_ERROR:
				return {"status": "logic_error", "step_index": step_index, "report": report.to_dict()}

			VerificationEngine.Verdict.FAIL:
				_retry_count += 1
				if _retry_count > _max_retries:
					return {"status": "failed_max_retries", "step_index": step_index, "report": report.to_dict()}

				# 分析失败 → 生成修复提示词 → 在同一 session 中发送修复
				set_phase(Phase.FIX)
				var fix_analysis = _verification.analyze_failure(report)
				var fix_prompt = CCPromptBuilder.build_fix_prompt(fix_analysis, step)
				step["description"] = fix_prompt  # 更新步骤描述为修复指令
				step_progress.emit(step_index, float(_retry_count) / float(_max_retries + 1))
				# 继续循环，在同 session 中执行修复

	return {"status": "failed", "reason": "未知错误"}

## 雇佣 Agent 执行步骤
## is_fix: 是否是修复调用（同 session 内继续）
func _hire_to_agent(step: Dictionary, step_index: int, is_fix: bool) -> bool:
	# 构建提示词
	var prompt: String
	if is_fix:
		prompt = step.get("description", "")  # 已在上次失败后替换为修复指令
	else:
		prompt = CCPromptBuilder.build_step_prompt(step)

	if prompt.is_empty():
		push_error("HireController: 提示词为空")
		return false

	# 启动 Agent 子进程
	if not is_fix or not _adapter.supports_session():
		# 新步骤或 Pi（不支持 session）：重新启动
		if _adapter.has_exited() == false:
			_adapter.terminate()
		if not _adapter.start():
			return false

		if _adapter is CCAdapter:
			(_adapter as CCAdapter).start_new_step(step_index)

	# 发送提示词
	_adapter.send_prompt(prompt)

	# 事件循环：读取 Agent 输出
	while not _adapter.has_exited():
		if _is_cancelled:
			_adapter.abort()
			return false

		var event = _adapter.read_event()
		match event.get("type", ""):
			"agent_started":
				pass  # 已在 step_started 信号中处理
			"text_delta":
				text_output.emit(event.get("text", ""))
			"tool_started":
				tool_started.emit(event.get("tool_name", ""), event.get("tool_args", {}))
			"tool_updated":
				pass  # 中间更新，暂时不展示
			"tool_finished":
				tool_finished.emit(event.get("tool_name", ""), event.get("result", {}))
			"agent_finished":
				break  # 正常完成
			"error":
				push_warning("Agent 错误: %s" % event.get("message", ""))
				text_output.emit("[错误] %s" % event.get("message", ""))
			"empty":
				await _wait_frame_short()

	_adapter.terminate()

	if _adapter.get_exit_code() != 0:
		push_warning("Agent 进程异常退出，exit code: %d" % _adapter.get_exit_code())

	return true

## 取消执行
func cancel() -> void:
	_is_cancelled = true
	_is_running = false
	if _adapter:
		_adapter.abort()
	set_phase(Phase.CANCELLED)

## 跳过当前步骤
func skip_current_step() -> void:
	if _current_step_index >= 0 and _current_step_index < _results.size():
		_results[_current_step_index] = {"status": "skipped"}
	if _adapter:
		_adapter.abort()

## 是否正在运行
func is_running() -> bool:
	return _is_running

## 重置
func reset() -> void:
	cancel()
	_current_phase = Phase.IDLE
	_steps.clear()
	_results.clear()
	_current_step_index = -1
	_retry_count = 0

# -- 内部方法 --

func set_phase(phase: int) -> void:
	_current_phase = phase
	var names = {
		Phase.IDLE: "空闲",
		Phase.RESEARCH: "调研中",
		Phase.PLAN: "规划中",
		Phase.HIRE: "执行中",
		Phase.VERIFY: "验证中",
		Phase.FIX: "修复中",
		Phase.COMPLETE: "已完成",
		Phase.CANCELLED: "已取消"
	}
	phase_changed.emit(phase, names.get(phase, "未知"))

func _build_summary() -> Dictionary:
	var passed = 0
	var failed = 0
	var skipped = 0

	for r in _results:
		match r.get("status", ""):
			"pass", "pass_with_warnings":
				passed += 1
			"failed", "failed_max_retries":
				failed += 1
			"skipped":
				skipped += 1

	return {
		"total": _steps.size(),
		"passed": passed,
		"failed": failed,
		"skipped": skipped,
		"agent": _adapter.get_agent_name() if _adapter else "Unknown"
	}

func _wait_frame() -> void:
	var tree = AlphaAgentSingleton.get_instance().get_scene_tree()
	if tree:
		await tree.process_frame

func _wait_frame_short() -> void:
	var tree = AlphaAgentSingleton.get_instance().get_scene_tree()
	if tree:
		await tree.create_timer(0.05).timeout

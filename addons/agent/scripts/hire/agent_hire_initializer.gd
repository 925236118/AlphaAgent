@tool
class_name AgentHireInitializer
extends RefCounted

## Agent 雇佣仪式初始化器
## 三阶段检测流程：发布招聘广告 → 面试 → 雇佣成功 / 拒绝 offer
##
## 使用方式:
##   var init = AgentHireInitializer.new()
##   init.initialize("cc")  # 同步调用，全部检测立即完成
##   检查 init.is_ready() / init.get_result()

# -- 信号 --
signal init_step(step: String, status: String, message: String)
## step: "advertise" | "interview" | "result"
## status: "running" | "success" | "failed"

signal init_finished(success: bool)

# -- 状态 --
var _selected_agent: String = "cc"   # "cc" | "pi"
var _env_checked: bool = false
var _agent_ready: bool = false
var _checker: AgentChecker = null
var _agent_name: String = ""
var _agent_version: String = ""

# -- 结果信息 --
var result_message: String = ""
var result_success: bool = false

## 启动初始化流程（同步执行，所有检测立即完成）
func initialize(agent_type: String) -> void:
	_selected_agent = agent_type
	_env_checked = false
	_agent_ready = false
	result_success = false
	_agent_name = ""
	_agent_version = ""

	# Step 1: 发布招聘广告（where/which 检测 PATH 中是否存在）
	init_step.emit("advertise", "running", "正在发布招聘广告...")
	_checker = _get_checker(agent_type)
	if _checker == null:
		init_step.emit("advertise", "failed",
			"不支持的 Agent 类型: %s" % agent_type)
		_finish(false)
		return

	# 同步执行 where/which 检测
	var available := _checker.check()
	if not available:
		init_step.emit("advertise", "failed",
			"%s 拒绝了您的 offer，请检查\n· 未找到 %s 命令\n· 请确保已安装并在 PATH 中" % [agent_type, agent_type])
		_finish(false)
		return

	init_step.emit("advertise", "success", "收到回应")

	# Step 2: 面试（check() 内部已执行 --version 并填充了 version 字段）
	init_step.emit("interview", "running", "正在面试中...")

	# 提取版本信息
	if _checker is CCChecker:
		var cc = _checker as CCChecker
		_agent_name = cc.get_agent_name()
		_agent_version = cc.cc_version
	elif _checker is PiChecker:
		var pi = _checker as PiChecker
		_agent_name = pi.get_agent_name()
		_agent_version = pi.pi_version

	if _agent_version == "":
		init_step.emit("interview", "failed", "面试未通过，请检查安装")
		_finish(false)
		return

	init_step.emit("interview", "success", "面试通过！")

	# Step 3: 雇佣成功
	init_step.emit("result", "success",
		"%s 已经雇佣成功，员工版本 %s" % [_agent_name, _agent_version])
	_agent_ready = true
	_env_checked = true
	_finish(true)

## 检测 Agent 是否就绪
func is_ready() -> bool:
	return _agent_ready

## 是否已完成环境检测
func is_env_checked() -> bool:
	return _env_checked

## 获取选中的 agent 类型
func get_selected_agent() -> String:
	return _selected_agent

## 获取 agent 版本号
func get_agent_version() -> String:
	return _agent_version

## 获取 agent 名称
func get_agent_name() -> String:
	return _agent_name

## 获取检测结果
func get_result() -> Dictionary:
	return {
		"success": result_success,
		"message": result_message,
		"agent": _agent_name,
		"version": _agent_version
	}

## 重置状态（切换 Agent 或重新检测时使用）
func reset() -> void:
	_env_checked = false
	_agent_ready = false
	_selected_agent = "cc"
	_checker = null
	_agent_name = ""
	_agent_version = ""
	result_message = ""
	result_success = false

# -- 内部方法 --

func _get_checker(agent_type: String) -> AgentChecker:
	match agent_type:
		"cc":
			return CCChecker.new()
		"pi":
			return PiChecker.new()
	return null

func _finish(success: bool) -> void:
	result_success = success
	var status_text = "已就绪" if success else "未就绪"
	result_message = "%s %s" % [_agent_name if not _agent_name.is_empty() else "Agent", status_text]
	init_finished.emit(success)

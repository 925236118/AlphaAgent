@tool
class_name CCExecutionPanel
extends MarginContainer

## CC 执行进度面板
## 显示在执行模式下的步骤进度、操作按钮和 Agent 状态

# -- 子节点引用 --
@onready var step_label: Label = %StepLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel
@onready var pause_button: Button = %PauseButton
@onready var skip_button: Button = %SkipButton
@onready var stop_button: Button = %StopButton
@onready var session_label: Label = %SessionLabel
@onready var retry_label: Label = %RetryLabel

# -- 信号 --
signal pause_requested
signal skip_requested
signal stop_requested

# -- 状态 --
var _total_steps: int = 0
var _current_step: int = -1
var _phase: String = ""

func _ready() -> void:
	pause_button.pressed.connect(func(): pause_requested.emit())
	skip_button.pressed.connect(func(): skip_requested.emit())
	stop_button.pressed.connect(func(): stop_requested.emit())
	hide()

## 显示面板并设置步骤信息
func show_for_steps(total: int) -> void:
	_total_steps = total
	_current_step = 0
	if progress_bar:
		progress_bar.max_value = total
		progress_bar.value = 0
	show()

## 更新当前步骤
func update_step(step_index: int, step_title: String) -> void:
	_current_step = step_index
	if step_label:
		step_label.text = "步骤 %d/%d: %s" % [step_index + 1, _total_steps, step_title]
	if progress_bar:
		progress_bar.value = step_index

## 更新阶段文字
func update_phase(phase: String) -> void:
	_phase = phase
	if status_label:
		status_label.text = phase

## 更新 Session 信息（CC 独有）
func update_session(session_id: String, retry_count: int, max_retries: int) -> void:
	if session_label:
		if session_id.is_empty():
			session_label.text = "Session: 新会话"
		else:
			session_label.text = "Session: %s..." % session_id.substr(0, 12)
	if retry_label:
		retry_label.text = "重试: %d/%d" % [retry_count, max_retries]

## 根据 Agent 类型调整 UI（Pi 无 session 信息，但保留重试计数）
func configure_for_agent(agent_type: String) -> void:
	if agent_type == "pi":
		# Pi 有 session 但不需要在 UI 上强调
		pass

## 隐藏面板
func hide_panel() -> void:
	hide()

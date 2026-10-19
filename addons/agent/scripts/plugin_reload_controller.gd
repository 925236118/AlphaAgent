@tool
extends Node

## 此节点挂在编辑器基础控件下，在 AlphaAgent 卸载后继续存活。
var dialog: ConfirmationDialog
var timer: Timer
var running: bool = false
var waiting: bool = false
var restoring: bool = false
var target_layout: int = 0
var old_layout: int = 0
var snapshot: Dictionary = {}
var old_panel: WeakRef
var deadline: int = 0
var previous_workspace: String = "Script"
var failure_message: String = ""

func _ready() -> void:
	dialog = ConfirmationDialog.new()
	dialog.title = "刷新 AlphaAgent"
	dialog.get_ok_button().text = "立即刷新"
	dialog.get_cancel_button().text = "稍后"
	add_child(dialog)
	dialog.confirmed.connect(_on_confirmed)
	dialog.canceled.connect(_on_canceled)
	timer = Timer.new()
	timer.wait_time = 0.2
	add_child(timer)
	timer.timeout.connect(_poll)

func request_refresh() -> void:
	if running or waiting:
		return
	var plugin = AlphaAgentSingleton.get_instance().editor_plugin
	if not is_instance_valid(plugin):
		return
	old_layout = plugin.instance_layout
	target_layout = AlphaAgentPlugin.global_setting.plugin_layout
	if old_layout == target_layout:
		queue_free()
		return
	dialog.dialog_text = "布局已修改，是否立即刷新插件？\n刷新后将应用新布局，并恢复当前会话和输入草稿。"
	dialog.popup_centered(Vector2i(480, 150))

func _on_canceled() -> void:
	if not running:
		waiting = false
		timer.stop()
		queue_free()

func _on_confirmed() -> void:
	if running or waiting:
		return
	waiting = true
	dialog.hide()
	timer.start()
	# 退出确认框的信号栈后再检查任务状态。
	_show_waiting.call_deferred()

func _show_waiting() -> void:
	if not waiting:
		return
	var panel = AlphaAgentSingleton.get_instance().main_panel
	if is_instance_valid(panel) and panel.is_busy_for_reload():
		dialog.dialog_text = "当前任务结束后将刷新插件。\n可以取消本次等待，已保存的布局设置会保留。"
		dialog.get_ok_button().hide()
		dialog.get_cancel_button().text = "取消等待"
		dialog.popup_centered(Vector2i(480, 150))

func _poll() -> void:
	if running:
		_check_initialized()
		return
	if not waiting:
		return
	var singleton = AlphaAgentSingleton.get_instance()
	if not is_instance_valid(singleton.editor_plugin) or not is_instance_valid(singleton.main_panel):
		queue_free()
		return
	var panel = singleton.main_panel
	if panel.is_busy_for_reload():
		return
	waiting = false
	running = true
	dialog.hide()
	panel.reload_locked = true
	snapshot = panel.capture_reload_state()
	old_panel = weakref(panel)
	# 等待过程中可能再次修改了设置，以确认时的目标为准。
	AlphaAgentPlugin.global_setting.plugin_layout = target_layout
	AlphaAgentPlugin.global_setting.save_global_setting()
	var script_editor = EditorInterface.get_script_editor()
	if not script_editor.is_visible_in_tree():
		previous_workspace = "2D" if not singleton.editor_plugin._has_main_screen() else "AlphaAgent"
	deadline = Time.get_ticks_msec() + 15000
	timer.stop()
	# 先安排重新启用，再卸载插件；回调属于外部控制器。
	get_tree().create_timer(0.2).timeout.connect(_reenable)
	EditorInterface.set_plugin_enabled("agent", false)

func _reenable() -> void:
	if old_panel != null and is_instance_valid(old_panel.get_ref()):
		if Time.get_ticks_msec() > deadline:
			_fail("旧插件面板未能释放，请重新启用 AlphaAgent。")
			return
		get_tree().create_timer(0.1).timeout.connect(_reenable)
		return
	if not ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray()).has("res://addons/agent/plugin.cfg"):
		EditorInterface.set_plugin_enabled("agent", true)
	timer.start()

func _check_initialized() -> void:
	var singleton = AlphaAgentSingleton.get_instance()
	var panel = singleton.main_panel
	if is_instance_valid(singleton.editor_plugin) and is_instance_valid(panel) and panel.startup_complete:
		timer.stop()
		panel.reload_locked = true
		await panel.restore_reload_state(snapshot)
		panel.reload_locked = false
		if singleton.editor_plugin._has_main_screen():
			EditorInterface.set_main_screen_editor("AlphaAgent")
		elif previous_workspace == "AlphaAgent":
			EditorInterface.set_main_screen_editor("Script")
		panel.setting_container.update_layout_status()
		if not failure_message.is_empty():
			_show_failure(failure_message)
		else:
			queue_free()
		return
	if Time.get_ticks_msec() > deadline:
		if not restoring:
			_rollback()
		else:
			_fail("插件刷新和布局恢复均未完成，请在项目设置中重新启用 AlphaAgent。")

func _rollback() -> void:
	timer.stop()
	restoring = true
	failure_message = "新布局初始化失败，已恢复原布局。当前会话和草稿已恢复。"
	AlphaAgentPlugin.global_setting.plugin_layout = old_layout
	AlphaAgentPlugin.global_setting.save_global_setting()
	var singleton = AlphaAgentSingleton.get_instance()
	old_panel = weakref(singleton.main_panel) if is_instance_valid(singleton.main_panel) else null
	if ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray()).has("res://addons/agent/plugin.cfg"):
		EditorInterface.set_plugin_enabled("agent", false)
	deadline = Time.get_ticks_msec() + 15000
	get_tree().create_timer(0.2).timeout.connect(_reenable)

func _fail(message: String) -> void:
	timer.stop()
	var panel = AlphaAgentSingleton.get_instance().main_panel
	if is_instance_valid(panel):
		panel.reload_locked = false
	# 故障时保留控制器上的快照，允许恢复，避免会话被静默丢弃。
	EditorInterface.get_base_control().set_meta("alphaagent_reload_recovery", snapshot)
	_show_failure(message)

func _show_failure(message: String) -> void:
	running = false
	dialog.dialog_text = message
	dialog.get_ok_button().hide()
	dialog.get_cancel_button().text = "关闭"
	dialog.popup_centered(Vector2i(520, 170))

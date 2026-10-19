@tool
extends Node

const RESET = preload("res://addons/agent/scripts/config_reset.gd")
var dialog: ConfirmationDialog
var running: bool = false
var old_panel: WeakRef
var snapshot: Dictionary = {}
var plan: Dictionary = {}
var deadline: int = 0
var failure: String = ""
var target_version: String = ""

func _ready() -> void:
	dialog = ConfirmationDialog.new()
	dialog.title = "初始化所有配置"
	target_version = RESET.loaded_version(AlphaAgentPlugin.global_setting)
	dialog.dialog_text = "警告：会删除所有的模型配置、角色、记忆、技能等内容。请谨慎选择。\n\n范围：当前配置版本 %s（含 API 密钥、搜索及其他设置），\n以及当前项目记忆。此操作不可撤销。\n确认后会自动刷新插件并恢复默认配置。历史对话和项目文件保留。" % (target_version if not target_version.is_empty() else "未知（配置未就绪）")
	dialog.get_ok_button().text = "确认初始化"
	dialog.get_ok_button().theme_type_variation = &"DangerButton"
	dialog.get_cancel_button().text = "取消"
	dialog.theme = AlphaAgentSingleton.get_instance().main_panel.theme
	add_child(dialog)
	dialog.confirmed.connect(_on_confirmed)
	dialog.canceled.connect(func():
		if not running:
			queue_free()
	)
	dialog.popup_centered(Vector2i(640, 240))

func _on_confirmed() -> void:
	if running:
		return
	var host := EditorInterface.get_base_control()
	var reload_controller = host.get_node_or_null("AlphaAgentReloadController")
	var panel = AlphaAgentSingleton.get_instance().main_panel
	if is_instance_valid(reload_controller) or not is_instance_valid(panel) or panel.is_busy_for_reload():
		_show_result("当前有任务或插件刷新尚未结束，请结束后重新初始化。")
		return
	var settings = AlphaAgentPlugin.global_setting
	# 已打开的弹窗自身也可能经历热重载，新加字段尚未初始化。
	var confirmed_version = get("target_version")
	if not confirmed_version is String or confirmed_version.is_empty() or RESET.loaded_version(settings) != confirmed_version:
		_show_result("当前配置版本未就绪或已经变化，请关闭此窗口并重新打开初始化操作。")
		return
	plan = RESET.collect_files(settings, confirmed_version)
	if not plan.error.is_empty():
		_show_result(plan.error)
		return
	running = true
	panel.reload_locked = true
	snapshot = panel.capture_reload_state()
	old_panel = weakref(panel)
	deadline = Time.get_ticks_msec() + 15000
	dialog.hide()
	_unload.call_deferred()

func _unload() -> void:
	EditorInterface.set_plugin_enabled("agent", false)
	get_tree().create_timer(0.2).timeout.connect(_reset_and_enable)

func _reset_and_enable() -> void:
	if is_instance_valid(old_panel.get_ref()):
		if Time.get_ticks_msec() > deadline:
			_show_result("旧插件未能释放，配置尚未删除。请手动重新启用插件。")
			return
		get_tree().create_timer(0.1).timeout.connect(_reset_and_enable)
		return
	# 先保存项目记忆，失败时不删除磁盘上的版本配置。
	var config = AlphaAgentPlugin.CONFIG
	var previous_memory = config.memory.duplicate()
	config.memory.clear()
	if ResourceSaver.save(config, "res://addons/agent/config.tres") != OK:
		config.memory.assign(previous_memory)
		failure = "无法清空项目记忆，版本配置尚未删除。请检查文件权限。"
	else:
		AlphaAgentPlugin.project_memory.clear()
		AlphaAgentPlugin.global_memory.clear()
		failure = RESET.execute(plan)
	EditorInterface.set_plugin_enabled("agent", true)
	_wait_ready()

func _wait_ready() -> void:
	var panel = AlphaAgentSingleton.get_instance().main_panel
	if is_instance_valid(panel) and panel.startup_complete:
		await panel.restore_reload_state(snapshot)
		panel.reload_locked = false
		if AlphaAgentSingleton.get_instance().editor_plugin._has_main_screen():
			EditorInterface.set_main_screen_editor("AlphaAgent")
		_show_result("当前版本配置已初始化，已恢复默认配置。" if failure.is_empty() else failure)
		return
	if Time.get_ticks_msec() > deadline:
		EditorInterface.get_base_control().set_meta("alphaagent_reload_recovery", snapshot)
		_show_result("插件未能完成刷新，请手动重新启用 AlphaAgent。" + failure)
		return
	get_tree().create_timer(0.1).timeout.connect(_wait_ready)

func _show_result(message: String) -> void:
	running = false
	var panel = AlphaAgentSingleton.get_instance().main_panel
	if is_instance_valid(panel) and old_panel != null and panel == old_panel.get_ref():
		panel.reload_locked = false
	dialog.dialog_text = message
	dialog.get_ok_button().hide()
	dialog.get_cancel_button().text = "关闭"
	dialog.popup_centered(Vector2i(640, 200))

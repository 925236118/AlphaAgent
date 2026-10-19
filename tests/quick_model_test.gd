extends SceneTree

# godot --headless --editor --path . --script res://tests/quick_model_test.gd
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	await create_timer(1.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var original_setting = AlphaAgentPlugin.global_setting
	var gs = AlphaAgentPlugin.GlobalSetting.new()
	gs.setting_file = "user://quick_model_test_settings.json"
	var models_path = "user://quick_model_test_models.json"
	var file = FileAccess.open(models_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"supplier": [{"id": "supplier", "name": "Test", "provider": "deepseek", "models": [
		{"id": "chat", "name": "Chat", "supplier_id": "supplier", "active": true},
		{"id": "disabled", "name": "Disabled", "supplier_id": "supplier", "active": false},
		{"id": "image", "name": "Image", "supplier_id": "supplier", "active": true, "supports_image_generation": true}
	]}]}))
	file.close()
	gs.model_manager = ModelConfig.ModelManager.new(models_path)
	AlphaAgentPlugin.global_setting = gs
	var settings = load("res://addons/agent/ui/setting/setting.tscn").instantiate()
	root.add_child(settings)
	settings._init_quick_model_option()
	var option = settings.get_node("%QuickModelOption")
	check(option.item_count == 2, "Only enabled chat models")
	option.item_selected.emit(1)
	var singleton = AlphaAgentSingleton.get_instance()
	var model = gs.model_manager.get_model_by_id("disabled")
	model.active = true
	singleton.models_changed.emit()
	check(option.item_count == 3, "Enabling refreshes immediately")
	check(option.get_item_metadata(option.selected).model_id == "chat", "Keep valid selection")
	gs.model_manager.get_model_by_id("chat").active = false
	singleton.models_changed.emit()
	check(option.item_count == 2 and option.selected == 0, "Disabled selection falls back")
	check(gs.quick_model_model_id.is_empty() and gs.quick_model_supplier_id.is_empty(), "Clear stored selection")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(gs.setting_file))
	check(saved.quick_model_model_id.is_empty(), "Persist fallback")
	option.item_selected.emit(1)
	model.name = "Renamed"
	singleton.models_changed.emit()
	check(option.get_item_text(1) == "Test / Renamed" and option.selected == 1, "Rename preserves selection")
	model.supports_image_generation = true
	singleton.models_changed.emit()
	check(option.item_count == 1 and gs.quick_model_model_id.is_empty(), "Exclude converted image model")
	model.supports_image_generation = false
	singleton.models_changed.emit()
	option.item_selected.emit(1)
	var row = load("res://addons/agent/ui/models/setting_model_item.tscn").instantiate()
	root.add_child(row)
	row.set_setting_model_info(model)
	row.on_remove_button_click()
	check(option.item_count == 1 and gs.quick_model_model_id.is_empty(), "Deleting refreshes and clears selection")
	row.free()
	settings.free()
	AlphaAgentPlugin.global_setting = original_setting
	for path in [gs.setting_file, models_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Quick model: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

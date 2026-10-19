extends SceneTree

# 编辑器插件依赖 editor-only 资源，运行方式：
# godot --headless --editor --path . --script res://tests/deepseek_search_test.gd

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
	# 等待编辑器完成启动与文件扫描，避免在资源导入期间退出。
	await create_timer(1.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var provider = DeepSeekSearch.new()
	root.add_child(provider)
	check((await provider.search("Godot")).has("error"), "Missing API key")
	provider.api_key = "test-key"
	check((await provider.search(" \t\n")).has("error"), "Whitespace query")
	check((await provider.search("字".repeat(129))).has("error"), "Overlong Unicode query")
	var query = 'Godot site:docs.godotengine.org lang:zh after:2025'
	var parsed = provider._parse_response(query, 200, JSON.stringify({"results": [
		{"title": "Godot", "url": "https://godotengine.org", "summary": "长摘要", "snippet": "短摘要", "site_name": null, "date": null, "authority": 3, "rerank_score": 2.4},
		{"summary": "", "snippet": "回退摘要", "site_name": "Docs"},
		{"summary": "字".repeat(800)},
		"invalid entry"
	]}))
	check(parsed.query == query, "Preserve query operators")
	check(parsed.results.size() == 3, "Skip malformed entries")
	check(parsed.results[0].content == "长摘要", "Prefer model summary")
	check(parsed.results[0].source == "deepseek", "Nullable site name")
	check(parsed.results[0].date == null and parsed.results[0].authority == 3 and parsed.results[0].rerank_score == 2.4, "Preserve metadata")
	check(parsed.results[1].content == "回退摘要", "Fallback to snippet")
	check(parsed.results[2].content.length() == 503, "Limit content size")
	check(provider._parse_response(query, 200, '{"results":[]}').results.is_empty(), "Empty results are successful")
	for invalid in ['null', '{}', '{"results":null}', '{"results":{}}', 'invalid json']:
		check(provider._parse_response(query, 200, invalid).has("error"), "Reject invalid response: " + invalid)
	for code in [400, 401, 402, 408, 429, 500, 504]:
		var error = provider._parse_response(query, code, '{"error":{"message":"test error"}}')
		check(error.error.contains(str(code)), "Report HTTP status %d" % code)
	check(provider._parse_response(query, 502, '<html>Bad gateway</html>').has("error"), "Non-JSON HTTP error")

	# 使用独立临时配置验证 UI 信号和保存，避免修改用户真实设置。
	var original_setting = AlphaAgentPlugin.global_setting
	var gs = AlphaAgentPlugin.GlobalSetting.new()
	gs.setting_file = "user://deepseek_search_test_settings.json"
	gs.search_provider = "deepseek"
	gs.search_deepseek_api_key = "saved-deepseek-key"
	gs.search_kimi_api_key = "saved-kimi-key"
	AlphaAgentPlugin.global_setting = gs
	var settings = load("res://addons/agent/ui/setting/setting.tscn").instantiate()
	root.add_child(settings)
	settings._init_search_config()
	var option = settings.get_node("%SearchProviderOption")
	var key_edit = settings.get_node("%SearchDeepSeekKeyEdit")
	check(option.get_item_text(option.selected) == "DeepSeek", "Restore DeepSeek selection")
	check(key_edit.text == gs.search_deepseek_api_key and key_edit.secret, "Restore masked key")
	check(key_edit.get_parent().visible and not settings.get_node("%SearchKimiKeyEdit").get_parent().visible, "Show matching key field")
	key_edit.text_changed.emit("changed-deepseek-key")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(gs.setting_file))
	check(saved.search_deepseek_api_key == "changed-deepseek-key" and saved.search_kimi_api_key == "saved-kimi-key", "Persist independent keys")
	option.select(1)
	option.item_selected.emit(1)
	check(gs.search_provider == "kimi" and not key_edit.get_parent().visible, "Existing provider selection")
	option.select(3)
	option.item_selected.emit(3)
	gs.search_deepseek_api_key = ""
	var tool = WebSearchTool.new()
	root.add_child(tool)
	var call = AgentModelUtils.ToolCallsInfo.new()
	call.function.arguments = JSON.stringify({"query": "Godot"})
	check((await tool.do_action(call)).error.contains("DeepSeek API Key"), "Tool dispatch reaches DeepSeek")
	call.function.arguments = '{"query":123}'
	check((await tool.do_action(call)).has("error"), "Reject non-string tool query")
	AlphaAgentPlugin.global_setting = original_setting
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.setting_file))
	settings.free()
	tool.free()
	provider.free()
	print("DeepSeek search: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

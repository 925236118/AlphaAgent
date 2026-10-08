@tool
class_name WebSearchTool
extends AgentToolBase

## 联网搜索 Tool
## AI 决定搜索关键字，调用搜索供应商 API，返回结构化结果

func _get_tool_name() -> String:
	return "web_search"

func _get_tool_short_description() -> String:
	return "联网搜索，获取互联网上的最新信息。"

func _get_tool_description() -> String:
	return "联网搜索工具。当需要获取互联网上的最新信息、新闻、技术文档或不确定的实时数据时使用。由你决定搜索关键字。返回搜索结果列表，包含标题、链接和摘要。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"query": {
				"type": "string",
				"description": "搜索关键字，用简洁明确的语言描述要搜索的内容。例如：'Godot 4 C# 使用方法' 或 '2026年最新AI模型对比'"
			},
			"scope": {
				"type": "string",
				"description": "搜索范围（仅知乎供应商支持）。zhihu=知乎站内搜索（默认），global=全网搜索",
				"enum": ["zhihu", "global"]
			}
		},
		"required": ["query"]
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var args = JSON.parse_string(tool_call.function.arguments)
	if args == null or not args is Dictionary:
		return {"error": "参数解析失败"}

	var query = args.get("query", "")
	if query.is_empty():
		return {"error": "搜索关键字不能为空"}

	var scope = args.get("scope", "zhihu")
	var gs = AlphaAgentPlugin.global_setting
	if gs.search_provider.is_empty():
		return {"error": "网络搜索未开启。请在设置面板的「搜索配置」中选择搜索供应商并配置相应的密钥。"}

	var result: Dictionary = {}
	var provider: SearchProviderBase = null
	match gs.search_provider:
		"kimi":
			provider = KimiSearch.new()
			provider.api_key = gs.search_kimi_api_key
			add_child(provider)
			result = await provider.search(query, 10)
		"zhihu":
			provider = ZhihuSearch.new()
			provider.access_secret = gs.search_zhihu_access_secret
			add_child(provider)
			if scope == "global":
				result = await provider.search_global(query, 10)
			else:
				result = await provider.search(query, 10)
		_:
			return {"error": "搜索供应商「%s」暂未实现" % gs.search_provider}

	if provider:
		provider.queue_free()
	return result

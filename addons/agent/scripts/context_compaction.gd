@tool
class_name AgentContextCompaction
extends RefCounted

const DEFAULT_CONTEXT_WINDOW := 128000
const DEFAULT_RESERVE_TOKENS := 4096
const DEFAULT_KEEP_RECENT_TOKENS := 20000
const CHARS_PER_TOKEN_ESTIMATE := 4

static func estimate_tokens(text: String) -> int:
	if text.is_empty():
		return 0
	return maxi(1, int(ceil(float(text.length()) / float(CHARS_PER_TOKEN_ESTIMATE))))

static func estimate_messages_tokens(messages: Array) -> int:
	var total := 0
	for msg in messages:
		if msg is Dictionary:
			total += estimate_message_tokens(msg)
	return total

static func estimate_message_tokens(msg: Dictionary) -> int:
	var total := estimate_tokens(str(msg.get("content", "")))
	total += estimate_tokens(str(msg.get("reasoning_content", "")))
	if msg.has("tool_calls") and msg["tool_calls"] is Array:
		for tool_call in msg["tool_calls"]:
			if tool_call is Dictionary:
				total += estimate_tokens(JSON.stringify(tool_call))
	return total

static func should_compact(messages: Array, context_window: int = DEFAULT_CONTEXT_WINDOW, reserve_tokens: int = DEFAULT_RESERVE_TOKENS) -> bool:
	var context_tokens := estimate_messages_tokens(messages)
	return context_tokens > maxi(0, context_window - reserve_tokens)

static func find_compaction_cut_index(messages: Array, keep_recent_tokens: int = DEFAULT_KEEP_RECENT_TOKENS) -> int:
	if messages.size() <= 2:
		return -1

	var accumulated := 0
	for i in range(messages.size() - 1, 0, -1):
		var msg = messages[i]
		if msg is Dictionary and str(msg.get("role", "")) == "system":
			continue
		accumulated += estimate_message_tokens(msg)
		if accumulated >= keep_recent_tokens:
			return i
	return 1

static func build_compaction_prompt(messages_to_summarize: Array) -> Array[Dictionary]:
	return [
		{
			"role": "system",
			"content": """\
你是一个对话摘要助手。请将以下对话历史压缩为简洁摘要，保留：
- 用户的核心目标与约束
- 已完成的关键操作与文件变更
- 当前进度与未解决问题
- 重要的技术决策

输出纯文本摘要，不要使用 markdown 标题。"""
		},
		{
			"role": "user",
			"content": JSON.stringify(messages_to_summarize)
		}
	]

static func apply_compaction(messages: Array, summary: String, cut_index: int) -> Array:
	if cut_index <= 0 or summary.strip_edges().is_empty():
		return messages

	var result: Array = []
	for i in range(messages.size()):
		var msg = messages[i]
		if i == 0 and msg is Dictionary and str(msg.get("role", "")) == "system":
			result.append(msg)
			break

	var compaction_note := {
		"role": "system",
		"content": "[上下文压缩摘要]\n" + summary.strip_edges()
	}
	result.append(compaction_note)

	for i in range(cut_index, messages.size()):
		result.append(messages[i])
	return result

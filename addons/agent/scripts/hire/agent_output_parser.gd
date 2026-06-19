@tool
@abstract
class_name AgentOutputParser
extends RefCounted

## Agent 输出解析器 — 抽象基类
## CCOutputParser / PiOutputParser 的公共接口
## 负责将 Agent 特有的 JSON 输出映射为统一事件格式

## 解析一行原始输出，返回原始事件 Dictionary
@abstract
func parse(raw_line: String) -> Dictionary

## 将 Agent 特有事件映射为统一事件格式
## 统一事件类型: agent_started | agent_finished | text_delta |
##                tool_started | tool_updated | tool_finished | error | empty
@abstract
func map_to_unified(raw_event: Dictionary) -> Dictionary

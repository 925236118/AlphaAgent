@tool
class_name AgentModelUtils
extends RefCounted

class ToolCallsInfo:
	var id: String = ""
	var function: ToolCallsInfoFunc = ToolCallsInfoFunc.new()
	var type: String = "function"
	func to_dict():
		return {
			"id": id,
			"type": type,
			"function": function.to_dict()
		}

class ToolCallsInfoFunc:
	var name: String = ""
	var arguments: String = ""

	func to_dict():
		return {
			"name": name,
			"arguments": arguments
		}

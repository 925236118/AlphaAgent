@tool
class_name AgentConfig
extends Resource

@export var alpha_version: String = ""
@export_multiline var system_prompt = ""
@export var memory: Array[String] = []

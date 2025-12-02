@tool
class_name AgentConfig
extends Resource

@export var secret_key = ""
@export_multiline var system_prompt = ""
@export var memory: Array[String] = []

@export var settings: Dictionary = {}

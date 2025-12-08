@tool
extends VBoxContainer

@onready var global_memory_container: VBoxContainer = %GlobalMemoryContainer
@onready var global_memory_item_container: VBoxContainer = %GlobalMemoryItemContainer
@onready var project_memory_container: VBoxContainer = %ProjectMemoryContainer
@onready var project_memory_item_container: VBoxContainer = %ProjectMemoryItemContainer
@onready var add_global_memory: Button = %AddGlobalMemory
@onready var add_project_memory: Button = %AddProjectMemory

var memory_dir = EditorInterface.get_editor_paths().get_config_dir() + "/.alpha/"
var memory_file: String = memory_dir + "memory.json"

const MEMORY_ITEM = preload("uid://cr2sav6by4tal")

func _ready() -> void:
	load_from_project()
	visibility_changed.connect(on_visibility_changed)
	add_global_memory.pressed.connect(on_add_global_memory)
	add_project_memory.pressed.connect(on_add_project_memory)
func on_visibility_changed():
	if visible:
		add_memory_nodes()
	else:
		clear_memory_nodes()

func load_from_project():
	var CONFIG := load("uid://b4bcww0bmnxt0") as AgentConfig
	var memory = CONFIG.memory
	await get_tree().physics_frame
	AlphaAgentPlugin.instance.project_memory = memory

func load_from_global():
	if not DirAccess.dir_exists_absolute(memory_dir):
		DirAccess.make_dir_absolute(memory_dir)

	var memory_string = FileAccess.get_file_as_string(memory_file)
	if FileAccess.get_open_error() != OK:
		memory_string = ""

	var json = []
	if memory_string != "":
		json = JSON.parse_string(memory_string)
	
	await get_tree().physics_frame
	AlphaAgentPlugin.instance.global_memory = json as Array[String]

func add_memory_nodes():
	for i in AlphaAgentPlugin.instance.global_memory.size():
		var global_memory = AlphaAgentPlugin.instance.global_memory[i]
		var item = MEMORY_ITEM.instantiate()
		global_memory_item_container.add_child(item)
		item.set_text(global_memory)
		item.remove.connect(on_remove_global_memory.bind(item))
		item.save.connect(on_save_global_memory.bind(item))
		
	for i in AlphaAgentPlugin.instance.project_memory.size():
		var project_memory = AlphaAgentPlugin.instance.project_memory[i]
		var item = MEMORY_ITEM.instantiate()
		project_memory_item_container.add_child(item)
		item.set_text(project_memory)
		item.remove.connect(on_remove_project_memory.bind(item))
		item.save.connect(on_save_project_memory.bind(item))

func on_remove_global_memory(node: Control):
	var index = node.get_index()
	AlphaAgentPlugin.instance.global_memory.remove_at(index)
	node.queue_free()
	save_global_memory_file()

func save_global_memory_file():
	var file = FileAccess.open(memory_file, FileAccess.WRITE)
	file.store_string(JSON.stringify(AlphaAgentPlugin.instance.global_memory))
	file.close()

func on_remove_project_memory(node: Control):
	var index = node.get_index()
	AlphaAgentPlugin.instance.project_memory.remove_at(index)
	node.queue_free()
	save_project_memory_file()

func save_project_memory_file():
	var CONFIG := load("uid://b4bcww0bmnxt0") as AgentConfig
	CONFIG.memory = AlphaAgentPlugin.instance.project_memory
	ResourceSaver.save(CONFIG, "uid://b4bcww0bmnxt0")

func on_save_global_memory(content, item: Control):
	var index = item.get_index()
	AlphaAgentPlugin.instance.global_memory[index] = content
	save_global_memory_file()
	
func on_save_project_memory(content, item: Control):
	var index = item.get_index()
	AlphaAgentPlugin.instance.project_memory[index] = content
	save_project_memory_file()

func clear_memory_nodes():
	var global_memory_item_count = global_memory_item_container.get_child_count()
	for i in global_memory_item_count:
		global_memory_item_container.get_child(global_memory_item_count - 1 - i).queue_free()
	var project_memory_item_count = project_memory_item_container.get_child_count()
	for i in project_memory_item_count:
		project_memory_item_container.get_child(project_memory_item_count - 1 - i).queue_free()

func on_add_global_memory():
	var item := MEMORY_ITEM.instantiate() as AgentMemoryItem
	global_memory_item_container.add_child(item)
	AlphaAgentPlugin.instance.global_memory.push_back("")
	item.set_text("")
	item.set_state(AgentMemoryItem.State.Edit)
	item.remove.connect(on_remove_global_memory.bind(item))
	item.save.connect(on_save_global_memory.bind(item))

func on_add_project_memory():
	var item = MEMORY_ITEM.instantiate()
	project_memory_item_container.add_child(item)
	AlphaAgentPlugin.instance.project_memory.push_back("")
	item.set_text("")
	item.set_state(AgentMemoryItem.State.Edit)
	item.remove.connect(on_remove_project_memory.bind(item))
	item.save.connect(on_save_project_memory.bind(item))

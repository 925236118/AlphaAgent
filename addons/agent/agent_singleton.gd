@tool
class_name AlphaAgentSingleton
extends RefCounted

# 单例实例
static var instance: AlphaAgentSingleton = null

# PlanState 枚举（用于计划列表）
enum PlanState {
	Plan,
	Active,
	Finish
}

# PlanItem 类（用于计划列表）
class PlanItem:
	var name: String = ""
	var state: PlanState = PlanState.Plan
	func _init(name: String, state: PlanState) -> void:
		self.name = name
		self.state = state

# 信号定义
signal update_plan_list(plan_list: Array[PlanItem])
signal models_changed
signal roles_changed

# 主面板引用
var main_panel: AgentMainPanel = null

# EditorPlugin 引用（如果可用）
var editor_plugin: EditorPlugin = null

# 查找标志，避免重复查找
var _has_tried_find_main_panel: bool = false

# 获取单例实例
static func get_instance() -> AlphaAgentSingleton:
	if instance == null:
		instance = AlphaAgentSingleton.new()
		# 如果场景树中已存在 main_panel，自动添加引用（只尝试一次）
		instance._try_find_main_panel_in_scene_tree()
		
	return instance

# 尝试在场景树中查找 main_panel（用于编辑器测试环境）
func _try_find_main_panel_in_scene_tree() -> void:
	if main_panel != null:
		return  # 已经设置了，不需要查找
	
	if _has_tried_find_main_panel:
		return  # 已经尝试过查找，避免重复查找
	
	_has_tried_find_main_panel = true
	
	var scene_tree = get_scene_tree()
	if scene_tree == null:
		return
	
	var root = scene_tree.root
	if root == null:
		return
	
	# 递归查找 AgentMainPanel 节点
	var found_panel = _find_main_panel_recursive(root)
	if found_panel != null:
		main_panel = found_panel

# 递归查找 AgentMainPanel 节点
func _find_main_panel_recursive(node: Node) -> AgentMainPanel:
	if node is AgentMainPanel:
		return node as AgentMainPanel
	
	for child in node.get_children():
		var result = _find_main_panel_recursive(child)
		if result != null:
			return result
	
	return null

# 设置主面板
func set_main_panel(panel: AgentMainPanel) -> void:
	main_panel = panel
	if panel != null:
		_has_tried_find_main_panel = true  # 已设置，标记为已查找

# 设置 EditorPlugin（用于需要 EditorPlugin 功能时）
func set_editor_plugin(plugin: EditorPlugin) -> void:
	editor_plugin = plugin

# 添加自动加载单例（代理到 EditorPlugin）
func add_autoload_singleton(name: String, path: String) -> void:
	if editor_plugin != null:
		editor_plugin.add_autoload_singleton(name, path)
	else:
		push_warning("EditorPlugin 不可用，无法添加自动加载单例: " + name)

# 移除自动加载单例（代理到 EditorPlugin）
func remove_autoload_singleton(name: String) -> void:
	if editor_plugin != null:
		editor_plugin.remove_autoload_singleton(name)
	else:
		push_warning("EditorPlugin 不可用，无法移除自动加载单例: " + name)

# 获取场景树（优先使用 main_panel 的场景树，否则使用主循环）
func get_scene_tree() -> SceneTree:
	if main_panel != null:
		var tree = main_panel.get_tree()
		if tree != null:
			return tree
	
	var main_loop = Engine.get_main_loop()
	if main_loop != null:
		var scene_tree = main_loop as SceneTree
		if scene_tree != null:
			return scene_tree
	
	return null

# 等待场景树可用并等待一帧（统一处理，兼容插件和编辑器环境）
func wait_for_scene_tree_frame() -> void:
	# 优先使用 main_panel 的场景树
	if main_panel != null:
		var tree = main_panel.get_tree()
		if tree != null:
			await tree.process_frame
			return
	
	# 如果 main_panel 的场景树不可用，使用主循环的场景树
	var main_loop = Engine.get_main_loop()
	if main_loop == null:
		push_warning("无法获取主循环，跳过等待帧")
		return
	
	var scene_tree = main_loop as SceneTree
	if scene_tree != null:
		await scene_tree.process_frame
		return
	
	# 如果主循环不是 SceneTree（在编辑器脚本中可能出现），使用定时器等待
	# 这种情况很少见，但为了兼容性保留
	var timer = main_loop.create_timer(0.016)  # 约一帧的时间（60fps）
	if timer != null:
		await timer.timeout
	else:
		push_warning("无法创建定时器，跳过等待帧")

@tool
class_name AgentRoleConfig
extends Node

const WORKFLOW_PROMPT = """## 三阶段工作流

### 阶段一：分析问题

[b]声明格式[/b]：`【分析问题】`

[b]目的[/b]
因为可能存在多个可选方案，要做出正确的决策，需要足够的依据。

[b]必须做的事[/b]：
- 理解我的意图，如果有歧义请问我
- 搜索所有相关代码
- 识别问题根因

[b]主动发现问题[/b]
- 发现重复代码
- 识别不合理的命名
- 发现多余的代码、类
- 发现可能过时的设计
- 发现过于复杂的设计、调用
- 发现不一致的类型定义
- 进一步搜索代码，看是否更大范围内有类似问题

做完以上事项，就可以向我提问了。

[b]绝对禁止[/b]：
- ❌ 修改任何代码
- ❌ 急于给出解决方案
- ❌ 跳过搜索和理解步骤
- ❌ 不分析就推荐方案

[b]阶段转换规则[/b]
本阶段你要向我提问。
如果存在多个你无法抉择的方案，要问我，作为提问的一部分。
如果没有需要问我的，则直接进入下一阶段。

### 阶段二：制定方案
[b]声明格式[/b]：`【制定方案】`

[b]前置条件[/b]：
- 我明确回答了关键技术决策。

[b]必须做的事[/b]：
- 列出变更（新增、修改、删除）的文件，简要描述每个文件的变化
- 消除重复逻辑：如果发现重复代码，必须通过复用或抽象来消除
- 确保修改后的代码符合DRY原则和良好的架构设计

如果新发现了向我收集的关键决策，在这个阶段你还可以继续问我，直到没有不明确的问题之后，本阶段结束。
本阶段不允许自动切换到下一阶段。

### 阶段三：执行方案
[b]声明格式[/b]：`【执行方案】`

[b]必须做的事[/b]：
- 严格按照选定方案实现
- 修改后运行类型检查

[b]绝对禁止[/b]：
- ❌ 提交代码（除非用户明确要求）
- 启动开发服务器

如果在这个阶段发现了拿不准的问题，请向我提问。

收到用户消息时，一般从【分析问题】阶段开始，除非用户明确指定阶段的名字。
"""

class RoleInfo:
	var id: String = ""
	var name: String = ""
	var prompt: String = ""
	var tools: Array = []

	func _init(p_name: String = "", p_prompt: String = "", p_tools: Array = []):
		id = _generate_id()
		name = p_name
		prompt = p_prompt
		tools = p_tools

	func _generate_id() -> String:
		return str(Time.get_unix_time_from_system()) + "_" + str(randi())

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"prompt": prompt,
			"tools": tools
		}
	static func from_dict(data: Dictionary) -> RoleInfo:
		var info = RoleInfo.new()
		info.id = data.get("id", "")
		info.name = data.get("name", "")
		info.prompt = data.get("prompt", "")
		info.tools = data.get("tools", [])
		return info

class RoleManager:
	var roles: Array = []
	var config_file: String = ""
	var current_role_id: String = ""

	func _init(p_config_file: String):
		config_file = p_config_file
		_ensure_config_dir()
		load_roles()

		# 如果没有角色，添加默认的角色
		if roles.is_empty():
			add_default_roles()

	func _ensure_config_dir():
		var dir_path = config_file.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)

	func load_roles():
		var file_content = FileAccess.get_file_as_string(config_file)
		if FileAccess.get_open_error() != OK:
			return
		var json = JSON.parse_string(file_content)
		if json == null:
			return
		current_role_id = json.get("current_role_id", "")
		roles = json.get("roles", []).map(func(r: Dictionary): return RoleInfo.from_dict(r))

	func add_default_roles():
		# 使用单例，等待 main_panel 初始化
		var singleton = AlphaAgentSingleton.get_instance()

		# 等待 main_panel 初始化（在 _enter_tree 中创建）
		var max_wait_time = 10.0
		var elapsed_time = 0.0
		var start_time = Time.get_ticks_msec()

		while singleton.main_panel == null:
			await AlphaAgentPlugin.wait_for_scene_tree_frame()
			elapsed_time = (Time.get_ticks_msec() - start_time) / 1000.0
			if elapsed_time >= max_wait_time:
				push_error("等待 main_panel 初始化超时")
				return

		# 等待一帧，确保工具列表已加载
		await AlphaAgentPlugin.wait_for_scene_tree_frame()

		# 缓存工具列表，避免重复调用
		var tools_dict = singleton.main_panel.tools.get_function_name_list()
		var tools_keys = tools_dict.keys()

		# 添加默认角色
		var default_role = RoleInfo.new()
		default_role.name = "默认角色"
		default_role.prompt = ""
		default_role.tools = tools_keys
		roles.append(default_role)

		# 添加只读角色
		var readonly_role = RoleInfo.new()
		readonly_role.name = "只读角色"
		readonly_role.prompt = "你只能使用只读的工具。无法编辑、修改、删除项目内容或文件。"
		readonly_role.tools = tools_keys.filter(func(key): return tools_dict[key].readonly)
		roles.append(readonly_role)

		# 添加工作流角色
		var workflow_role = RoleInfo.new()
		workflow_role.name = "工作流"
		workflow_role.prompt = WORKFLOW_PROMPT
		workflow_role.tools = tools_keys
		roles.append(workflow_role)

		# 设置默认角色为当前角色
		current_role_id = default_role.id

		save_datas()


	func save_datas():
		var data = {
			"current_role_id": current_role_id,
			"roles": roles.map(func(r): return r.to_dict())
		}
		var file = FileAccess.open(config_file, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(data, "\t"))
			file.close()

	func get_current_role() -> RoleInfo:
		for role in roles:
			if role.id == current_role_id:
				return role
		return null

	func get_role_by_id(role_id: String) -> RoleInfo:
		for role in roles:
			if role.id == role_id:
				return role
		return null

	func add_role(role: RoleInfo):
		roles.append(role)
		save_datas()

	func remove_role(role: RoleInfo):
		roles.remove_at(roles.find(role))
		save_datas()

	func update_role(role: RoleInfo):
		var old_role = get_role_by_id(role.id)
		old_role.name = role.name
		old_role.prompt = role.prompt
		old_role.tools = role.tools
		save_datas()

	func set_current_role(role_id: String):
		current_role_id = role_id
		save_datas()

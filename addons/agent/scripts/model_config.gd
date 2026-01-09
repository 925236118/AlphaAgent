@tool
class_name ModelConfig
extends RefCounted

## 模型配置管理类，用于管理多个AI模型的配置

class SupplierInfo:
	var id: String = ""
	var name: String = ""
	var base_url: String = ""
	var api_key: String = ""
	var provider: String = "openai"  # 提供商类型: openai, deepseek, ollama
	var models: Array = []

	func _init(s_id: String = "", s_name: String = "", s_api_base: String = "",
			   s_api_key: String = ""):
		id = s_id if s_id != "" else _generate_id()
		name = s_name
		base_url = s_api_base
		api_key = s_api_key
		models = []

	func _generate_id() -> String:
		return str(Time.get_unix_time_from_system()) + "_" + str(randi())

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"base_url": base_url,
			"api_key": api_key,
			"provider": provider,
			"models": models.map(func(m: ModelInfo): return m.to_dict())
		}

	static func from_dict(data: Dictionary) -> SupplierInfo:
		var info = SupplierInfo.new()
		info.id = data.get("id", "")
		info.name = data.get("name", "")
		info.base_url = data.get("base_url", "")
		info.api_key = data.get("api_key", "")
		info.provider = data.get("provider", "")
		info.models = data.models.map(func(m: Dictionary): return ModelInfo.from_dict(m))
		return info

## 单个模型的配置信息
class ModelInfo:
	var id: String = ""  # 唯一标识符
	var name: String = ""  # 显示名称
	var model_name: String = ""  # 模型名称（如: gpt-4, deepseek-chat）
	var supports_thinking: bool = false  # 是否支持深度思考
	var supports_tools: bool = true  # 是否支持工具调用
	var max_tokens: int = 8192  # 最大token数
	var active: bool = false  # 是否激活
	var supplier_id: String = ""  # 所属供应商ID

	func _init(p_id: String = "", p_name: String= "", p_model_name: String = "", p_active: bool = true):
		id = p_id if p_id != "" else _generate_id()
		name = p_name
		model_name = p_model_name
		active = p_active

	func _generate_id() -> String:
		return str(Time.get_unix_time_from_system()) + "_" + str(randi())

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"model_name": model_name,
			"supports_thinking": supports_thinking,
			"supports_tools": supports_tools,
			"max_tokens": max_tokens,
			"active": active,
			"supplier_id": supplier_id
		}

	static func from_dict(data: Dictionary) -> ModelInfo:
		var info = ModelInfo.new()
		info.id = data.get("id", "")
		info.name = data.get("name", "")
		info.model_name = data.get("model_name", "")
		info.supports_thinking = data.get("supports_thinking", false)
		info.supports_tools = data.get("supports_tools", true)
		info.max_tokens = data.get("max_tokens", 8192)
		info.active = data.get("active", false)
		info.supplier_id = data.get("supplier_id", "")
		return info

## 模型配置管理器
class ModelManager:
	var suppliers: Array[SupplierInfo] = []
	var current_supplier_id: String = ""
	var current_model_id: String = ""
	var config_file: String = ""

	func _init(p_config_file: String):
		config_file = p_config_file
		_ensure_config_dir()
		load_models()

		# 如果没有模型，添加默认的DeepSeek模型
		if suppliers.is_empty():
			add_default_suppliers()

	func _ensure_config_dir():
		var dir_path = config_file.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)

	func clear_all_supplier():
		suppliers = []
		save_datas()

	func add_default_suppliers():
		# 添加默认DeepSeek供应商
		var deepseek_supplier = SupplierInfo.new()
		deepseek_supplier.name = "DeepSeek"
		deepseek_supplier.base_url = "https://api.deepseek.com"
		deepseek_supplier.api_key = ""
		deepseek_supplier.provider = "deepseek"
		suppliers.append(deepseek_supplier)

		var chat_model = ModelInfo.new()
		chat_model.name = "DeepSeek Chat"
		chat_model.model_name = "deepseek-chat"
		chat_model.supports_thinking = false
		chat_model.supports_tools = true
		chat_model.max_tokens = 8 * 1024
		chat_model.active = false
		chat_model.supplier_id = deepseek_supplier.id
		deepseek_supplier.models.append(chat_model)

		var reasoner_model = ModelInfo.new()
		reasoner_model.name = "DeepSeek Reasoner"
		reasoner_model.model_name = "deepseek-reasoner"
		reasoner_model.supports_thinking = true
		reasoner_model.supports_tools = true
		reasoner_model.max_tokens = 64 * 1024
		reasoner_model.active = false
		reasoner_model.supplier_id = deepseek_supplier.id
		deepseek_supplier.models.append(reasoner_model)

		current_supplier_id = deepseek_supplier.id
		current_model_id = reasoner_model.id

		# 添加默认MoonShot供应商
		var moonshot_supplier = SupplierInfo.new()
		moonshot_supplier.name = "MoonShot"
		moonshot_supplier.base_url = "https://api.moonshot.cn"
		moonshot_supplier.api_key = ""
		moonshot_supplier.provider = "openai"
		suppliers.append(moonshot_supplier)

		var kimi_k2_turbo_preview_model = ModelInfo.new()
		kimi_k2_turbo_preview_model.name = "Kimi K2 Turbo Preview"
		kimi_k2_turbo_preview_model.model_name = "kimi-k2-turbo-preview"
		kimi_k2_turbo_preview_model.supports_thinking = false
		kimi_k2_turbo_preview_model.supports_tools = true
		kimi_k2_turbo_preview_model.max_tokens = 8 * 1024
		kimi_k2_turbo_preview_model.active = false
		kimi_k2_turbo_preview_model.supplier_id = moonshot_supplier.id
		moonshot_supplier.models.append(kimi_k2_turbo_preview_model)

		var kimi_k2_0905_preview_model = ModelInfo.new()
		kimi_k2_0905_preview_model.name = "Kimi K2 0905 Preview"
		kimi_k2_0905_preview_model.model_name = "kimi-k2-0905-preview"
		kimi_k2_0905_preview_model.supports_thinking = false
		kimi_k2_0905_preview_model.supports_tools = true
		kimi_k2_0905_preview_model.max_tokens = 8 * 1024
		kimi_k2_0905_preview_model.active = false
		kimi_k2_0905_preview_model.supplier_id = moonshot_supplier.id
		moonshot_supplier.models.append(kimi_k2_0905_preview_model)

		var kimi_k2_thinking_model = ModelInfo.new()
		kimi_k2_thinking_model.name = "Kimi K2 Thinking"
		kimi_k2_thinking_model.model_name = "kimi-k2-thinking"
		kimi_k2_thinking_model.supports_thinking = true
		kimi_k2_thinking_model.supports_tools = true
		kimi_k2_thinking_model.max_tokens = 64 * 1024
		kimi_k2_thinking_model.active = false
		kimi_k2_thinking_model.supplier_id = moonshot_supplier.id
		moonshot_supplier.models.append(kimi_k2_thinking_model)

		var kimi_k2_thinking_turbo_model = ModelInfo.new()
		kimi_k2_thinking_turbo_model.name = "Kimi K2 Thinking Turbo"
		kimi_k2_thinking_turbo_model.model_name = "kimi-k2-thinking-turbo"
		kimi_k2_thinking_turbo_model.supports_thinking = true
		kimi_k2_thinking_turbo_model.supports_tools = true
		kimi_k2_thinking_turbo_model.max_tokens = 64 * 1024
		kimi_k2_thinking_turbo_model.active = false
		kimi_k2_thinking_turbo_model.supplier_id = moonshot_supplier.id
		moonshot_supplier.models.append(kimi_k2_thinking_turbo_model)

		# 添加默认硅基流动供应商
		var siliconflow_supplier = SupplierInfo.new()
		siliconflow_supplier.name = "硅基流动"
		siliconflow_supplier.base_url = "https://api.siliconflow.cn"
		siliconflow_supplier.api_key = ""
		siliconflow_supplier.provider = "openai"
		suppliers.append(siliconflow_supplier)

		var deepseek_v3_2_model = ModelInfo.new()
		deepseek_v3_2_model.name = "DeepSeek-V3.2"
		deepseek_v3_2_model.model_name = "deepseek-ai/DeepSeek-V3.2"
		deepseek_v3_2_model.supports_thinking = false
		deepseek_v3_2_model.supports_tools = true
		deepseek_v3_2_model.max_tokens = 64 * 1024
		deepseek_v3_2_model.active = false
		deepseek_v3_2_model.supplier_id = siliconflow_supplier.id
		siliconflow_supplier.models.append(deepseek_v3_2_model)

		var qwen_next_80b_a3b_thinking = ModelInfo.new()
		qwen_next_80b_a3b_thinking.name = "Qwen3 Next 80B A3B Thinking"
		qwen_next_80b_a3b_thinking.model_name = "Qwen/Qwen3-Next-80B-A3B-Thinking"
		qwen_next_80b_a3b_thinking.supports_thinking = true
		qwen_next_80b_a3b_thinking.supports_tools = true
		qwen_next_80b_a3b_thinking.max_tokens = 64 * 1024
		qwen_next_80b_a3b_thinking.active = false
		qwen_next_80b_a3b_thinking.supplier_id = siliconflow_supplier.id
		siliconflow_supplier.models.append(qwen_next_80b_a3b_thinking)

		# 添加默认OpenRouter供应商
		var openrouter_supplier = SupplierInfo.new()
		openrouter_supplier.name = "Open Router"
		openrouter_supplier.base_url = "https://openrouter.ai/api"
		openrouter_supplier.api_key = ""
		openrouter_supplier.provider = "openai"
		suppliers.append(openrouter_supplier)

		var claude_sonnet_4_5 = ModelInfo.new()
		claude_sonnet_4_5.name = "claude-sonnet-4.5"
		claude_sonnet_4_5.model_name = "anthropic/claude-sonnet-4.5"
		claude_sonnet_4_5.supports_thinking = false
		claude_sonnet_4_5.supports_tools = true
		claude_sonnet_4_5.max_tokens = 64 * 1024
		claude_sonnet_4_5.active = false
		claude_sonnet_4_5.supplier_id = openrouter_supplier.id
		openrouter_supplier.models.append(claude_sonnet_4_5)

		# 添加默认OpenAI供应商
		var openai_supplier = SupplierInfo.new()
		openai_supplier.name = "OPEN AI"
		openai_supplier.base_url = "https://api.openai.com"
		openai_supplier.api_key = ""
		openai_supplier.provider = "openai"
		suppliers.append(openai_supplier)

		# 添加默认硅基流动供应商
		var ollama_supplier = SupplierInfo.new()
		ollama_supplier.name = "Ollama"
		ollama_supplier.base_url = "http://localhost:11434"
		ollama_supplier.api_key = ""
		ollama_supplier.provider = "ollama"
		suppliers.append(ollama_supplier)

		save_datas()


	func load_models():
		var file_content = FileAccess.get_file_as_string(config_file)
		if FileAccess.get_open_error() != OK:
			return

		var json = JSON.parse_string(file_content)
		if json == null:
			return

		current_model_id = json.get("current_model_id", "")
		current_supplier_id = json.get("current_supplier_id", "")
		var suppliers_data = json.get("supplier", [])

		suppliers.clear()
		for supplier_data in suppliers_data:
			suppliers.append(SupplierInfo.from_dict(supplier_data))

	func save_datas():
		var data = {
			"current_supplier_id": current_supplier_id,
			"current_model_id": current_model_id,
			"supplier": suppliers.map(func(m): return m.to_dict())
		}

		var file = FileAccess.open(config_file, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(data, "\t"))
			file.close()

	func get_current_supplier() -> SupplierInfo:
		for supplier in suppliers:
			if supplier.id == current_supplier_id:
				return supplier
		return null

	func get_supplier_by_id(supplier_id: String) -> SupplierInfo:
		for supplier in suppliers:
			if supplier.id == supplier_id:
				return supplier
		return null

	func get_current_model() -> ModelInfo:
		var current_supplier_info = get_current_supplier()

		if not current_supplier_info == null:
			for model in current_supplier_info.models:
				if model.id == current_model_id:
					return model
		# 如果没有找到当前模型，返回第一个
		else:
			current_supplier_id = suppliers[0].id
			current_model_id = suppliers[0].models[0].id
			return suppliers[0].models[0]

		return null

	func set_current_model(supplier_id: String, model_id: String):
		current_supplier_id = supplier_id
		current_model_id = model_id
		save_datas()

	func add_model(supplier_id: String, model: ModelInfo):
		get_supplier_by_id(supplier_id).models.append(model)
		save_datas()

	func update_model(supplier_id: String, model_id: String, updated_model: ModelInfo):
		var supplier = get_supplier_by_id(supplier_id)
		for i in supplier.models.size():
			var model = supplier.models[i]
			if model.id == model_id:
				supplier.models[i] = updated_model
				save_datas()
				return

	func update_supplier(supplier_id: String, supplier: SupplierInfo):
		var old_supplier = get_supplier_by_id(supplier_id)
		old_supplier.name = supplier.name
		old_supplier.base_url = supplier.base_url
		old_supplier.api_key = supplier.api_key
		old_supplier.provider = supplier.provider
		save_datas()

	func remove_model(supplier_id: String, model_id: String):
		var supplier = get_supplier_by_id(supplier_id)
		for i in supplier.models.size():
			var model = supplier.models[i]
			if model.id == model_id:
				supplier.models.remove_at(i)
				# 如果删除的是当前模型，切换到第一个
				if current_model_id == model_id and not supplier.models.is_empty():
					current_model_id = supplier.models[0].id
				save_datas()
				return

	func get_model_by_id(model_id: String) -> ModelInfo:
		for supplier in suppliers:
			for model in supplier.models:
				if model.id == model_id:
					return model
		return null
	func add_supplier(supplier: SupplierInfo):
		suppliers.append(supplier)
		save_datas()

	func remove_supplier(supplier: SupplierInfo):
		suppliers.remove_at(suppliers.find(supplier))
		save_datas()

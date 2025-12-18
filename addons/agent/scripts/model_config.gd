@tool
class_name ModelConfig
extends RefCounted

## 模型配置管理类，用于管理多个AI模型的配置

class SupplierInfo:
	var id: String = ""
	var name: String = ""
	var base_url: String = ""
	var api_key: String = ""
	var provider: String = "deepseek"  # 提供商类型: openai, deepseek, ollama
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

	func add_default_suppliers():
		# 添加默认DeepSeek供应商
		var supplier = SupplierInfo.new()
		supplier.name = "DeepSeek"
		supplier.base_url = "https://api.deepseek.com"
		supplier.api_key = ""
		supplier.provider = "openai"
		suppliers.append(supplier)

		var chat_model = ModelInfo.new()
		chat_model.name = "DeepSeek Chat"
		chat_model.model_name = "deepseek-chat"
		chat_model.supports_thinking = false
		chat_model.supports_tools = true
		chat_model.max_tokens = 8 * 1024
		chat_model.active = false
		chat_model.supplier_id = supplier.id
		supplier.models.append(chat_model)

		var reasoner_model = ModelInfo.new()
		reasoner_model.name = "DeepSeek Reasoner"
		reasoner_model.model_name = "deepseek-reasoner"
		reasoner_model.supports_thinking = true
		reasoner_model.supports_tools = true
		reasoner_model.max_tokens = 64 * 1024
		reasoner_model.active = false
		reasoner_model.supplier_id = supplier.id
		supplier.models.append(reasoner_model)

		current_supplier_id = supplier.id
		current_model_id = reasoner_model.id

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

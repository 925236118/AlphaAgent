@tool
class_name ModelConfig
extends RefCounted

## 模型配置管理类，用于管理多个AI模型的配置

## 单个模型的配置信息
class ModelInfo:
	var id: String = ""  # 唯一标识符
	var name: String = ""  # 显示名称
	var api_base: String = ""  # API基础URL
	var api_key: String = ""  # API密钥
	var model_name: String = ""  # 模型名称（如: gpt-4, deepseek-chat）
	var supports_thinking: bool = false  # 是否支持深度思考
	var supports_tools: bool = true  # 是否支持工具调用
	var max_tokens: int = 8192  # 最大token数
	var provider: String = "openai"  # 提供商类型: openai, deepseek, ollama

	func _init(p_id: String = "", p_name: String = "", p_api_base: String = "",
			   p_api_key: String = "", p_model_name: String = ""):
		id = p_id if p_id != "" else _generate_id()
		name = p_name
		api_base = p_api_base
		api_key = p_api_key
		model_name = p_model_name

	func _generate_id() -> String:
		return str(Time.get_unix_time_from_system()) + "_" + str(randi())

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"api_base": api_base,
			"api_key": api_key,
			"model_name": model_name,
			"supports_thinking": supports_thinking,
			"supports_tools": supports_tools,
			"max_tokens": max_tokens,
			"provider": provider
		}

	static func from_dict(data: Dictionary) -> ModelInfo:
		var info = ModelInfo.new()
		info.id = data.get("id", "")
		info.name = data.get("name", "")
		info.api_base = data.get("api_base", "")
		info.api_key = data.get("api_key", "")
		info.model_name = data.get("model_name", "")
		info.supports_thinking = data.get("supports_thinking", false)
		info.supports_tools = data.get("supports_tools", true)
		info.max_tokens = data.get("max_tokens", 8192)
		info.provider = data.get("provider", "openai")
		return info
		info.supports_tools = data.get("supports_tools", true)
		info.max_tokens = data.get("max_tokens", 8192)
		info.provider = data.get("provider", "openai")
		return info

## 模型配置管理器
class ModelManager:
	var models: Array[ModelInfo] = []
	var current_model_id: String = ""
	var config_file: String = ""

	func _init(p_config_file: String):
		config_file = p_config_file
		_ensure_config_dir()
		load_models()

		# 如果没有模型，添加默认的DeepSeek模型
		if models.is_empty():
			add_default_models()

	func _ensure_config_dir():
		var dir_path = config_file.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)

	func add_default_models():
		# 添加 DeepSeek Chat (非思考模式的 DeepSeek-V3.2)
		# 使用 OpenAI 兼容接口
		var deepseek = ModelInfo.new()
		deepseek.name = "DeepSeek Chat"
		deepseek.api_base = "https://api.deepseek.com"
		deepseek.api_key = ""  # 用户需要自己配置
		deepseek.model_name = "deepseek-chat"
		deepseek.supports_thinking = false
		deepseek.supports_tools = true
		deepseek.max_tokens = 8192
		deepseek.provider = "openai"  # 使用 OpenAI 兼容实现
		models.append(deepseek)

		# 添加 DeepSeek Reasoner (思考模式的 DeepSeek-V3.2)
		# 使用 OpenAI 兼容接口
		var reasoner = ModelInfo.new()
		reasoner.name = "DeepSeek Reasoner"
		reasoner.api_base = "https://api.deepseek.com"
		reasoner.api_key = ""  # 用户需要自己配置
		reasoner.model_name = "deepseek-reasoner"
		reasoner.supports_thinking = true
		reasoner.supports_tools = false  # reasoner 模式不支持工具调用
		reasoner.max_tokens = 8192
		reasoner.provider = "openai"  # 使用 OpenAI 兼容实现
		models.append(reasoner)

		current_model_id = deepseek.id
		save_models()

	func load_models():
		var file_content = FileAccess.get_file_as_string(config_file)
		if FileAccess.get_open_error() != OK:
			return

		var json = JSON.parse_string(file_content)
		if json == null:
			return

		current_model_id = json.get("current_model_id", "")
		var models_data = json.get("models", [])

		models.clear()
		for model_data in models_data:
			models.append(ModelInfo.from_dict(model_data))

	func save_models():
		var data = {
			"current_model_id": current_model_id,
			"models": models.map(func(m): return m.to_dict())
		}

		var file = FileAccess.open(config_file, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(data, "\t"))
			file.close()

	func get_current_model() -> ModelInfo:
		for model in models:
			if model.id == current_model_id:
				return model

		# 如果没有找到当前模型，返回第一个
		if not models.is_empty():
			current_model_id = models[0].id
			return models[0]

		return null

	func set_current_model(model_id: String):
		current_model_id = model_id
		save_models()

	func add_model(model: ModelInfo):
		models.append(model)
		save_models()

	func update_model(model_id: String, updated_model: ModelInfo):
		for i in range(models.size()):
			if models[i].id == model_id:
				updated_model.id = model_id  # 保持ID不变
				models[i] = updated_model
				save_models()
				return

	func remove_model(model_id: String):
		for i in range(models.size()):
			if models[i].id == model_id:
				models.remove_at(i)
				# 如果删除的是当前模型，切换到第一个
				if current_model_id == model_id and not models.is_empty():
					current_model_id = models[0].id
				save_models()
				return

	func get_model_by_id(model_id: String) -> ModelInfo:
		for model in models:
			if model.id == model_id:
				return model
		return null

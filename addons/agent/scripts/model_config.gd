@tool
class_name ModelConfig
extends RefCounted

## 模型配置管理类，用于管理多个AI模型的配置

class SupplierInfo:
	var id: String = ""
	var name: String = ""
	var base_url: String = ""
	var api_key: String = ""
	var provider: String = "openai"  # 提供商类型: openai, moonshot, deepseek, minimax, gemini, ollama
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
	var supports_vision: bool = false  # 是否支持图片输入
	var supports_image_generation: bool = false  # 是否支持图片生成（如 MiniMax image-01）
	var context_length: int = 0  # 上下文窗口大小（token 数），0 表示未知
	var max_tokens: int = 8192  # 最大输出token数
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
			"supports_vision": supports_vision,
			"supports_image_generation": supports_image_generation,
			"context_length": context_length,
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
		info.supports_vision = data.get("supports_vision", false)
		info.supports_image_generation = data.get("supports_image_generation", false)
		info.context_length = data.get("context_length", 0)
		info.max_tokens = data.get("max_tokens", 8192)
		info.active = data.get("active", false)
		info.supplier_id = data.get("supplier_id", "")
		# 迁移：旧配置没有 context_length 字段，用 max_tokens 作为回退（旧版 max_tokens 实际表示上下文长度）
		if info.context_length == 0 and info.max_tokens > 0:
			info.context_length = info.max_tokens
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

		var deepseek_v4_flash_model = ModelInfo.new()
		deepseek_v4_flash_model.name = "DeepSeek V4.1 Flash"
		deepseek_v4_flash_model.model_name = "deepseek-flash"
		deepseek_v4_flash_model.supports_thinking = true
		deepseek_v4_flash_model.supports_tools = true
		deepseek_v4_flash_model.supports_vision = true
		deepseek_v4_flash_model.context_length = 1048576
		deepseek_v4_flash_model.max_tokens = 384 * 1024
		deepseek_v4_flash_model.active = false
		deepseek_v4_flash_model.supplier_id = deepseek_supplier.id
		deepseek_supplier.models.append(deepseek_v4_flash_model)

		var deepseek_v4_pro_model = ModelInfo.new()
		deepseek_v4_pro_model.name = "DeepSeek V4 Pro"
		deepseek_v4_pro_model.model_name = "deepseek-v4-pro"
		deepseek_v4_pro_model.supports_thinking = true
		deepseek_v4_pro_model.supports_tools = true
		deepseek_v4_pro_model.supports_vision = false
		deepseek_v4_pro_model.context_length = 1048576
		deepseek_v4_pro_model.max_tokens = 384 * 1024
		deepseek_v4_pro_model.active = false
		deepseek_v4_pro_model.supplier_id = deepseek_supplier.id
		deepseek_supplier.models.append(deepseek_v4_pro_model)

		current_supplier_id = deepseek_supplier.id
		current_model_id = deepseek_v4_pro_model.id

		# 添加默认MoonShot供应商
		var moonshot_supplier = SupplierInfo.new()
		moonshot_supplier.name = "MoonShot"
		moonshot_supplier.base_url = "https://api.moonshot.cn"
		moonshot_supplier.api_key = ""
		moonshot_supplier.provider = "moonshot"
		suppliers.append(moonshot_supplier)

		var kimi_k2_5_model = ModelInfo.new()
		kimi_k2_5_model.name = "Kimi K2.5"
		kimi_k2_5_model.model_name = "kimi-k2.5"
		kimi_k2_5_model.supports_thinking = true
		kimi_k2_5_model.supports_tools = true
		kimi_k2_5_model.max_tokens = 8 * 1024
		kimi_k2_5_model.active = false
		kimi_k2_5_model.supplier_id = moonshot_supplier.id
		moonshot_supplier.models.append(kimi_k2_5_model)

		var kimi_k2_5_preview_model = ModelInfo.new()
		kimi_k2_5_preview_model.name = "Kimi K2.5 Preview"
		kimi_k2_5_preview_model.model_name = "kimi-k2.5-preview"
		kimi_k2_5_preview_model.supports_thinking = false
		kimi_k2_5_preview_model.supports_tools = true
		kimi_k2_5_preview_model.max_tokens = 8 * 1024
		kimi_k2_5_preview_model.active = false
		kimi_k2_5_preview_model.supplier_id = moonshot_supplier.id
		moonshot_supplier.models.append(kimi_k2_5_preview_model)

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

		# 添加默认MiniMax供应商
		var minimax_supplier = SupplierInfo.new()
		minimax_supplier.name = "MiniMax"
		minimax_supplier.base_url = "https://api.minimaxi.com/v1"
		minimax_supplier.api_key = ""
		minimax_supplier.provider = "minimax"
		suppliers.append(minimax_supplier)

		var minimax_m27_model = ModelInfo.new()
		minimax_m27_model.name = "MiniMax-M2.7"
		minimax_m27_model.model_name = "MiniMax-M2.7"
		minimax_m27_model.supports_thinking = true
		minimax_m27_model.supports_tools = true
		minimax_m27_model.context_length = 204800
		minimax_m27_model.max_tokens = 8192
		minimax_m27_model.active = false
		minimax_m27_model.supplier_id = minimax_supplier.id
		minimax_supplier.models.append(minimax_m27_model)

		var minimax_m27_hs_model = ModelInfo.new()
		minimax_m27_hs_model.name = "MiniMax-M2.7-highspeed"
		minimax_m27_hs_model.model_name = "MiniMax-M2.7-highspeed"
		minimax_m27_hs_model.supports_thinking = true
		minimax_m27_hs_model.supports_tools = true
		minimax_m27_hs_model.context_length = 204800
		minimax_m27_hs_model.max_tokens = 8192
		minimax_m27_hs_model.active = false
		minimax_m27_hs_model.supplier_id = minimax_supplier.id
		minimax_supplier.models.append(minimax_m27_hs_model)
		var minimax_m3_model = ModelInfo.new()
		minimax_m3_model.name = "MiniMax-M3"
		minimax_m3_model.model_name = "MiniMax-M3"
		minimax_m3_model.supports_thinking = true
		minimax_m3_model.supports_tools = true
		minimax_m3_model.supports_vision = true
		minimax_m3_model.context_length = 1048576
		minimax_m3_model.max_tokens = 8192
		minimax_m3_model.active = false
		minimax_m3_model.supplier_id = minimax_supplier.id
		minimax_supplier.models.append(minimax_m3_model)

		# MiniMax 生图模型
		var minimax_image_01_model = ModelInfo.new()
		minimax_image_01_model.name = "MiniMax Image-01"
		minimax_image_01_model.model_name = "image-01"
		minimax_image_01_model.supports_thinking = false
		minimax_image_01_model.supports_tools = false
		minimax_image_01_model.supports_vision = false
		minimax_image_01_model.supports_image_generation = true
		minimax_image_01_model.context_length = 0
		minimax_image_01_model.max_tokens = 8192
		minimax_image_01_model.active = false
		minimax_image_01_model.supplier_id = minimax_supplier.id
		minimax_supplier.models.append(minimax_image_01_model)

		var minimax_image_01_live_model = ModelInfo.new()
		minimax_image_01_live_model.name = "MiniMax Image-01-Live"
		minimax_image_01_live_model.model_name = "image-01-live"
		minimax_image_01_live_model.supports_thinking = false
		minimax_image_01_live_model.supports_tools = false
		minimax_image_01_live_model.supports_vision = false
		minimax_image_01_live_model.supports_image_generation = true
		minimax_image_01_live_model.context_length = 0
		minimax_image_01_live_model.max_tokens = 8192
		minimax_image_01_live_model.active = false
		minimax_image_01_live_model.supplier_id = minimax_supplier.id
		minimax_supplier.models.append(minimax_image_01_live_model)

		# 添加默认Gemini供应商
		var gemini_supplier = SupplierInfo.new()
		gemini_supplier.name = "Gemini"
		gemini_supplier.base_url = "https://generativelanguage.googleapis.com/v1beta"
		gemini_supplier.api_key = ""
		gemini_supplier.provider = "gemini"
		suppliers.append(gemini_supplier)

		var gemini_flash_preview = ModelInfo.new()
		gemini_flash_preview.name = "gemini-3-flash-preview"
		gemini_flash_preview.model_name = "gemini-3-flash-preview"
		gemini_flash_preview.supports_thinking = false
		gemini_flash_preview.supports_tools = false
		gemini_flash_preview.max_tokens = 64 * 1024
		gemini_flash_preview.active = false
		gemini_flash_preview.supplier_id = gemini_supplier.id
		gemini_supplier.models.append(gemini_flash_preview)

		var gemini_31_pro_preview = ModelInfo.new()
		gemini_31_pro_preview.name = "gemini-3.1-pro-preview"
		gemini_31_pro_preview.model_name = "gemini-3.1-pro-preview"
		gemini_31_pro_preview.supports_thinking = false
		gemini_31_pro_preview.supports_tools = false
		gemini_31_pro_preview.max_tokens = 64 * 1024
		gemini_31_pro_preview.active = false
		gemini_31_pro_preview.supplier_id = gemini_supplier.id
		gemini_supplier.models.append(gemini_31_pro_preview)

		var gemini_25_flash = ModelInfo.new()
		gemini_25_flash.name = "gemini-2.5-flash"
		gemini_25_flash.model_name = "gemini-2.5-flash"
		gemini_25_flash.supports_thinking = false
		gemini_25_flash.supports_tools = false
		gemini_25_flash.max_tokens = 64 * 1024
		gemini_25_flash.active = false
		gemini_25_flash.supplier_id = gemini_supplier.id
		gemini_supplier.models.append(gemini_25_flash)

		# 添加默认火山引擎供应商
		var volcengine_supplier = SupplierInfo.new()
		volcengine_supplier.name = "火山引擎"
		volcengine_supplier.base_url = "https://ark.cn-beijing.volces.com/api/v3"
		volcengine_supplier.api_key = ""
		volcengine_supplier.provider = "volcengine"
		suppliers.append(volcengine_supplier)

		var doubao_seed_evolving = ModelInfo.new()
		doubao_seed_evolving.name = "Doubao Seed Evolving"
		doubao_seed_evolving.model_name = "doubao-seed-evolving"
		doubao_seed_evolving.supports_thinking = true
		doubao_seed_evolving.supports_tools = true
		doubao_seed_evolving.supports_vision = true
		doubao_seed_evolving.context_length = 1048576
		doubao_seed_evolving.max_tokens = 8192
		doubao_seed_evolving.active = false
		doubao_seed_evolving.supplier_id = volcengine_supplier.id
		volcengine_supplier.models.append(doubao_seed_evolving)

		var doubao_seed_2_1_pro = ModelInfo.new()
		doubao_seed_2_1_pro.name = "Doubao Seed 2.1 Pro"
		doubao_seed_2_1_pro.model_name = "doubao-seed-2-1-pro-260915"
		doubao_seed_2_1_pro.supports_thinking = true
		doubao_seed_2_1_pro.supports_tools = true
		doubao_seed_2_1_pro.supports_vision = true
		doubao_seed_2_1_pro.context_length = 1048576
		doubao_seed_2_1_pro.max_tokens = 8192
		doubao_seed_2_1_pro.active = false
		doubao_seed_2_1_pro.supplier_id = volcengine_supplier.id
		volcengine_supplier.models.append(doubao_seed_2_1_pro)

		var doubao_seed_2_1_lite = ModelInfo.new()
		doubao_seed_2_1_lite.name = "Doubao Seed 2.1 Lite"
		doubao_seed_2_1_lite.model_name = "doubao-seed-2-1-lite-260915"
		doubao_seed_2_1_lite.supports_thinking = true
		doubao_seed_2_1_lite.supports_tools = true
		doubao_seed_2_1_lite.supports_vision = true
		doubao_seed_2_1_lite.context_length = 1048576
		doubao_seed_2_1_lite.max_tokens = 8192
		doubao_seed_2_1_lite.active = false
		doubao_seed_2_1_lite.supplier_id = volcengine_supplier.id
		volcengine_supplier.models.append(doubao_seed_2_1_lite)

		var doubao_seed_2_1_turbo = ModelInfo.new()
		doubao_seed_2_1_turbo.name = "Doubao Seed 2.1 Turbo"
		doubao_seed_2_1_turbo.model_name = "doubao-seed-2-1-turbo-260628"
		doubao_seed_2_1_turbo.supports_thinking = true
		doubao_seed_2_1_turbo.supports_tools = true
		doubao_seed_2_1_turbo.supports_vision = true
		doubao_seed_2_1_turbo.context_length = 262144
		doubao_seed_2_1_turbo.max_tokens = 8192
		doubao_seed_2_1_turbo.active = false
		doubao_seed_2_1_turbo.supplier_id = volcengine_supplier.id
		volcengine_supplier.models.append(doubao_seed_2_1_turbo)

		# 火山引擎图片生成模型
		var doubao_seedream_pro = ModelInfo.new()
		doubao_seedream_pro.name = "Doubao Seedream 5.0 Pro"
		doubao_seedream_pro.model_name = "doubao-seedream-5-0-pro-260628"
		doubao_seedream_pro.supports_thinking = false
		doubao_seedream_pro.supports_tools = false
		doubao_seedream_pro.supports_vision = false
		doubao_seedream_pro.supports_image_generation = true
		doubao_seedream_pro.context_length = 0
		doubao_seedream_pro.max_tokens = 8192
		doubao_seedream_pro.active = false
		doubao_seedream_pro.supplier_id = volcengine_supplier.id
		volcengine_supplier.models.append(doubao_seedream_pro)

		var doubao_seedream_flash = ModelInfo.new()
		doubao_seedream_flash.name = "Doubao Seedream 5.0 Flash"
		doubao_seedream_flash.model_name = "doubao-seedream-5-0-flash-260915"
		doubao_seedream_flash.supports_thinking = false
		doubao_seedream_flash.supports_tools = false
		doubao_seedream_flash.supports_vision = false
		doubao_seedream_flash.supports_image_generation = true
		doubao_seedream_flash.context_length = 0
		doubao_seedream_flash.max_tokens = 8192
		doubao_seedream_flash.active = false
		doubao_seedream_flash.supplier_id = volcengine_supplier.id
		volcengine_supplier.models.append(doubao_seedream_flash)

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

		var model_size = suppliers.reduce(func(sum, supplier): return supplier.models.size() + sum, 0)
		AlphaAgentPlugin.print_alpha_message("{0}个默认供应商及{1}个模型创建完成".format([suppliers.size(), model_size]))


	func load_models():
		var file_content = FileAccess.get_file_as_string(config_file)
		if FileAccess.get_open_error() != OK:
			AlphaAgentPlugin.print_alpha_message("模型配置文件不存在，将创建默认供应商...")
			return

		var json = JSON.parse_string(file_content)
		if json == null:
			AlphaAgentPlugin.print_alpha_message("模型配置文件解析失败，将创建默认供应商...")
			return

		current_model_id = json.get("current_model_id", "")
		current_supplier_id = json.get("current_supplier_id", "")
		var suppliers_data = json.get("supplier", [])

		suppliers.clear()
		for supplier_data in suppliers_data:
			suppliers.append(SupplierInfo.from_dict(supplier_data))
		var model_size = suppliers.reduce(func(sum, supplier): return supplier.models.size() + sum, 0)

		AlphaAgentPlugin.print_alpha_message("{0}个供应商及{1}个模型加载完成".format([suppliers.size(), model_size]))

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

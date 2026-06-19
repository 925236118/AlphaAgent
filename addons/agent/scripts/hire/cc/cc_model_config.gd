@tool
class_name CCModelConfig
extends RefCounted

## CC 模型配置透传
## 负责在启动 CC 子进程前设置环境变量，将 Alpha 的模型配置透传给 CC
##
## 第一阶段仅支持 DeepSeek（通过 OpenAI 兼容接口）

## 配置 CC 的环境变量
## model_config: Alpha 当前使用的模型配置（ModelConfig.ModelInfo）
## 仅当 global_setting.cc_use_alpha_model = true 时生效
static func configure_cc_environment(model_config: Dictionary) -> void:
	var gs = AlphaAgentPlugin.global_setting
	if not gs.cc_use_alpha_model:
		# 用户自行配置 CC 模型，Alpha 不干预
		return

	# 仅透传 DeepSeek（第一阶段）
	var provider = model_config.get("provider", "")
	if provider != "deepseek":
		push_warning("CCModelConfig: 当前仅支持 DeepSeek 模型透传，provider=%s 将被跳过" % provider)
		return

	OS.set_environment("ANTHROPIC_BASE_URL", model_config.get("base_url", ""))
	OS.set_environment("ANTHROPIC_API_KEY", model_config.get("api_key", ""))
	OS.set_environment("ANTHROPIC_MODEL", model_config.get("model_name", ""))
	OS.set_environment("ANTHROPIC_CUSTOM_PROVIDER", "openai-compatible")

## 清除由 Alpha 设置的环境变量
static func clear_cc_environment() -> void:
	OS.set_environment("ANTHROPIC_BASE_URL", "")
	OS.set_environment("ANTHROPIC_API_KEY", "")
	OS.set_environment("ANTHROPIC_MODEL", "")
	OS.set_environment("ANTHROPIC_CUSTOM_PROVIDER", "")

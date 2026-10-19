@tool
class_name VolcengineChat
extends DeepSeekChat

## 火山引擎 ARK 非流式聊天客户端（用于标题生成和上下文压缩）

## 覆盖此方法添加 thinking 参数
func _get_extra_request_data() -> Dictionary:
	if not use_thinking:
		return {"thinking": {"type": "disabled"}}
	return {}

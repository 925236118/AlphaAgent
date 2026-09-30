@tool
class_name VolcengineChatStream
extends DeepSeekChatStream

## 火山引擎 ARK 流式聊天客户端（OpenAI 兼容，支持 thinking 参数）
## 文档：https://www.volcengine.com/docs/82379/1330310

## 覆盖此方法添加 thinking 参数（关闭深度思考时传 type=disabled）
func _get_extra_request_data() -> Dictionary:
	if not use_thinking:
		return {"thinking": {"type": "disabled"}}
	return {}

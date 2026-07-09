# Chat Wrapper（LLM 适配层）

## 关键文件

| 文件 | 类型 | 用途 |
|------|------|------|
| `scripts/chat_wrapper/openai_chat_stream.gd` | Stream | OpenAI 兼容流式对话 |
| `scripts/chat_wrapper/openai_chat.gd` | Chat | 标题生成、Compaction 摘要 |
| `scripts/chat_wrapper/deepseek_chat_stream.gd` | Stream | DeepSeek |
| `scripts/chat_wrapper/anthropic_chat_stream.gd` | Stream | Anthropic |
| `scripts/chat_wrapper/gemini_chat_stream.gd` | Stream | Gemini |
| `scripts/chat_wrapper/moonshot_chat_stream.gd` | Stream | Moonshot |
| `scripts/chat_wrapper/minimax_chat_stream.gd` | Stream | MiniMax |
| `scripts/chat_wrapper/ollama_chat_stream.gd` | Stream | Ollama 本地 |
| `scripts/test/mock_chat_stream.gd` | Mock | 无 API 的测试用 Stream |

每个 provider 均有对应的 `*Chat` 非流式类，用于标题生成和 Compaction 摘要。

## Provider 映射

`main_panel.send_messages()` 中的工厂分支：

| provider | Stream 类 | Chat 类 |
|----------|-----------|---------|
| `openai` | `OpenAIChatStream` | `OpenAIChat` |
| `deepseek` | `DeepSeekChatStream` | `DeepSeekChat` |
| `anthropic` | `AnthropicChatStream` | `AnthropicChat` |
| `gemini` | `GeminiChatStream` | `GeminiChat` |
| `moonshot` | `MoonShotChatStream` | `MoonShotChat` |
| `minimax` | `MiniMaxChatStream` | `MiniMaxChat` |
| `ollama` | `OllamaChatStream` | `OllamaChat` |

## 统一信号契约（Stream 类）

| 信号 | 参数 | 说明 |
|------|------|------|
| `think` | `String` | 思考内容流式片段 |
| `message` | `String` | 正文流式片段 |
| `use_tool` | `Array[ToolCallsInfo]` | 模型请求工具调用 |
| `response_use_tool` | 无 | 模型开始输出 tool_calls 前的通知 |
| `generate_finish` | `finish_reason`, `total_tokens` | 生成结束 |
| `error` | `Dictionary` | 错误信息 |

`finish_reason` 常见值：`stop`、`tool_calls`。

## 公共属性

Stream 类实例化后由 `main_panel` 设置：

```gdscript
current_chat_stream.api_base = supplier.base_url
current_chat_stream.model_name = model.model_name
current_chat_stream.max_tokens = model.max_tokens
current_chat_stream.secret_key = supplier.api_key  # ollama 除外
current_chat_stream.use_thinking = model.supports_thinking and use_thinking
current_chat_stream.tools = _get_effective_tools_list()
```

## HTTP 代理

通过 `AgentModelUtils.apply_proxy_to_http_client()` 应用 `GlobalSetting` 中的 `http_proxy_host` / `http_proxy_port`。

项目级 `res://.alpha/settings.json` 可覆盖代理设置。

## 工具调用解析

各 Stream 类在 SSE 流解析中累积 `tool_calls`，解析完成后通过 `use_tool` 信号传出 `AgentModelUtils.ToolCallsInfo` 数组。

`ToolCallsInfo` 含：`id`、`function.name`、`function.arguments`（JSON 字符串）。

## Provider 特殊处理

### Gemini Thinking

`gemini_chat_stream.gd` 在 `use_thinking == true` 时：

1. 请求体添加 `generationConfig.thinkingConfig.thinkingBudget`
2. 响应解析时区分 `part.thought == true`（思考）与普通 `text`（正文）
3. 思考内容通过 `think` 信号，正文通过 `message` 信号

### Anthropic Thinking

通过 `messages` API 的 `thinking` 块与 `budget_tokens` 配置。

## Mock Provider 测试

`MockChatStream` 支持队列化响应，用于无真实 API 的自动化测试：

```bash
godot --headless -s addons/agent/scripts/test/mock_chat_stream_test.gd
```

详见 [测试基础设施](testing.md)。

## 新增 Provider Checklist

1. 在 `scripts/chat_wrapper/` 创建 `{name}_chat_stream.gd` 和 `{name}_chat.gd`
2. 实现统一信号接口和 `post_message(messages)` 方法
3. 在 `model_config.gd` 的 provider 枚举/选项中添加新值
4. 在 `main_panel.send_messages()` 添加工厂分支
5. 在 `ui/models/` 供应商 UI 中添加配置项和官网链接
6. 测试：流式对话、工具调用、thinking 模式、标题生成、Compaction 摘要

## 扩展指南

- Provider 特殊字段（如 Gemini `thought_signature`）：在对应 Stream 类内处理，不泄漏到 `main_panel`
- 非流式用途扩展：使用 `*Chat` 类，连接 `generate_finish` 信号

相关文档：[模型配置](models.md)、[聊天流程](chat-flow.md)、[测试基础设施](testing.md)

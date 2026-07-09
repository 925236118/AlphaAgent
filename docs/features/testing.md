# 测试基础设施

## 关键文件

| 文件 | 职责 |
|------|------|
| `scripts/test/mock_chat_stream.gd` | 可队列化响应的 Mock Stream |
| `scripts/test/mock_chat_stream_test.gd` | Headless 测试入口 |
| `tools/tools_test.tscn` | 工具手动测试场景 |

## MockChatStream

仿照真实 `*ChatStream` 信号契约，无需真实 API Key 即可测试聊天流程。

### API

```gdscript
var stream := MockChatStream.new()

stream.queue_text_response("hello", "thinking step")  # 正文 + 可选思考
stream.queue_tool_call("read_file", {"path": "res://main.gd"})
stream.queue_error("network error")

stream.use_thinking = true
stream.post_message([])
```

### 信号

与真实 Stream 一致：`think`、`message`、`use_tool`、`response_use_tool`、`generate_finish`、`error`。

## 运行 Headless 测试

```bash
godot --headless -s addons/agent/scripts/test/mock_chat_stream_test.gd
```

测试验证：

- `generate_finish` 正常触发
- `message` 输出 `hello`
- `think` 输出 `thinking step`（`use_thinking=true` 时）

## 工具手动测试

`tools/tools_test.tscn` 提供编辑器内手动调用各工具的测试场景，适合验证 Godot 编辑器 API 集成。

## 扩展指南

### 新增 Mock 测试

1. 在 `scripts/test/` 创建 `*_test.gd`
2. 使用 `extends SceneTree` + `_initialize()` 模式
3. 通过 `assert()` 验证行为，`quit(0)` 成功退出

### 扩展 MockChatStream

- 添加多轮 `post_message` 队列消费
- 模拟流式分片 emit
- 集成到 GUT 或其他测试框架（如项目引入）

相关文档：[Chat Wrapper](chat-wrapper.md)、[工具开发指南](tools/developer-guide.md)

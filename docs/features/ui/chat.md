# 聊天 UI

## 关键文件

| 文件 | 职责 |
|------|------|
| `ui/chat/input_container.gd` | 输入区：发送、Steering、模型/角色选择、补全菜单 |
| `ui/chat/message_item.gd` | 单条消息渲染与状态 |
| `ui/chat/use_tool_item.gd` | 工具调用详情折叠展示 |
| `ui/chat/reference_item.gd` | 文件/节点引用 chip |
| `ui/customdropdown/dropdown/custom_dropdown.gd` | Agent/ASK 模式切换下拉 |

## input_container 信号

| 信号 | 参数 | 消费者 |
|------|------|--------|
| `send_message` | `message: Dictionary`, `message_content: String` | `main_panel.on_input_container_send_message` |
| `steering_message` | `message: Dictionary`, `message_content: String` | `main_panel._on_steering_message` |
| `stop_chat` | 无 | `main_panel` 停止对话 |
| `show_help` | 无 | 打开帮助窗口 |
| `show_setting` | 无 | 切换设置页 |
| `show_memory` | 无 | 切换记忆页 |
| `model_changed` | `supplier_id`, `model_id` | 更新当前模型 |
| `chat_mode_changed` | `mode: String` | `main_panel._on_chat_mode_changed` |

## 发送流程

1. 用户输入文本，可选附加引用（`reference_list` 中的文件/节点路径）
2. 若对话生成中且 Stop 可见 → 发出 `steering_message`（插队）
3. 否则构建 user message Dictionary，发出 `send_message`
4. `main_panel` 创建 `message_item`，调用 `send_messages()`

发送快捷键由 `GlobalSetting.send_shortcut` 控制。

## Token 用量显示

`usage_label` 显示当前会话 token 占用百分比：

- `set_usage_label(total_tokens, max_content_length)` — `max_content_length` 为上下文窗口（千 token 单位）
- Tooltip 显示 `已用 / 上限` 具体数值
- 每轮 `generate_finish` 后由 `main_panel` 累加更新

## message_item 状态

`AgentChatMessageItem` 管理单条消息的多种展示状态：

| 状态 | 方法 | 说明 |
|------|------|------|
| 用户消息 | `update_user_message_content` | 显示用户文本 |
| 思考内容 | `update_think_content` | Thinking 区域，可折叠 |
| 助手正文 | `update_message_content` | 流式累加显示 |
| 工具调用 | `used_tools` / `update_used_tool_result` | 展示参数与结果 |
| 工具响应中 | `response_use_tool` | 标记进入工具调用态 |

同一 `message_id` 关联 assistant 消息与其 tool 结果。

## 引用与拖拽

- `reference_item`：输入区上方的文件/节点引用 chip，可删除
- 支持从文件系统或场景树拖拽资源到输入框
- `auto_add_file_ref` 设置项控制是否自动添加引用

## 补全菜单

输入 `/` 或 `@` 触发下拉补全，详见 [输入框快捷菜单](../input-menu.md)。

内置命令：

| 命令 | 说明 |
|------|------|
| `/memory` | 切换记忆面板 |
| `/help` | 打开帮助 |
| `/setting` | 切换设置面板 |

另支持 [Prompt 模板](../prompt-templates.md) 与 Skill 补全。

## 模型与角色选择

- `model_button`：绑定 `ModelManager` 当前模型，`models_changed` 时刷新
- `role_button`：绑定 `RoleManager` 当前角色，`roles_changed` 时刷新
- `use_thinking`：CheckButton，与模型 `supports_thinking` 联动
- `custom_dropdown`：Agent/ASK 模式切换；ASK 模式限制为只读工具

## Agent / ASK 模式

| 模式 | 行为 |
|------|------|
| Agent | 按当前角色工具白名单执行（默认可写） |
| ASK | 仅暴露 `tool_readonly == true` 的工具，禁止写操作 |

模式切换通过 `custom_dropdown.mode_changed` 信号联动 placeholder 与工具过滤。

`CustomDropdown` API：

- `get_now_mode()` → `"Agent"` 或 `"ASK"`
- `set_mode(mode, emit_signal)` — 程序化设置（历史恢复用）
- `mode_changed(mode)` — 模式变更信号

## Steering 插队发送

对话生成中（`disable=true` 且 Stop 按钮可见）用户按发送快捷键：

- 不发起新对话轮次
- 发出 `steering_message`，消息进入 `main_panel._steering_queue`
- 当前工具循环结束后注入上下文并继续

## 扩展指南

- 新增输入命令：在 `command_list` 或 Prompt 模板目录添加
- 新增消息展示类型：扩展 `message_item.gd` 添加渲染分支
- 新增引用类型：扩展 `reference_item` 和拖拽处理逻辑

相关文档：[聊天流程](../chat-flow.md)、[输入框快捷菜单](../input-menu.md)、[上下文压缩](../context-compaction.md)

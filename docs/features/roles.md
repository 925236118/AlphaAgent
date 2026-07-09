# 角色系统

## 关键文件

| 文件 | 职责 |
|------|------|
| `scripts/role_config.gd` | `RoleInfo`、`RoleManager`、`WORKFLOW_PROMPT` |
| `ui/role/role_option_window.gd` | 角色管理主窗口 |
| `ui/role/edit_role_window.gd` | 创建/编辑角色弹窗 |
| `ui/role/edit_function_item.gd` | 工具开关项 |
| `ui/role/setting_role_item.gd` | 设置页角色行 |

## 数据结构

### RoleInfo

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 唯一标识 |
| `name` | String | 角色名称 |
| `prompt` | String | 人设 Prompt，注入 system 消息 |
| `tools` | Array[String] | 工具名白名单 |

持久化：`roles.{version}.json`，由 `RoleManager` 管理。

## 工具白名单链路

```mermaid
flowchart LR
    Role[RoleInfo.tools] --> Filter[get_filtered_tools_list]
    Filter --> Stream[ChatStream.tools]
    Stream --> LLM[API function calling]
```

`main_panel.send_messages()` 读取当前角色与 ASK 模式：

```gdscript
current_chat_stream.tools = _get_effective_tools_list()
```

优先级：
1. **ASK 模式**：仅 `tool_readonly == true` 的工具
2. **有角色且 tools 非空**：角色白名单
3. **无角色或 tools 为空**：回退只读工具集（不再暴露全部工具）

角色无 tools 或 tools 为空时，LLM 看不到任何工具。

## 默认角色

`RoleManager.add_default_roles()` 在首次启动时创建：

| 角色 | 特点 |
|------|------|
| 默认 | 全工具权限 |
| 只读 | 仅只读工具 |
| 工作流 | 内置 `WORKFLOW_PROMPT` 三阶段流程 |

`WORKFLOW_PROMPT` 定义分析→方案→执行三阶段约束，见 `role_config.gd` 常量。

## system prompt 注入

`init_message_list()` 将 `current_role.prompt` 填入 `{role_prompt}` 占位符：

```gdscript
"role_prompt": current_role.prompt if current_role else "无"
```

## UI 数据流

| 操作 | 信号/方法 |
|------|-----------|
| 切换角色 | `set_current_role(id)` → `roles_changed` |
| 编辑工具权限 | `edit_role_window` 勾选 → 更新 `RoleInfo.tools` |
| 刷新选择器 | `AlphaAgentSingleton.roles_changed` → `input_container` |

## 扩展指南

1. 新增预设角色：在 `add_default_roles()` 中添加 `RoleInfo` 实例
2. 角色级 system 规则：修改角色的 `prompt` 字段
3. 限制工具集：在角色编辑 UI 中勾选/取消工具名

相关文档：[工具系统架构](../architecture/tool-system.md)、[聊天流程](chat-flow.md)

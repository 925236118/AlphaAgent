# 扩展钩子 API

## 关键文件

| 文件 | 职责 |
|------|------|
| `agent_singleton.gd` | 扩展信号与拦截器注册 |
| `tools/tools.gd` | 工具执行前后触发钩子 |
| `ui/main_panel.gd` | `before_agent_finish` 触发点 |

## 信号

| 信号 | 时机 | 参数 |
|------|------|------|
| `before_tool_call(tool_call)` | 工具执行前 | `AgentModelUtils.ToolCallsInfo` |
| `after_tool_call(tool_call, result)` | 工具执行后 | 工具调用 + JSON 结果字符串 |
| `before_agent_finish(finish_reason, total_tokens)` | 单轮对话结束前 | 结束原因、token 数 |
| `chat_mode_changed(mode)` | Agent/ASK 模式切换 | `"Agent"` 或 `"ASK"` |

## 使用示例

### 监听工具调用

```gdscript
func _ready():
    var singleton = AlphaAgentSingleton.get_instance()
    singleton.before_tool_call.connect(_on_before_tool)
    singleton.after_tool_call.connect(_on_after_tool)

func _on_before_tool(tool_call: AgentModelUtils.ToolCallsInfo):
    print("即将执行: ", tool_call.function.name)

func _on_after_tool(tool_call: AgentModelUtils.ToolCallsInfo, result: String):
    print("执行完成: ", tool_call.function.name)
```

### 工具拦截器

```gdscript
AlphaAgentSingleton.get_instance().register_tool_call_interceptor(
    func(tool_call: AgentModelUtils.ToolCallsInfo) -> bool:
        if tool_call.function.name == "execute_command":
            return true  # 返回 true 拦截默认执行
        return false
)
```

拦截时 `use_tool()` 返回 `{"intercepted": true}`，不会调用 `do_action`。

### 对话结束钩子

```gdscript
AlphaAgentSingleton.get_instance().before_agent_finish.connect(
    func(reason, tokens): print("本轮结束: ", reason, " tokens=", tokens)
)
```

## 与 Pi Extensions 的对比

Pi 提供 30+ 事件的 TypeScript Extension 系统。Alpha Agent 当前提供轻量 GDScript 钩子，适合：

- 项目内脚本监听/拦截工具
- 审计日志、权限二次校验
- 自定义 finish 后处理

完整第三方扩展加载（类似 Pi jiti）尚未实现，可通过 Godot 插件 + 信号连接达到类似效果。

## 扩展指南

- 拦截器在 `before_tool_call` 信号之后、`do_action` 之前执行
- 使用 `unregister_tool_call_interceptor(callback)` 移除拦截器
- 避免在钩子中执行耗时同步操作，以免阻塞工具循环

相关文档：[工具系统架构](../architecture/tool-system.md)、[插件生命周期](../architecture/plugin-lifecycle.md)

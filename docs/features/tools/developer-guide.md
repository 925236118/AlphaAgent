# 工具开发指南

## AgentToolBase 接口

所有工具继承 `AgentToolBase`（`tools/tool_base.gd`），必须实现以下抽象方法：

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `_get_tool_name()` | String | 工具唯一名称，作为 function calling 的 name |
| `_get_tool_description()` | String | 详细描述，传给 LLM |
| `_get_tool_short_description()` | String | 简短描述，用于 UI 和角色编辑 |
| `_get_tool_parameters()` | Dictionary | OpenAI JSON Schema 格式的参数定义 |
| `_get_tool_readonly()` | bool | 是否只读（ASK 模式、并行执行、角色「只读」均依据此） |
| `_get_tool_group()` | ToolGroup | 工具分组 |
| `do_action(tool_call)` | Dictionary | 执行逻辑，返回结果字典 |

## do_action 返回格式

返回 `Dictionary`，由 `AgentTools.use_tool()` 自动 `JSON.stringify`：

```gdscript
# 成功
return {"result": "操作成功", "data": {...}}

# 失败
return {"error": "错误描述"}
```

参数解析：

```gdscript
func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
    var json = JSON.parse_string(tool_call.function.arguments)
    if json == null or not json.has("required_field"):
        return {"error": "参数错误"}
    # 执行逻辑...
    return {"result": "..."}
```

## 注册流程

1. 在 `tools/tools_nodes/` 创建 `{name}_tool.gd`，`extends AgentToolBase`
2. 在 `tools/tools.tscn` 添加子节点，挂载脚本
3. `AgentTools._ready()` 自动扫描子节点注册到 `tool_map`
4. 在 `docs/features/tools/index.md` 和 `base.md` 补充条目

## 只读与写操作

| `tool_readonly` | ASK 模式 | 并行执行 | 角色「只读」 |
|-----------------|----------|----------|--------------|
| `true` | 可见 | 与同批只读工具并行 | 可见 |
| `false` | 不可见 | 串行执行 | 取决于角色白名单 |

写操作工具（`false`）在 `main_panel._execute_tool_calls()` 中串行 `await`，避免文件竞争。

## 输出截断

`AgentTools.use_tool()` 在返回前调用 `truncate_tool_output()`，默认上限 12000 字符。工具 `do_action` 无需自行截断。

## 扩展钩子

工具执行前后自动触发 `AlphaAgentSingleton` 信号，可在项目脚本中监听或注册拦截器。详见 [扩展钩子 API](../extension-api.md)。

## 实现模板

### 只读查询工具

```gdscript
@tool
class_name ExampleQueryTool
extends AgentToolBase

func _get_tool_name() -> String:
    return "example_query"

func _get_tool_short_description() -> String:
    return "查询示例数据。"

func _get_tool_description() -> String:
    return "详细描述，说明用途和限制。"

func _get_tool_parameters() -> Dictionary:
    return {
        "type": "object",
        "properties": {
            "path": {"type": "string", "description": "资源路径"}
        },
        "required": ["path"]
    }

func _get_tool_readonly() -> bool:
    return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
    return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
    var json = JSON.parse_string(tool_call.function.arguments)
    # 查询逻辑...
    return {"result": data}
```

### 写操作工具（含文件备份）

```gdscript
func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
    var path = json.path
    AgentTempFileManager.get_instance().create_temp_file(path)
    # 写入逻辑...
    return {"success": true}
```

触发备份的工具见 [文件编辑回滚](../edit-file.md)。

### EditorInterface 调用

通过 `AlphaAgentSingleton` 获取编辑器能力：

```gdscript
var singleton = AlphaAgentSingleton.get_instance()
var plugin = singleton.editor_plugin
var editor_interface = plugin.get_editor_interface()
```

## ToolGroup 选择

| 分组 | 适用场景 |
|------|----------|
| QUERY | 只读查询，不修改任何状态 |
| FILE | 文件系统读写 |
| SCENE | 场景节点操作 |
| EDITOR | 通过 EditorInterface 修改资源/脚本 |
| COMMAND | 命令行执行 |
| DEBUG | 调试验证 |
| PROJECT | 项目配置（如 input mapping） |

## 辅助工具

| 文件 | 用途 |
|------|------|
| `tools/tool_utils/tool_utils.gd` | 跨工具复用函数（节点路径标准化、全局搜索等） |
| `tools/tool_utils/temp_file_manager.gd` | 文件编辑备份 |

## 扩展检查清单

- [ ] 工具名全局唯一
- [ ] `_get_tool_readonly()` 正确设置（查询类 true，写操作 false）
- [ ] 写操作工具调用 `create_temp_file`（如适用）
- [ ] 参数 schema 含 `required` 字段
- [ ] 错误情况返回 `{"error": "..."}` 而非抛异常
- [ ] 返回内容考虑截断上限（超大结果会被 `truncate_tool_output` 裁剪）
- [ ] 更新 `docs/features/tools/index.md`

相关文档：[工具系统架构](../../architecture/tool-system.md)、[工具总索引](index.md)、[扩展钩子 API](../extension-api.md)

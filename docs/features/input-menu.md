# 输入框快捷菜单

实现文档，描述输入框 `/` 与 `@` 补全功能。UI 组件详见 [聊天 UI](ui/chat.md)。

## 功能概述

在输入框中输入特定字符时，自动显示下拉菜单供快速选择。


| 触发字符 | 功能                     | 说明                    |
| ---- | ---------------------- | --------------------- |
| `/`  | 命令 / Skill / Prompt 模板 | 显示所有命令、Skill 和模板，支持过滤 |
| `@`  | 文件路径列表                 | 显示项目文件路径，支持过滤         |


---

## `/` 命令

### 使用方式

1. 输入 `/` → 显示所有命令、Skill 和 Prompt 模板
2. 输入 `/关键字` → 过滤显示包含关键字的项

### 显示格式

```
/memory 管理记忆
/help 帮助
/setting 显示设置
/review-script [审查当前 Godot 脚本质量]
/create-ui-scene [生成 Godot UI 场景结构方案]
/godot-gdscript-patterns [Master Godot 4 GDScript patterns...]
...
```

### 命令类型


| 类型                                 | 行为                   |
| ---------------------------------- | -------------------- |
| 内置命令（`/memory`、`/help`、`/setting`） | 执行对应面板操作             |
| Prompt 模板（`/review-script` 等）      | 将模板正文填入输入框           |
| Skill（`/skill_name`）               | 插入 `/skill_name` 供发送 |


### 选中行为

- 命令：插入命令 + 空格，如 `/memory` 
- Skill：插入 `/skill_name`  + 空格
- 模板：通过 `handle_command()` 将模板 content 填入 `user_input`
- 选中后输入框自动获取焦点，光标定位到末尾

---

## `@` 命令 - 文件路径列表

### 使用方式

1. 输入 `@` → 显示根目录 `res://` 下的文件和文件夹（最多20条）
2. 输入 `@关键字` → 搜索所有层级，返回包含关键字的文件路径

### 显示格式

```
res://project.godot
res://icon.svg
res://scenes/
res://scripts/
...
```

### 选中行为

- 插入文件路径 + 空格，如 `res://project.godot` 
- 选中后输入框自动获取焦点，光标定位到末尾

---

## 技术实现

### 关键文件


| 文件                          | 路径                                               |
| --------------------------- | ------------------------------------------------ |
| `input_container.gd`        | `addons/agent/ui/chat/input_container.gd`        |
| `prompt_template_config.gd` | `addons/agent/scripts/prompt_template_config.gd` |


### 核心逻辑

#### 1. 菜单类型枚举

```gdscript
enum MenuListType {
    None,
    Command,
    Skill,
    File
}
```

#### 2. 命令列表来源（_get_command_list）

```gdscript
var commands = command_list.duplicate()  # 内置 /memory /help /setting
commands.append_array(prompt_template_manager.get_command_list())
```

#### 3. 输入检测 (`on_user_input_text_changed`)

- `@` → 文件列表补全
- `/` → 命令 + Skill + 模板补全

#### 4. 选中处理 (`on_input_menu_list_item_selected`)

按 `MenuListType` 分支插入命令、Skill 或文件路径。

### 辅助函数


| 函数                                              | 作用                |
| ----------------------------------------------- | ----------------- |
| `get_filtered_skill_list(prefix)`               | 获取过滤后的 Skill 列表   |
| `get_skill_description(skill_name)`             | 获取 Skill 的描述信息    |
| `get_filtered_file_list(text)`                  | 获取过滤后的文件列表        |
| `get_project_file_list(start_path, interation)` | 获取项目文件列表（支持递归深度）  |
| `_get_command_list()`                           | 合并内置命令与 Prompt 模板 |


---

## 配置说明

### 文件搜索深度

`get_project_file_list` 默认 `interation=-1`（无限制），搜索所有层级文件。

### 文件列表最大显示数

`get_filtered_file_list` 限制最多显示 20 条结果。

### 忽略文件模式

```gdscript
var ignore_patterns = [".alpha", ".godot", "*.uid", "addons", "*.import"]
```

相关文档：[Prompt Templates](prompt-templates.md)、[Skill 系统](skills.md)
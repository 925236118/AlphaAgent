# Prompt Templates

## 关键文件

| 文件 | 职责 |
|------|------|
| `scripts/prompt_template_config.gd` | `PromptTemplateManager` |
| `addons/agent/prompts/*.md` | 内置模板 |
| `ui/chat/input_container.gd` | `/` 补全与命令展开 |

## 模板格式

```markdown
---
name: review-script
description: 审查当前 Godot 脚本质量
---

# 正文内容
...
```

`name` 对应 `/` 命令名（如 `/review-script`），`description` 显示在补全菜单中。

## 存储位置

| 类型 | 路径 |
|------|------|
| 内置模板（只读源） | `res://addons/agent/prompts/` |
| 用户模板 | `{config_dir}/.alpha/prompts_{version}/` |

首次创建用户目录时，从内置目录复制缺失的 `.md` 文件。

## 使用方式

1. 输入 `/review-script` 回车 — `handle_command()` 将模板正文填入输入框
2. 输入 `/` — 补全菜单显示模板列表，选中后填入
3. 编辑后发送给 Agent

## 内置模板

| 命令 | 说明 |
|------|------|
| `/review-script` | 审查 Godot 脚本质量（类型安全、信号、性能） |
| `/create-ui-scene` | 生成 UI 场景结构方案（节点层级、布局） |

## PromptTemplateManager API

| 方法 | 说明 |
|------|------|
| `get_template(name)` | 获取 `PromptTemplate` |
| `get_template_names()` | 所有模板名称 |
| `get_command_list()` | 转为 `/` 补全用的 command 数组 |

## 扩展指南

### 新增内置模板

1. 在 `addons/agent/prompts/{name}.md` 创建文件
2. 填写 front matter（`name`、`description`）和正文
3. 用户下次启动或目录初始化后自动复制到用户目录

### 新增用户模板

直接在 `{config_dir}/.alpha/prompts_{version}/` 添加 `.md` 文件，重启插件或重新加载后可用。

相关文档：[输入框快捷菜单](input-menu.md)、[数据持久化](../architecture/data-persistence.md)

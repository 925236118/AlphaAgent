# Skill 系统

## 关键文件

| 文件 | 职责 |
|------|------|
| `skills/skill.gd` | `AgentSkillResource`，SKILL.md 解析与保存 |
| `scripts/skill_config.gd` | `SkillManager`，目录扫描与 CRUD |
| `skills/default_skills/*/SKILL.md` | 19 个内置 Skill |
| `tools/tools_nodes/load_skill.gd` | 运行时加载 Skill 工具 |
| `ui/skill/skill_container.gd` | Skill 管理 UI |

## SKILL.md 格式

```markdown
---
name: godot-gdscript-patterns
description: Master Godot 4 GDScript patterns...
---

# 正文内容
...
```

`AgentSkillResource.load_from_folder()` 解析 YAML front matter 提取 `name` 和 `description`，其余为 `skill_content`。

## 存储位置

| 类型 | 路径 |
|------|------|
| 内置 Skill（只读源） | `res://addons/agent/skills/default_skills/` |
| 用户 Skill | `EditorPaths.config_dir/.alpha/skills_{version}/` |

首次创建用户目录时，`SkillManager.create_default_skills()` 从内置目录复制全部 Skill。

## 生命周期

```mermaid
flowchart LR
    Install[插件启用] --> Copy[复制 default_skills]
    Copy --> Load[SkillManager.load_skills]
    Load --> UI[技能面板 CRUD]
    Load --> XML[系统提示 XML 目录]
    Load --> Tool[load_skill 工具]
    XML --> Context[模型知晓可用 Skill]
    Tool --> Context[注入完整 Skill 正文]
    UI --> Input[/ 补全菜单]
```

Skill **不会**自动注入完整正文，但会在 system prompt 中以 XML 目录形式渐进披露 name/description，供模型决定何时调用 `load_skill`。

## get_skills_xml_summary

`SkillManager.get_skills_xml_summary()` 生成：

```xml
<available_skills>
  <skill name="godot-gdscript-patterns">Master Godot 4 GDScript patterns...</skill>
  ...
</available_skills>
```

由 `main_panel.init_message_list()` 追加到 system prompt，实现渐进式披露。

## load_skill 工具

参数 `skill_name` 的 enum 动态来自 `skill_manager.get_skill_names()`。

返回 `skill.get_skill_markdown()` 完整 Markdown，供模型阅读后遵循。

## SkillManager API

| 方法 | 说明 |
|------|------|
| `get_skill(name)` | 获取 `AgentSkillResource` |
| `get_skill_names()` | 所有 skill 名称列表 |
| `add_skill(skill)` | 创建新 skill 文件夹并保存 |
| `update_skill(skill)` | 更新已有 skill |
| `delete_skill(skill)` | 递归删除 skill 文件夹 |

## UI 与补全联动

- `ui/skill/skill_container.gd`：列表展示与编辑表单
- `ui/chat/input_container.gd`：输入 `/` 时 `get_filtered_skill_list()` 显示 skill 补全

## 扩展指南

### 新增内置 Skill

1. 在 `addons/agent/skills/default_skills/{skill-name}/` 创建 `SKILL.md`
2. 填写 front matter（`name`、`description`）
3. 用户下次初始化或手动复制后可用

### 编写 Skill 内容规范

- `name` 使用 kebab-case，与文件夹名一致
- `description` 一句话说明适用场景
- 正文包含模式、示例代码、注意事项

相关文档：[输入框快捷菜单](input-menu.md)、[数据持久化](../architecture/data-persistence.md)

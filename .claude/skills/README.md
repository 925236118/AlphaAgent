# Cursor / Claude Skills 说明

本目录用于 Cursor AI 辅助开发时的 Skill 引用。

## 唯一来源

内置 Skill 的源文件位于插件目录：

```
addons/agent/skills/default_skills/
```

每个 Skill 是一个子目录，包含 `SKILL.md` 文件（含 YAML front matter）。

## 使用方式

- 在 Cursor 中开发本插件时，以 `addons/agent/skills/default_skills/` 下的 Skill 为准
- 不要在本目录维护重复的 Skill 副本
- 新增或修改 Skill 时，直接编辑插件内的 `default_skills/` 目录

## 内置 Skill 列表

共 19 个 Godot 开发相关 Skill，包括：

- `godot-gdscript-patterns` — GDScript 模式
- `godot-tscn-format` — .tscn 文件格式规范
- `godot-state-machine` — 状态机
- `godot-inventory-system` — 背包系统
- 等（完整列表见各子目录）

运行时通过 `load_skill` 工具加载，输入框输入 `/` 可触发 Skill 补全。
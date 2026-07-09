# 数据持久化

## 存储路径

### 编辑器配置目录（用户级）

基础路径：`EditorInterface.get_editor_paths().get_config_dir() + "/.alpha/"`

非编辑器环境回退到 `OS.get_config_dir()` 下的 Godot 配置目录。

| 文件 | 路径模式 | 管理类 |
|------|----------|--------|
| 用户设置 | `setting.{version}.json` | `GlobalSetting` |
| 模型配置 | `models.{version}.json` | `ModelManager` |
| 角色配置 | `roles.{version}.json` | `RoleManager` |
| 记忆 | `memory.{version}.json` | `memory_container.gd` |
| Skill | `skills_{version}/` | `SkillManager` |
| Prompt 模板 | `prompts_{version}/` | `PromptTemplateManager` |

### 用户数据目录

| 文件 | 路径 | 说明 |
|------|------|------|
| 聊天历史 | `OS.user_data_dir/.alpha/history.json` | `history_and_title.gd` |
| 编辑备份 | `OS.user_data_dir/.alpha/temp/` | `AgentTempFileManager` |

### 项目级

| 数据 | 位置 | 说明 |
|------|------|------|
| 项目设置覆盖 | `res://.alpha/settings.json` | 覆盖全局 `setting.{version}.json` 中的部分字段 |
| 项目记忆 | `config.tres` 的 `memory` 字段 | 随项目版本控制 |
| 系统提示词 | `config.tres` 的 `system_prompt` | 插件内置资源 |

## 版本化命名

版本号来自 `config.tres` 的 `alpha_version`（当前 `0.5`）。

```gdscript
setting_file = setting_dir + "setting.{version}.json".format({"version": CONFIG.alpha_version})
```

插件升级时可通过版本号区分配置文件，便于迁移脚本处理旧版数据。

## JSON Schema 概览

### setting.{version}.json

```json
{
  "auto_clear": false,
  "auto_expand_think": false,
  "auto_add_file_ref": true,
  "send_shortcut": 1,
  "http_proxy_host": "",
  "http_proxy_port": ""
}
```

`send_shortcut` 对应 `AlphaAgentPlugin.SendShotcut` 枚举（`None=0`, `Enter=1`, `CtrlEnter=2`）。

### res://.alpha/settings.json（项目级覆盖）

与 `setting.{version}.json` 字段相同，存在时覆盖全局设置中的对应项。适合按项目配置代理或默认发送快捷键。

### models.{version}.json

由 `ModelManager` 管理，包含 `suppliers[]` 和 `current_supplier_id` / `current_model_id`。

每个 supplier 含：`id`, `name`, `base_url`, `api_key`, `provider`, `models[]`。

每个 model 含：`id`, `name`, `model_name`, `supports_thinking`, `supports_tools`, `max_tokens`, `active`, `supplier_id`。

### roles.{version}.json

由 `RoleManager` 管理，包含 `roles[]` 和 `current_role_id`。

每个 role 含：`id`, `name`, `prompt`, `tools[]`（工具名白名单）。

### memory.{version}.json

```json
{
  "global_memory": ["记忆条目1", "记忆条目2"]
}
```

项目记忆存于 `config.tres`，不写入此文件。

### history.json

```json
[
  {
    "id": "abc123",
    "title": "对话标题",
    "time": "2026-07-09T12:00:00",
    "use_thinking": false,
    "mode": "Agent",
    "message": [
      {"role": "user", "content": "..."},
      {"role": "assistant", "content": "...", "tool_calls": [...]}
    ]
  }
]
```

`mode` 保存 Agent/ASK 状态；`message` 可能含 Compaction 产生的 `[上下文压缩摘要]` system 消息。

### Skill 目录结构

```
skills_0.5/
└── godot-gdscript-patterns/
    └── SKILL.md
```

`SKILL.md` 含 YAML front matter（`name`, `description`, `version`）和 Markdown 正文。

## 数据流

```mermaid
flowchart LR
    GS[GlobalSetting.load] --> MM[ModelManager]
    GS --> RM[RoleManager]
    GS --> SM[SkillManager]
    GS --> PTM[PromptTemplateManager]
    GS --> ProjOverride[.alpha/settings.json]
    MM --> UI[模型选择器]
    RM --> UI2[角色选择器]
    SM --> SkillUI[技能面板]
    PTM --> InputMenu[/ 补全]
    Memory[memory.json] --> PM[project_memory / global_memory]
    PM --> SP[system_prompt 注入]
```

## 扩展指南

- 新增持久化配置：在 `GlobalSetting._init()` 中定义路径，在 `load_global_setting()` 中初始化对应 Manager
- 修改 schema：在 Manager 的 `from_dict()` / `to_dict()` 中处理默认值，保证向后兼容
- 跨版本迁移：比较 `alpha_version`，在 `load_global_setting()` 开头执行一次性迁移逻辑

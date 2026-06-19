# Alpha Agent Harness — 工程管理层

## 概述

Harness 是 Alpha Agent 的工程管理层，包含六个子系统，协同完成从操作记录到知识沉淀的完整闭环。

> **设计原则**：Harness 不新增 LLM 可调用的工具。所有 Harness 数据（Log、Docs、Memory、Soul、Hook 配置）均为标准文件（`.json` / `.md`），使用现有的 `read_file` / `write_file` / `update_script_file_content` 工具即可操作。Harness 的核心逻辑（Hook 执行、Dream 反思、Memory 检索）作为插件内部引擎运行，对 LLM 透明。

```
                        ┌──────────────────────┐
                        │      用户输入          │
                        └──────────┬───────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                    HARNESS 层                        │
        │                                                      │
        │   ┌──────┐   ┌──────┐    ┌────────┐   ┌────────┐   │
        │   │ Hook │──→│ Log  │────│ Dream  │──→│ Memory │   │
        │   └──────┘   └──────┘    └───┬────┘   └───┬────┘   │
        │                    │         │              │        │
        │                    │    ┌────┘              │        │
        │                    │    │                   │        │
        │                 ┌──┴────┴──┐            ┌───┴───┐   │
        │                 │   Docs   │            │ Soul  │   │
        │                 └──────────┘            └───────┘   │
        │                                                      │
        │   Log + Docs ──→ Dream（反思）──→ Memory（长期记忆）  │
        │   Memory → 对话开始时加载到上下文                     │
        │   Soul → 分析用户习惯，独立于 Memory                  │
        └──────────────────────────┬──────────────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                    CORE 层                           │
        │          Alpha 对话引擎 + 工具调用 + CC 委派          │
        └─────────────────────────────────────────────────────┘
```

### 六子系统关系

```
Hook ──→ 监听生命周期事件（开始/结束/工具调用）
   │
   └──→ Log ──→ 记录每次操作（改了什么文件、做了什么功能，上限 200 条）
          │
          ├──→ Docs ──→ 保存设计方案（.md 文件，手动归档）
          │       │
          └───────┤
                  │
                  ▼
              Dream ──→ 定期反思 Log + Docs，提炼为长期知识
                  │
                  ▼
              Memory ──→ 长期记忆（技术选型、踩坑、经验），对话时加载到上下文
                  │
                  └──→ Soul ──→ 分析用户偏好（编码习惯、架构倾向），独立于 Memory
```

---

## 1. Log — 操作日志

### 定位

记录 Alpha 的每次实际操作：修改了什么文件、实现了什么功能、发生了什么错误。它是一个**流水账**，不包含分析和总结。

### 数据结构

```gdscript
class LogEntry:
    var id: int                  # 自增序号
    var timestamp: float         # OS.get_unix_time()
    var action: LogAction        # 操作类型
    var summary: String          # 一句话摘要，如"在 movement.gd 添加 dash() 方法"
    var files_changed: Array[String]   # 涉及的文件路径
    var tool_used: String        # 使用的工具名
    var result: LogResult        # 操作结果
    var session_id: String       # 所属对话 session

enum LogAction {
    FILE_CREATED,      # 创建文件
    FILE_MODIFIED,     # 修改文件
    FILE_DELETED,      # 删除文件
    SCENE_MODIFIED,    # 修改场景
    COMMAND_EXECUTED,  # 执行命令
    CC_DELEGATED,      # 委派 CC 执行
    ERROR_OCCURRED,    # 发生错误
}

enum LogResult {
    SUCCESS,
    FAILED,
    PARTIAL
}
```

### 容量限制

**硬上限 200 条**。超过时自动删除最旧的条目（FIFO）。

### 自动记录时机

| 触发事件 | action | 记录内容 |
|---------|--------|---------|
| `write_file` 被调用 | `FILE_CREATED` / `FILE_MODIFIED` | 文件路径 + 变更摘要 |
| `update_script_file_content` 被调用 | `FILE_MODIFIED` | 文件路径 + 修改的函数/变量 |
| `add_node_to_scene` / `update_scene_node_property` | `SCENE_MODIFIED` | 场景路径 + 节点路径 |
| CC 委派步骤完成 | `CC_DELEGATED` | 步骤标题 + 涉及文件 |
| 任何工具返回 error | `ERROR_OCCURRED` | 工具名 + 错误信息 |

### 日志文件

```
{user_data_dir}/.alpha/
└── logs.json          # 单文件，JSON 数组，最多 200 条
```

### Log 与现有工具

Log 存储为 `logs.json` 文件。Alpha 使用现有的 `read_file` 工具即可查看日志，无需额外工具。日志的写入由 Harness 内部的 Hook（`log_writer.gd`）自动完成。

---

## 2. Docs — 设计文档

### 定位

存放**设计方案**的文件夹。当 Alpha 完成一个设计规划、架构决策或技术方案后，将其保存为 Markdown 文件。这是**人类可读的设计档案**。

### 文件结构

```
项目根目录/
└── docs/
    ├── designs/
    │   ├── player-dash-skill.md        # Player dash 技能设计方案
    │   ├── inventory-system.md         # 背包系统架构设计
    │   └── save-system-refactor.md     # 存档系统重构方案
    ├── decisions/
    │   ├── 2025-06-01-state-machine.md # 架构决策：选择 StateChart 模式
    │   └── 2025-06-10-save-format.md   # 架构决策：存档格式选择
    └── INDEX.md                        # 文档索引（自动维护）
```

### 文档模板

```markdown
# {标题}

> 创建时间: {timestamp}
> 状态: draft / in_progress / completed / abandoned
> 关联任务: {task_link}

## 背景
为什么要做这个设计

## 方案
具体的设计方案

## 涉及文件
- `res://scripts/player/movement.gd`
- `res://scenes/player/player.tscn`

## 决策理由
为什么选择这个方案而非其他

## 验收标准
- [ ] dash() 方法可在任意移动状态下触发
- [ ] dash 有冷却时间
```

### INDEX.md 自动维护

```
docs/INDEX.md 由 Alpha 自动维护，列出所有文档：

- [player-dash-skill](designs/player-dash-skill.md) — Player dash 技能设计方案 (completed)
- [inventory-system](designs/inventory-system.md) — 背包系统架构设计 (in_progress)
- [2025-06-01-state-machine](decisions/2025-06-01-state-machine.md) — 状态机选型 (completed)
```

### Docs 与现有工具

Docs 文件位于 `res://docs/` 目录下，是普通的 Markdown 文件。Alpha 使用现有的 `read_file` / `write_file` 工具即可读写，无需额外工具。`INDEX.md` 由 Harness 内部自动维护。

---

## 3. Hook — 生命周期钩子

### 定位

在 Alpha 的关键生命周期节点触发自定义逻辑。Hook 是 Log 的**数据来源之一**（Hook 触发时可以写入 Log）。

### Hook 事件

| 事件 | 触发时机 | 典型用途 |
|------|---------|---------|
| `session.start` | Alpha 对话开始 | 初始化环境、加载配置 |
| `session.end` | Alpha 对话结束 | 清理临时文件、发送通知 |
| `tool.pre` | 工具调用之前 | 权限检查、输入校验 |
| `tool.post` | 工具调用之后 | 写入 Log、触发 Docs 更新 |
| `cc.pre_delegate` | 委派 CC 之前 | 审查发给 CC 的提示词 |
| `cc.post_delegate` | CC 执行完毕 | 记录 CC 执行结果到 Log |

### 执行方式选择

| 方式 | 优点 | 缺点 | 适用场景 |
|------|------|------|---------|
| **GDScript** | 可直接访问 EditorInterface、场景树、文件系统；与 Godot 深度集成 | 仅能在 Godot 内运行 | Godot 编辑器内操作、场景/资源处理 |
| **CMD** | 可调用外部工具（git、格式化器、CI）；语言无关 | 无法访问 Godot 内部 API | 版本控制、外部工具集成、CI 触发 |

**推荐方案：两者都支持，用户按需选择。**

- **默认推荐 GDScript**：因为 Harness 是 Alpha（Godot 插件）的一部分，GDScript Hook 可以直接操作编辑器，实现"工具调用后自动写入 Log"等核心功能。
- **同时支持 CMD**：作为补充，用于调用 git、触发外部 CI 等场景。

### Hook 配置

```json
// .alpha/hooks.json
{
  "hooks": [
    {
      "event": "tool.post",
      "filter": {"tool_name": "write_file"},
      "type": "gdscript",
      "path": "res://addons/agent/harness/hooks/log_writer.gd"
    },
    {
      "event": "tool.post",
      "filter": {"tool_name": "update_script_file_content"},
      "type": "gdscript",
      "path": "res://addons/agent/harness/hooks/log_writer.gd"
    },
    {
      "event": "session.start",
      "filter": {},
      "type": "cmd",
      "command": "git pull --rebase",
      "timeout_ms": 30000
    }
  ]
}
```

### 内置 Hook：log_writer.gd

Alpha 预置一个 GDScript Hook，自动将 `tool.post` 事件写入 Log：

```gdscript
# addons/agent/harness/hooks/log_writer.gd
# 内置 Hook：将工具调用结果自动写入 Log

func execute(event: String, data: Dictionary) -> Dictionary:
    var tool_name = data.get("tool_name", "")
    var tool_args = data.get("tool_args", {})
    var result = data.get("result", {})
    var session_id = data.get("session_id", "")

    # 根据工具类型生成 Log 条目
    var entry = LogEntry.new()
    entry.tool_used = tool_name
    entry.session_id = session_id
    entry.result = LogResult.SUCCESS if result.get("ok", false) else LogResult.FAILED

    match tool_name:
        "write_file":
            entry.action = LogAction.FILE_CREATED if _is_new_file(tool_args) else LogAction.FILE_MODIFIED
            entry.files_changed = [tool_args.get("path", "")]
            entry.summary = "写入文件: %s" % tool_args.get("path", "")
        "update_script_file_content":
            entry.action = LogAction.FILE_MODIFIED
            entry.files_changed = [tool_args.get("path", "")]
            entry.summary = "修改脚本: %s" % tool_args.get("path", "")
        # ... 其他工具类型

    LogManager.append(entry)
    return {"ok": true}
```

### Hook 工具
### Hook 与现有工具

Hook 是 Harness 内部加载和执行的 GDScript 脚本，存储在 `res://addons/agent/harness/hooks/` 目录下。Alpha 使用现有的 `read_file` / `update_script_file_content` 工具即可查看或修改 Hook 脚本。Hook 的注册/启用/禁用通过 `.alpha/hooks.json` 配置文件管理，使用 `read_file` / `write_file` 工具即可编辑。

---

## 4. Dream — 反思引擎

### 定位

Dream 是连接"操作记录"和"长期知识"的桥梁。它定期（或在用户触发时）读取 Log 和 Docs，反思最近的开发活动，提炼出值得记住的知识，写入 Memory。

### 工作流

```
┌──────────────────────────────────────────────────┐
│              Dream 反思流程                        │
│                                                   │
│   触发条件：                                       │
│   · Log 新增 ≥ 20 条（自动触发）                   │
│   · 用户手动触发 /dream 命令                       │
│   · 对话结束时（兜底）                             │
│                                                   │
│   Step 1: 读取输入                                 │
│   ┌──────────┐    ┌──────────┐                    │
│   │ Log（最近 │    │ Docs（最  │                    │
│   │ 未反思的  │    │ 近新增/更 │                    │
│   │ 操作记录）│    │ 新的方案）│                    │
│   └────┬─────┘    └────┬─────┘                    │
│        └───────┬───────┘                          │
│                ▼                                   │
│   Step 2: Alpha 分析                               │
│   · 哪些操作反复出现？（识别代码模式）               │
│   · 哪些错误重复发生？（识别踩坑）                   │
│   · 哪些设计方案已落地？（记录技术选型）              │
│   · 哪些文件经常一起修改？（发现隐式依赖）            │
│                                                   │
│   Step 3: 生成 Memory 条目                         │
│   · 每条 Memory 标注来源：dream_reflection          │
│   · 关联到具体的 Log 条目和 Docs 文件               │
│                                                   │
│   Step 4: 标记已反思                               │
│   · Log 中标记已反思的条目（避免重复分析）            │
└──────────────────────────────────────────────────┘
```

### Dream 分析维度

| 分析维度 | 数据来源 | 产出的 Memory 类型 |
|---------|---------|-------------------|
| **代码模式识别** | Log 中重复的 `FILE_MODIFIED` 操作 | `CODE_PATTERN` — "项目中的状态机都使用 match 实现" |
| **踩坑记录** | Log 中 `ERROR_OCCURRED` + 后续修复操作 | `PITFALL` — "AnimationLibrary 空名称会导致崩溃" |
| **技术选型沉淀** | Docs 中状态为 `completed` 的设计方案 | `TECH_DECISION` — "存档系统选择 JSON + ConfigFile" |
| **文件关联发现** | Log 中同一 session 内共同修改的文件 | `FILE_DEPENDENCY` — "player.tscn 和 movement.gd 存在双向依赖" |

### Dream 触发配置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `dream_auto_trigger_count` | 20 | Log 新增 N 条后自动触发 Dream |
| `dream_max_memories_per_run` | 5 | 每次 Dream 最多生成 N 条 Memory |
| `dream_on_session_end` | true | 对话结束时是否自动触发 Dream |

### Dream 工具

### Dream 与现有工具

Dream 是 Harness 的内部引擎，无需 LLM 调用。它根据配置自动触发（Log 新增 ≥ 20 条或对话结束时），或由用户通过 `/dream` 命令手动触发。Dream 的运行状态（上次运行时间、待反思条目数）写入 `.alpha/dream_status.json`，使用 `read_file` 即可查看。

---

## 5. Memory — 长期记忆

### 定位

Memory 是 Alpha 的**长期知识库**。它记录技术选型、踩过的坑、学到的经验。Memory 的内容在每次对话开始时**加载到上下文**中，替代现有的 `global_memory` / `project_memory`。

### 数据结构

```gdscript
class MemoryItem:
    var id: String              # UUID
    var category: MemoryCategory
    var title: String           # 简短标题
    var content: String         # 详细内容
    var tags: Array[String]     # 标签
    var created_at: float       # 创建时间
    var source: MemorySource    # 来源
    var source_refs: Array[String]  # 关联的 Log ID / Docs 文件名
    var access_count: int       # 被检索/引用的次数
    var confirmed: bool         # 是否经用户确认（未确认的记忆权重更低）

enum MemoryCategory {
    TECH_DECISION,    # 技术决策：为什么选择 A 而不是 B
    PITFALL,          # 踩坑记录：什么问题，怎么解决的
    CODE_PATTERN,     # 代码模式：项目中惯用的实现方式
    FILE_DEPENDENCY,  # 文件依赖：哪些文件存在隐式耦合
    LESSON,           # 经验教训：从成功或失败中学到的
    CUSTOM            # 用户手动添加
}

enum MemorySource {
    DREAM_REFLECTION,   # Dream 反思生成
    USER_EXPLICIT,      # 用户手动添加
    SOUL_INSIGHT,       # Soul 分析输出
    VERIFICATION        # 验证阶段发现
}
```

### 对话开始时加载

替代现有的简单 Memory 注入逻辑：

```gdscript
# main_panel.gd send_messages() 中
func _inject_memory_to_context(messages: Array, user_task: String):
    # 1. 基于当前任务检索最相关的 Memory
    var relevant = MemoryManager.retrieve(user_task, max_items = 15)

    # 2. 按 category 分组
    var tech_decisions = relevant.filter(func(m): return m.category == MemoryCategory.TECH_DECISION)
    var pitfalls = relevant.filter(func(m): return m.category == MemoryCategory.PITFALL)
    var patterns = relevant.filter(func(m): return m.category == MemoryCategory.CODE_PATTERN)
    var dependencies = relevant.filter(func(m): return m.category == MemoryCategory.FILE_DEPENDENCY)

    # 3. 注入到 system prompt 的上下文中
    var memory_context = "## 项目长期记忆\n"
    if not tech_decisions.is_empty():
        memory_context += "### 技术决策\n"
        for m in tech_decisions:
            memory_context += "- %s: %s\n" % [m.title, m.content]
    if not pitfalls.is_empty():
        memory_context += "### 踩过的坑\n"
        for m in pitfalls:
            memory_context += "- ⚠️ %s: %s\n" % [m.title, m.content]
    # ...

    return memory_context
```

### Memory 存储

```
{config_dir}/.alpha/
└── memory/
    ├── index.json          # 索引
    └── items/
        ├── {uuid_1}.json
        └── ...
```

### Memory 与现有工具

Memory 存储为 `.alpha/memory/` 目录下的 JSON 文件。Alpha 使用现有的 `read_file` / `write_file` 工具即可读写。Memory 的检索和上下文注入由 Harness 内部完成，无需 LLM 手动调用。用户也可以直接通过文件系统查看和编辑记忆文件。

### 与现有 Memory 的迁移

现有 `global_memory` 和 `project_memory`（`Array[String]`）作为 `CUSTOM` 类型导入，`confirmed = true`。迁移后删除旧字段。

---

## 6. Soul — 用户画像

### 定位

Soul 分析**用户的使用习惯和偏好**，而非项目属性。它回答的问题是：这个开发者喜欢怎么写代码？偏好什么架构风格？常用什么实现模式？

### 分析维度

| 维度 | 数据来源 | 分析方式 | 产出示例 |
|------|---------|---------|---------|
| **编码风格** | Log 中写入的脚本内容 | 统计关键词频率 | "用户偏好使用信号而非直接方法调用" |
| **架构倾向** | Docs 中的设计方案 | 识别重复的架构模式 | "用户倾向于数据驱动设计，数值放在 Resource 中" |
| **命名习惯** | Memory 中的 `CODE_PATTERN` | 统计命名规律 | "变量使用 snake_case，类名使用 PascalCase" |
| **交互模式** | 对话历史和 Log | 统计任务类型分布 | "用户 70% 的任务涉及场景编辑，30% 涉及脚本" |
| **容错偏好** | Log 中的 ERROR + 后续操作 | 分析错误处理方式 | "用户倾向于先看到完整错误信息再决定修复方案" |

### Soul 文件

```
{config_dir}/.alpha/
└── SOUL.json          # 结构化 JSON（非 Markdown）
```

```json
{
  "updated_at": 1718700000,
  "coding_style": {
    "prefers_signals_over_direct_calls": true,
    "prefers_static_typing": true,
    "naming": {
      "variables": "snake_case",
      "classes": "PascalCase",
      "constants": "UPPER_SNAKE_CASE"
    }
  },
  "architecture": {
    "prefers_data_driven": true,
    "prefers_composition_over_inheritance": false,
    "common_patterns": ["StateChart", "EventBus", "Resource-based config"]
  },
  "interaction": {
    "primary_task_type": "scene_editing",
    "prefers_detailed_planning": true,
    "review_frequency": "every_step"
  },
  "pain_points": [
    "AnimationPlayer 动画库管理",
    "多场景间的信号连接"
  ]
}
```

### Soul 的更新方式

- **被动更新**：Dream 运行后，同步分析用户的最新行为
- **手动修正**：用户可以随时编辑 SOUL.json 纠正分析偏差
- **权重衰减**：旧的行为数据随时间衰减，新数据权重更高

### Soul 的使用方式

Soul 不直接注入到对话上下文（那会占用过多 token），而是用于：

1. **影响 Alpha 的默认行为**：例如知道用户偏好信号，Alpha 生成代码时会优先使用信号
2. **影响 CC 提示词中的约束**：委派 CC 时，Soul 中的编码风格作为强制约束
3. **影响 Dream 的分析重点**：Soul 中的 `pain_points` 会引导 Dream 更关注相关领域

### Soul 与现有工具

Soul 存储为 `.alpha/SOUL.json` 文件。Alpha 使用现有的 `read_file` / `write_file` 工具即可读写。Soul 的分析和更新由 Harness 内部完成。用户也可以直接编辑 SOUL.json 修正分析偏差。

---

## 完整数据流

```
┌──────────────────────────────────────────────────────────────┐
│                        一次对话                                │
│                                                              │
│  [对话开始]                                                   │
│     │                                                        │
│     ├── Hook: session.start                                  │
│     ├── Memory 加载到上下文（替代现有 memory）                  │
│     │                                                        │
│     ▼                                                        │
│  [Alpha 执行任务]                                             │
│     │                                                        │
│     ├── Hook: tool.pre → tool.post                           │
│     │   └── log_writer.gd → 写入 Log                         │
│     │                                                        │
│     ├── 设计方案完成 → write_doc → 保存到 Docs/               │
│     │                                                        │
│     ▼                                                        │
│  [对话结束]                                                   │
│     │                                                        │
│     ├── Hook: session.end                                    │
│     ├── 检查 Log 新增数量 ≥ 20? → 触发 Dream                 │
│     │                                                        │
│     ▼                                                        │
│  [Dream 反思]                                                 │
│     │                                                        │
│     ├── 读取 Log（最近未反思的操作）                           │
│     ├── 读取 Docs（最近新增/更新的方案）                       │
│     ├── 分析 → 生成 Memory 条目                               │
│     ├── 分析 → 更新 Soul                                     │
│     │                                                        │
│     ▼                                                        │
│  [下次对话] → Memory 中的新条目被加载到上下文                  │
└──────────────────────────────────────────────────────────────┘
```

### 数据关系图

```
Hook ──监听──→ 工具调用 ──写入──→ Log (操作记录, ≤200条)
                                      │
                                      │ Dream 读取
                                      ▼
Docs (设计方案.md) ──Dream 读取──→ Dream (反思引擎)
                                      │
                              ┌───────┴───────┐
                              ▼               ▼
                         Memory (长期记忆)   Soul (用户画像)
                              │
                              │ 对话开始时加载
                              ▼
                         Alpha 上下文
```

---

## 技术架构

### 新增文件

```
addons/agent/
└── harness/
    ├── harness_manager.gd              # Harness 入口，管理所有子系统
    │
    ├── log/
    │   ├── log_manager.gd              # Log CRUD + 200 条 FIFO
    │   └── log_entry.gd                # LogEntry 数据结构
    │
    ├── docs/
    │   ├── docs_manager.gd             # Docs CRUD + INDEX.md 维护
    │   └── doc_templates/              # 设计文档模板
    │       ├── design_template.md
    │       └── decision_template.md
    │
    ├── dream/
    │   └── dream_engine.gd             # 反思引擎：Log+ Docs → Memory + Soul
    │
    ├── memory/
    │   ├── memory_manager.gd           # Memory CRUD + 检索 + 上下文注入
    │   ├── memory_item.gd              # MemoryItem 数据结构
    │   ├── memory_retriever.gd         # 相关性评分 + 检索
    │   └── memory_migrator.gd          # 旧 Array[String] → 新 MemoryItem
    │
    ├── soul/
    │   ├── soul_analyzer.gd            # 用户行为分析引擎
    │   └── soul_profile.gd             # Soul 数据结构 + 读写
    │
    └── hook/
        ├── hook_manager.gd             # Hook 注册/匹配/执行
        ├── hook_executor_gdscript.gd   # GDScript Hook 执行器
        ├── hook_executor_cmd.gd        # CMD Hook 执行器
        └── hooks/                      # 内置 Hook
            └── log_writer.gd           # tool.post → Log（默认启用）
```

> **注意**：Harness 不新增 LLM 可调用的工具。所有 Harness 数据（Log/Docs/Memory/Soul/Hook 配置）均为标准文件（.json / .md），使用现有的 `read_file` / `write_file` / `update_script_file_content` 工具即可操作。

### 核心类关系

```
HarnessManager
├── LogManager
│   └── log_entries: Array[LogEntry]     # FIFO, max 200
├── DocsManager
│   └── docs_dir: String                 # 项目 docs/ 路径
├── DreamEngine
│   ├── 依赖 LogManager (读取操作记录)
│   ├── 依赖 DocsManager (读取设计方案)
│   ├── 产出到 MemoryManager (写入记忆)
│   └── 产出到 SoulAnalyzer (更新画像)
├── MemoryManager
│   ├── MemoryRetriever (检索)
│   ├── MemoryMigrator (迁移)
│   └── 信号: memory_updated
├── SoulAnalyzer
│   └── SOUL.json 读写
└── HookManager
    ├── HookExecutorGDScript
    ├── HookExecutorCMD
    └── hooks.json 读写
```

### 与现有系统的修改点

| 文件 | 修改内容 |
|------|---------|
| `agent.gd` | `_enter_tree` 中初始化 `HarnessManager` |
| `main_panel.gd` | `send_messages()` 前调用 `MemoryManager.retrieve()` 注入上下文；触发 `session.start` / `session.end` |
| `tools.gd` | `use_tool()` 前后触发 `tool.pre` / `tool.post` Hook |
| `agent_singleton.gd` | 新增 harness 相关信号 |
| `setting.gd` | 添加 Harness 配置项 |
| `config.tres` | 移除旧 `project_memory` / `global_memory` 字段 |

---

## 配置项

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `harness_enabled` | bool | true | 是否启用 Harness |
| `harness_log_max_entries` | int | 200 | Log 最大条目数 |
| `harness_docs_dir` | string | `"res://docs/"` | Docs 存储目录 |
| `harness_dream_auto_trigger` | int | 20 | Log 新增 N 条后自动触发 Dream |
| `harness_dream_max_memories` | int | 5 | 每次 Dream 最多生成 N 条 Memory |
| `harness_dream_on_session_end` | bool | true | 对话结束时是否触发 Dream |
| `harness_memory_context_limit` | int | 15 | 对话开始时注入的最大 Memory 条数 |
| `harness_hook_config_path` | string | `"res://.alpha/hooks.json"` | Hook 配置文件路径 |

---

## 实现阶段

### Phase 1: 数据基础（2 个子系统）

1. **Log** — 操作日志
   - LogEntry 数据结构
   - 200 条 FIFO 管理
   - 内置 `log_writer.gd` Hook 自动写入

2. **Docs** — 设计文档
   - DocsManager：INDEX.md 自动维护
   - 设计文档模板

### Phase 2: 知识沉淀（2 个子系统）

3. **Dream** — 反思引擎
   - DreamEngine：Log → Memory 分析管道
   - 自动触发 + `/dream` 命令手动触发

4. **Memory** — 长期记忆
   - MemoryItem 数据结构 + 存储
   - 旧 Array[String] 迁移
   - 上下文注入（替换现有 memory 逻辑）

### Phase 3: 高级特性（2 个子系统）

5. **Soul** — 用户画像
   - SoulAnalyzer 行为分析引擎
   - SOUL.json 读写

6. **Hook** — 生命周期钩子
   - HookManager 事件系统
   - GDScript + CMD 双执行器
   - 注：Phase 1 中 `log_writer.gd` 已作为内置 Hook 实现，此阶段完善 Hook 管理功能

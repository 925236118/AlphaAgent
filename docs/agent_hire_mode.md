# Agent 雇佣模式（Agent Hire Mode）

## 功能概述

Agent 雇佣模式是 Alpha Agent 的一种全新工作模式。在该模式下，Alpha 不再直接执行用户的编程任务，而是扮演"架构师 + 审核员"的角色：先调研、再规划，然后将具体执行雇佣给外部 AI 编码 Agent 子进程，最后用只读工具验证执行结果。

**当前支持的执行 Agent**：Claude Code (CC) / Pi。后续可能添加 OpenCode 等。

### 与传统模式的对比

| 阶段 | 传统模式（Direct） | 雇佣模式（Hire） |
|------|-------------------|--------------------------|
| 调研 | ❌ 无，直接执行 | ✅ Alpha 使用只读工具调研项目上下文 |
| 规划 | ⚠️ 可选，通过 update_plan_list | ✅ Alpha 必须拆分步骤并生成 CC 可执行的任务 |
| 执行 | Alpha 逐工具调用执行 | CC 子进程自主执行（拥有完整读写能力） |
| 验证 | ❌ 无 | ✅ Alpha 使用只读工具检查 CC 的修改 |
| 失败处理 | 重新对话 | ✅ Alpha 分析失败原因，构造修复建议，CC 在同一 session 中修复 |

### 核心工作流（含失败修复循环）

```
用户输入任务
    │
    ▼
┌──────────────────────────────────────────────┐
│  Phase 1: RESEARCH（调研）- 由 Alpha 完成     │
│  Alpha 使用只读工具收集上下文：                │
│  · read_file / global_search                 │
│  · list_scene_nodes / get_project_file_list  │
│  · read_script_outline / resource_inspector   │
│  产出：项目上下文摘要                          │
└──────────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────────┐
│  Phase 2: PLAN（规划）- 由 Alpha 完成         │
│  Alpha 将任务拆分为可执行的步骤：               │
│  · 调用 update_plan_list 创建步骤列表          │
│  · 每个步骤需包含明确的输入/输出/验收标准        │
│  产出：N 个有序执行步骤 → 展示给用户确认         │
└──────────────────────────────────────────────┘
    │ 用户确认 / 修改 / 重新规划
    ▼
┌──────────────────────────────────────────────┐
│  Phase 3: HIRE（雇佣执行）- 外部 Agent 执行       │
│  对每个步骤：                                  │
│  · Alpha 为整个步骤创建一个 CC session         │
│  · 通过管道发送任务给 CC 子进程                │
│  · 实时读取 CC 的 stream-json 输出             │
│  · 展示给用户                                  │
│  产出：CC 完成文件修改                          │
└──────────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────────┐
│  Phase 4: VERIFY（验证）- Alpha 验证          │
│  Alpha 使用只读工具检查结果：                   │
│  · 逐项检查验收标准                             │
│  · read_file / check_script_error             │
│  · read_script_outline / list_scene_nodes     │
│  ┌──────────────────────────────────────┐    │
│  │ 验证结果：                            │    │
│  │  ✅ PASS → 进入下一步骤               │    │
│  │  ⚠️ WARN → 记录警告，继续执行         │    │
│  │  ❌ FAIL → 进入修复循环 ────────┐     │    │
│  │  🔄 LOGIC_ERROR → 用户重新规划  │     │    │
│  └──────────────────────────────────│──┘    │
└──────────────────────────────────────│──────┘
                                       │
    ┌──────────────────────────────────┘
    ▼
┌──────────────────────────────────────────────┐
│  FIX LOOP（修复循环 - 同一 CC Session 内）     │
│  1. Alpha 分析失败原因                         │
│  2. Alpha 构造修复建议（含具体代码位置和方案）   │
│  3. Alpha 在同一 CC session 中发送修复指令      │
│  4. CC 执行修复                                │
│  5. Alpha 重新验证                             │
│  · 最多重试 N 次（可配置，默认 2 次）            │
│  · 超出重试次数 → 报告用户，等待人工干预         │
└──────────────────────────────────────────────┘
```

---

## 模式切换

### 入口

通过**两种方式**切换雇佣模式，互相同步：

1. **设置面板**：`设置 → 雇佣 → ☑ 开启雇佣模式`（默认关闭）
2. **首页 LinkButton**：位于欢迎消息下方的快捷入口

### 首页 LinkButton

位置：`ScrollContainer/MarginContainer/BackgroundPanelContainer/VBoxContainer/Containers/ChatContainer/WelcomeMessage/PanelContainer/VBoxContainer/Description` 下。

| 雇佣模式状态 | 按钮文案 | 点击行为 |
|-------------|---------|---------|
| 关闭 | `切换到雇佣模式 →` | 开启雇佣模式，等同于设置中勾选 |
| 开启 | `← 回到默认模式` | 关闭雇佣模式，等同于设置中取消勾选 |

### 首页行为变化

| 元素 | 雇佣模式关闭 | 雇佣模式开启 |
|------|------------|------------|
| 角色选择器 | ✅ 显示 | ❌ 隐藏 |
| LinkButton | "切换到雇佣模式 →" | "← 回到默认模式" |
| Agent 状态 | 不显示 | 显示 Agent 检测状态 |

### 设置面板

开启雇佣模式后，设置面板展示：

```
┌─────────────────────────────────────────────────┐
│  雇佣设置                                         │
│  ┌─────────────────────────────────────────┐    │
│  │ ☑ 开启雇佣模式                           │    │
│  │                                          │    │
│  │ 执行 Agent: [Claude Code ▼]              │    │
│  │             (当前仅可选 CC / Pi)           │    │
│  │                                          │    │
│  │ Agent 状态: ✅ CC (v2.1.150) 已就绪       │    │
│  │             [重新检测]                    │    │
│  │                                          │    │
│  │ [安装 CC Skills]                         │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

### 对话锁定规则

**Agent 选择在使用中锁定**：对话一旦开始，该对话全程使用对话开始时选定的 Agent，中途去设置页修改 Agent 不会影响已开始的对话。Agent 选择会保存在历史记录中。

新对话开始时，首页输出提示：

> 🔁 您当前处于雇佣模式，我们已为您雇佣 **Claude Code**。对话期间无法修改选择的 Agent。如需更换 Agent，请开启新对话。

### 初始化流程（雇佣仪式）

切换回首页且 `_env_checked == false` 时，自动运行初始化检测：

```
┌──────────────────────────────────────────────────┐
│  ⏳ 正在发布招聘广告...                           │
│     (启动 Agent 子进程，建立管道)                  │
│                                                   │
│     → 成功: 进入下一步                            │
│     → 失败: "Agent 拒绝了您的 offer，请检查环境"   │
│              (提示用户检查安装、PATH、API Key)      │
└──────────────────────────────────────────────────┘
    │ 成功
    ▼
┌──────────────────────────────────────────────────┐
│  ⏳ Claude Code 正在面试中...                      │
│     (运行 claude --version，验证可执行)            │
│                                                   │
│     → 成功: 进入下一步                            │
│     → 失败: "面试未通过，请检查安装"               │
└──────────────────────────────────────────────────┘
    │ 成功
    ▼
┌──────────────────────────────────────────────────┐
│  ✅ Claude Code 已经雇佣成功，员工版本 v2.1.150    │
│     (Agent 就绪，可以开始对话)                     │
└──────────────────────────────────────────────────┘
```

失败时：

```
┌──────────────────────────────────────────────────┐
│  ❌ Claude Code 拒绝了您的 offer，请检查           │
│     · 未找到 claude 命令                          │
│     · 请确保 Claude Code 已安装并在 PATH 中        │
│     · 安装指南: https://docs.anthropic.com/...    │
│                                                   │
│     [重新检测]  [更换 Agent]                       │
│     （检测通过前无法发送对话）                      │
└──────────────────────────────────────────────────┘
```

### 实现

```gdscript
class AgentHireInitializer:
    var _selected_agent: String = "cc"  # "cc" | "pi"
    var _env_checked: bool = false
    var _agent_ready: bool = false

    signal init_step(step: String, status: String, message: String)
    # step: "advertise" | "interview" | "result"
    # status: "running" | "success" | "failed"

    func initialize(agent_type: String):
        _selected_agent = agent_type

        # Step 1: 发布招聘广告（where/which 检测 PATH）
        init_step.emit("advertise", "running", "正在发布招聘广告...")
        var checker = _get_checker(agent_type)
        if not checker.check_availability():
            init_step.emit("advertise", "failed",
                "%s 拒绝了您的 offer，请检查\n· 未找到 %s 命令\n· 请确保已安装并在 PATH 中" % [agent_type, agent_type])
            _agent_ready = false
            _env_checked = true
            return

        # Step 2: 面试（--version 检测可运行）
        init_step.emit("interview", "running", "%s 正在面试中..." % checker.agent_name)
        var version = checker.get_version()
        if version == "":
            init_step.emit("interview", "failed", "面试未通过，请检查安装")
            _agent_ready = false
            _env_checked = true
            return

        # Step 3: 雇佣成功
        init_step.emit("result", "success",
            "%s 已经雇佣成功，员工版本 %s" % [checker.agent_name, version])
        _agent_ready = true
        _env_checked = true

    func get_checker(agent_type: String):
        match agent_type:
            "cc": return CCChecker.new()
            "pi": return PiChecker.new()
        return null

    func is_ready() -> bool:
        return _agent_ready

    func reset():
        _env_checked = false
        _agent_ready = false
```

### 检测失败时禁止对话

`send_messages()` 中增加判断：

```gdscript
func send_messages():
    if hire_mode_enabled:
        if not hire_initializer.is_ready():
            push_error("Agent 未就绪，无法发送对话。请等待初始化完成或检查 Agent 环境。")
            return
        # 输出雇佣提示
        _show_hire_notice()
        # 进入雇佣模式流程
        _start_hire_workflow(messages)
        return
    # ... 原有 Direct 模式流程
```

### 状态保存

| 状态 | 存储位置 | 持久化 |
|------|---------|--------|
| `hire_mode_enabled` | `{config_dir}/.alpha/setting.json` | ✅ 跨会话保留 |
| `hire_agent` | `{config_dir}/.alpha/setting.json` | ✅ 跨会话保留 |
| `_env_checked` | 运行时变量 | ❌ 重启后重置，触发重新检测 |
| `_agent_ready` | 运行时变量 | ❌ |
| 对话使用的 Agent | 历史记录 `history.json` | ✅ 回放时还原 |

---

## Phase 1: RESEARCH（调研）

### 目标

Alpha 在接到任务后，不立即执行，而是先利用只读工具充分理解项目上下文。

**此阶段完全由 Alpha 自己完成**，不涉及 CC。

### 可用工具

仅限 `_get_tool_readonly() == true` 的工具：

| 工具 | 用途 |
|------|------|
| `read_file` | 读取相关文件内容 |
| `get_project_file_list` | 了解项目文件结构 |
| `global_search` | 搜索相关代码符号 |
| `read_script_outline` | 查看脚本结构（类/方法/信号） |
| `list_scene_nodes` | 查看场景节点树 |
| `get_class_doc` | 查阅 Godot 类文档 |
| `resource_inspector` | 查看资源文件结构 |
| `get_animation_info` | 查看动画详情 |
| `get_animation_player_detail` | 查看 AnimationPlayer 信息 |
| `check_script_error` | 检查脚本静态错误 |
| `get_editor_info` | 获取编辑器当前状态 |
| `get_project_info` | 获取项目配置信息 |
| `get_tileset_info` | 获取 TileSet 信息 |
| `get_image_info` | 获取图片文件信息 |
| `get_input_mappings` | 获取输入映射配置 |

### 产出格式

```json
{
  "phase": "research_complete",
  "summary": "任务需要在 player.tscn 的 Player 节点上添加一个 dash 技能...",
  "related_files": [
    "res://scenes/player/player.tscn",
    "res://scripts/player/player.gd",
    "res://scripts/player/movement.gd"
  ],
  "key_locations": [
    {"file": "res://scripts/player/movement.gd", "line_range": "45-78", "reason": "移动逻辑集中在此区域"}
  ],
  "risks": ["movement.gd 被多个场景引用，修改需谨慎"],
  "suggested_order": ["先修改 movement.gd", "再更新 player.tscn 动画引用", "最后测试"]
}
```

---

## Phase 2: PLAN（规划）

### 目标

基于调研结果，将用户任务拆分为 CC 可执行的、有序的、可验证的步骤。

**此阶段完全由 Alpha 自己完成**。

### 步骤结构

每个步骤包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `title` | string | 步骤标题，如"在 movement.gd 中添加 dash() 方法" |
| `description` | string | 详细描述，CC 可以直接理解并执行 |
| `context` | string | 从调研阶段收集的相关上下文（代码片段、文件路径等） |
| `acceptance_criteria` | string[] | 验收标准列表，用于验证阶段 |
| `expected_files` | string[] | 预期会被修改的文件列表 |
| `depends_on` | int[] | 依赖的前置步骤索引 |

### 用户确认与干预

计划生成后，Alpha 必须**暂停并展示给用户确认**。用户可以：
- ✅ 确认执行全部步骤
- 📝 修改某个步骤的描述
- ❌ 取消任务
- 🔄 要求重新规划

### 逻辑错误时的重新规划

如果验证阶段发现**逻辑错误**（LOGIC_ERROR，即代码能运行但行为不符合预期），说明计划本身可能有问题。此时 Alpha 应：
1. 将已验证的信息（哪些步骤通过了、哪些有问题）反馈给用户
2. 用户输入新的计划指令
3. Alpha 基于用户指令重新规划（可能复用部分已验证步骤）

---

## Phase 3: HIRE（雇佣执行）

### Agent 可用性检测

检测方法封装在 `AgentHireInitializer` 中（见上方"初始化流程"）。核心逻辑：

```gdscript
class CCChecker:
    var is_available: bool = false
    var cc_path: String = ""
    var cc_version: String = ""
    var error_message: String = ""

    func check() -> bool:
        var find_cmd: String
        match OS.get_name():
            "Windows":
                find_cmd = "where claude"
            "Linux", "macOS":
                find_cmd = "which claude"

        var output = []
        var exit_code = OS.execute(find_cmd.split(" ")[0],
            PackedStringArray(find_cmd.split(" ").slice(1)), output, true)
        if exit_code != 0:
            error_message = "未找到 claude 命令。请确保 Claude Code 已安装并在 PATH 中。"
            return false

        cc_path = output[0].strip_edges() if output.size() > 0 else "claude"
        output.clear()
        exit_code = OS.execute(cc_path, PackedStringArray(["--version"]), output, true)
        if exit_code != 0:
            error_message = "claude 命令执行失败 (exit code: %d)。" % exit_code
            return false

        cc_version = output[0].strip_edges() if output.size() > 0 else "unknown"
        is_available = true
        return true

    func get_status_text() -> String:
        if is_available:
            return "CC 就绪: %s (v%s)" % [cc_path, cc_version]
        else:
            return "CC 不可用: %s" % error_message
```

### Session 管理策略

每个步骤维护一个独立的 CC session，用于保持该步骤内的上下文连续性：

| 场景 | Session 行为 |
|------|-------------|
| **步骤首次执行** | 创建新 session，CC 在 stream-json 输出中返回 session_id |
| **验证失败后修复** | 在同一 session 中继续，发送修复指令（保持上下文） |
| **步骤重试** | 在同一 session 中继续（CC 能看到之前的修改和错误） |
| **进入下一步骤** | 结束当前 session，为下一步骤创建新 session |

**Session ID 由 CC 返回**：CC 在首次对话的 stream-json 输出中会返回一个 `session_id` 字段，Alpha 需要捕获并保存它。后续在同一 session 中继续对话时，使用 `--session-id` 参数传入该 ID。

```gdscript
# Session 管理伪代码
class CCSessionManager:
    var _current_session_id: String = ""  # 由 CC 返回，不是 Alpha 生成
    var _session_step_index: int = -1

    func capture_session_id(cc_output: String):
        # 从 CC 的 stream-json 输出中解析 session_id
        # 示例: {"type":"system","session_id":"abc123",...}
        for line in cc_output.split("\n"):
            var json = JSON.parse_string(line)
            if json and json.has("session_id"):
                _current_session_id = json["session_id"]
                break

    func is_same_step(step_index: int) -> bool:
        return step_index == _session_step_index and _current_session_id != ""

    func start_cc_for_step(step, step_index: int, is_fix: bool):
        if is_fix and _current_session_id != "":
            # 在同一 session 中继续对话（修复场景）
            return 'claude --session-id "%s" --output-format stream-json --verbose' % _current_session_id
        else:
            # 新步骤 = 新 session，不传 --session-id，由 CC 自动创建
            _session_step_index = step_index
            _current_session_id = ""  # 重置，等待 CC 返回新的 session_id
            return 'claude --output-format stream-json --verbose'
```

### CC 子进程管理

#### 启动

使用 `OS.execute_with_pipe` 以非阻塞模式启动 CC 子进程。

```gdscript
class CCProcessManager:
    var _stdio: FileAccess
    var _stderr: FileAccess
    var _pid: int
    var _shell_path: String
    var _current_session_id: String  # 由 CC 返回的 session_id

    func start() -> bool:
        match OS.get_name():
            "Windows":
                _shell_path = "cmd.exe"
            "Linux", "macOS":
                _shell_path = "/bin/sh"

        var result = OS.execute_with_pipe(_shell_path, PackedStringArray(), false)
        if not result or result.is_empty():
            return false

        _stdio = result["stdio"]
        _stderr = result["stderr"]
        _pid = result["pid"]
        return true

    func start_new_session() -> bool:
        # 不自行生成 session_id，由 CC 首次调用时返回
        _current_session_id = ""
        return start()
```

### 模型透传策略

#### 第一阶段：仅支持 DeepSeek

初期仅支持将 DeepSeek 模型透传给 CC。原因：
- DeepSeek 是 OpenAI 兼容接口，CC 原生支持通过环境变量配置
- 用户已在使用 DeepSeek 作为 Alpha 的 provider
- 减少初期开发复杂度

```gdscript
func configure_cc_deepseek(model_config: Dictionary):
    # DeepSeek 通过 OpenAI 兼容接口配置
    OS.set_environment("ANTHROPIC_BASE_URL", model_config.base_url)
    OS.set_environment("ANTHROPIC_API_KEY", model_config.api_key)
    OS.set_environment("ANTHROPIC_MODEL", model_config.model)
    # DeepSeek 特殊标记
    OS.set_environment("ANTHROPIC_CUSTOM_PROVIDER", "openai-compatible")
```

#### 后续扩展：通用模型透传

后续版本支持更多厂商（OpenAI、Gemini 等），通过统一的配置映射表实现。

#### 用户选项：是否使用 Alpha 的模型

在设置面板中提供一个开关：

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `cc_use_alpha_model` | bool | true | 为 true 时 CC 沿用 Alpha 当前配置的模型和 API Key；为 false 时 CC 使用用户自己配置的模型 |

**当 `cc_use_alpha_model = true` 时**，Alpha 在启动 CC 子进程前设置环境变量透传模型配置（仅支持 DeepSeek）。

**当 `cc_use_alpha_model = false` 时**，Alpha **不设置任何模型相关环境变量**。此时认为用户已自行配置好 CC 的模型（通过 `~/.claude/settings.json`、`.claude/settings.json` 或 shell 环境变量）。Alpha 只负责构造提示词和管理 session。

```gdscript
func configure_cc_environment(model_config: Dictionary):
    if not global_settings.get("cc_use_alpha_model", true):
        # 用户自行配置 CC 模型，Alpha 不干预
        return

    # 仅透传 DeepSeek（第一阶段）
    OS.set_environment("ANTHROPIC_BASE_URL", model_config.base_url)
    OS.set_environment("ANTHROPIC_API_KEY", model_config.api_key)
    OS.set_environment("ANTHROPIC_MODEL", model_config.model)
    OS.set_environment("ANTHROPIC_CUSTOM_PROVIDER", "openai-compatible")
```

### 提示词构造

每个步骤的提示词需包含：

```
你是 Claude Code，一个在 Godot 4 项目中的代码助手。
当前工作目录是 Godot 项目的根目录。

## 项目上下文
{从调研阶段收集的相关文件内容}

## 当前任务
{步骤标题}

## 详细说明
{步骤描述}

## 验收标准
{验收标准列表}

## 约束
- 只修改预期范围内的文件
- 保持现有代码风格一致
- 完成后不要进行额外操作
- 每次修改后检查语法是否正确
```

通过管道发送给 CC：

通过临时文件 + 管道发送给 CC（避免 echo 的编码问题，尤其是 Windows 下中文字符）：

```gdscript
# 提示词文件路径（在项目 .alpha 临时目录下）
const TEMP_PROMPT_FILE = "user://.alpha/cc_temp_prompt.txt"

func send_task_to_cc(task_prompt: String, session_id: String, is_new: bool):
    # Step 1: 将提示词写入临时文件（Godot 的 FileAccess 自动处理 UTF-8 编码）
    var file = FileAccess.open(TEMP_PROMPT_FILE, FileAccess.WRITE)
    if not file:
        printerr("无法写入临时提示词文件: ", TEMP_PROMPT_FILE)
        return
    file.store_string(task_prompt)
    file.close()

    # Step 2: 根据平台选择管道命令
    # 将 res:// 路径转为绝对路径
    var abs_path = ProjectSettings.globalize_path(TEMP_PROMPT_FILE)

    var command: String
    var cc_args = "--output-format stream-json --verbose"
    if session_id != "":
        cc_args += ' --session-id "%s"' % session_id

    match OS.get_name():
        "Windows":
            # cmd.exe: type 读取文件 → 管道 → claude
            command = 'type "%s" | claude %s\n' % [abs_path, cc_args]
        "Linux", "macOS":
            # /bin/sh: cat 读取文件 → 管道 → claude
            command = 'cat "%s" | claude %s\n' % [abs_path, cc_args]

    # Step 3: 通过 shell 管道发送给 CC
    _write_to_stdin(command)
```

#### 修复提示词

当验证失败时，Alpha 构造修复提示词在同一 session 中发送：

```
## 上次执行的问题

验证步骤发现以下问题：
{逐条列出失败项及具体位置}

## 修复要求

{针对每个失败项的具体修复方案，包含文件路径、行号、期望行为}

## 注意
- 只修改需要修复的部分，不要改动已验证正确的代码
- 修复后验证是否符合验收标准
```

### 输出解析

CC 使用 `--output-format stream-json` 输出，逐行解析 JSON 流。流中包含：
- `assistant` 类型的文本消息
- `tool_use` 类型的工具调用记录
- `tool_result` 类型的工具执行结果
- `result` 类型的最终结果

### 实时展示

CC 的输出应实时展示在聊天界面中。为 CC 输出创建专用的 UI 组件：

| 消息类型 | 展示方式 |
|---------|---------|
| CC 的文本输出 | 缩进的代码块样式，灰色背景 |
| CC 的工具调用 | 折叠面板，显示工具名和参数 |
| CC 的错误输出 | 红色高亮 |
| CC 完成标记 | 绿色完成图标 |

### 执行控制

| 操作 | 说明 | 实现 |
|------|------|------|
| **暂停** | 发送 Ctrl+C 信号中断当前步骤（不终止 CC 进程） | 见下方"Ctrl+C 信号发送机制" |
| **跳过** | 跳过当前步骤，标记为"已跳过" | 直接标记 step 状态 |
| **终止** | 终止 CC 进程，进入验证阶段 | 先尝试 Ctrl+C，超时后 `OS.kill()` |
| **重试** | 在同一 session 中重新发送当前步骤 | 重新写入提示词文件 + 管道命令 |

#### Ctrl+C 信号发送机制

由于 CC 通过管道与 shell 通信（stdin 不是真正的 TTY），发送 Ctrl+C 需要多级回退策略：

```
用户点击 [暂停]
    │
    ▼
┌────────────────────────────────────────────────┐
│  Level 1: 写入 \x03 (ETX) 到 stdin 管道         │
│  · 这是 Ctrl+C 的 ASCII 字节                     │
│  · CC 如果处理 stdin 控制字符，会收到中断         │
│  · 等待 2 秒观察 CC 是否停下                      │
│  适用: 全平台                                    │
└────────────────────────────────────────────────┘
    │ 2 秒后 CC 仍在运行
    ▼
┌────────────────────────────────────────────────┐
│  Level 2: 平台特定信号                           │
│  Linux/macOS: kill -INT <shell_pid>             │
│    → SIGINT 发送给 shell，shell 转发给子进程组    │
│  Windows: 无直接等价信号                         │
│    → 跳过此级，进入 Level 3                      │
│  适用: Linux/macOS                              │
└────────────────────────────────────────────────┘
    │ 2 秒后 CC 仍在运行
    ▼
┌────────────────────────────────────────────────┐
│  Level 3: 关闭 stdin 管道（发送 EOF）            │
│  · CC 读到 EOF 后会自然退出                      │
│  · 副作用：无法在同一 session 中继续，需新建       │
│  适用: 全平台                                    │
└────────────────────────────────────────────────┘
    │ 2 秒后 CC 仍在运行
    ▼
┌────────────────────────────────────────────────┐
│  Level 4: OS.kill(pid) 强制终止                  │
│  · SIGKILL（Linux/macOS）/ TerminateProcess（Win）│
│  · 最后手段，确保进程终止                         │
│  适用: 全平台                                    │
└────────────────────────────────────────────────┘
```

```gdscript
class CCProcessController:
    var _stdio: FileAccess
    var _shell_pid: int
    const LEVEL_TIMEOUT = 2.0  # 每级等待秒数

    func pause() -> bool:
        # Level 1: 写入 \x03（Ctrl+C 的 ASCII 码）
        _stdio.store_string("\x03")
        await _wait_and_check(LEVEL_TIMEOUT)
        if not OS.is_process_running(_shell_pid):
            return true  # CC 已停止

        # Level 2: 平台特定信号（仅 Linux/macOS）
        if OS.get_name() in ["Linux", "macOS"]:
            OS.execute("kill", ["-INT", str(_shell_pid)])
            await _wait_and_check(LEVEL_TIMEOUT)
            if not OS.is_process_running(_shell_pid):
                return true

        # Level 3: 关闭 stdin 发送 EOF
        _stdio.close()
        await _wait_and_check(LEVEL_TIMEOUT)
        if not OS.is_process_running(_shell_pid):
            return true

        # Level 4: 强制终止
        OS.kill(_shell_pid)
        return true  # 强制终止总是成功

    func terminate() -> bool:
        # 终止：直接进入 Level 3（关闭 stdin），不等 Level 1/2
        _stdio.close()
        await _wait_and_check(LEVEL_TIMEOUT)
        if not OS.is_process_running(_shell_pid):
            return true
        OS.kill(_shell_pid)
        return true

    func _wait_and_check(timeout: float):
        var elapsed = 0.0
        while elapsed < timeout and OS.is_process_running(_shell_pid):
            await Engine.get_main_loop().create_timer(0.1).timeout
            elapsed += 0.1
```

> **注意**：Ctrl+C 暂停后，CC session 状态取决于 CC 的响应。如果 CC 成功处理了中断，session 可能仍然可用；如果走了 Level 3/4，session 将不可恢复，修复时需新建 session。

## Phase 4: VERIFY（验证）

### 目标

CC 完成一个步骤后，Alpha 使用只读工具验证执行结果是否符合验收标准。

### 验证策略

| 验证维度 | 使用的工具 | 检查内容 |
|---------|-----------|---------|
| **文件变更** | `read_file` | 对比修改前后的文件内容 |
| **语法正确** | `check_script_error` | 检查是否有静态解析错误 |
| **结构完整** | `read_script_outline` | 确认新增的方法/信号/变量存在 |
| **场景正确** | `list_scene_nodes` | 确认场景节点变更正确 |
| **资源完整** | `get_project_file_list` | 确认新文件已创建 |
| **依赖正确** | `resource_inspector` | 确认资源引用路径正确 |

### 验证结果等级

| 等级 | 含义 | 处理 |
|------|------|------|
| **PASS** ✅ | 所有验收标准满足 | 进入下一步骤 |
| **WARN** ⚠️ | 验收标准满足，但有非关键问题 | 记录警告，继续执行。在最终报告中汇总 |
| **FAIL** ❌ | 验收标准不满足（语法错误、文件缺失等） | 进入**修复循环** |
| **LOGIC_ERROR** 🔄 | 代码可运行但行为逻辑不正确 | 暂停，反馈给用户，**用户输入新的计划指令** |

### FAIL 修复循环

```
验证失败 (FAIL)
    │
    ▼
┌──────────────────────────────────────────────┐
│  Alpha 分析失败                               │
│  · 读取失败相关的文件                          │
│  · 定位具体错误位置                            │
│  · 生成修复建议（具体到文件路径 + 行号）         │
└──────────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────────┐
│  Alpha 构造修复指令                            │
│  · 包含当前步骤完整上下文                       │
│  · 明确指出需要修复的部分                       │
│  · 提供期望的正确行为                          │
└──────────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────────┐
│  在同一 CC session 中发送修复指令               │
│  · 使用 --session-id 在同一 session 中继续        │
│  · CC 可以看到之前的修改和错误信息               │
└──────────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────────┐
│  CC 执行修复                                  │
└──────────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────────┐
│  Alpha 重新验证                               │
│  ┌──────────────────────────────────────┐    │
│  │  PASS → 修复成功，进入下一步骤         │    │
│  │  FAIL → 重试次数 < 最大次数？          │    │
│  │        是 → 回到分析步骤              │    │
│  │        否 → 暂停，报告用户人工干预     │    │
│  └──────────────────────────────────────┘    │
└──────────────────────────────────────────────┘
```

#### 修复分析示例

```json
{
  "step_index": 2,
  "step_title": "在 movement.gd 中添加 dash() 方法",
  "failure_analysis": {
    "failed_criteria": [
      "dash() 方法参数签名不正确：应为 func dash(direction: Vector2, speed: float)，实际为 func dash(speed: float)"
    ],
    "root_cause": "CC 未读取 movement.gd 中已有的 move() 方法签名作为参考",
    "fix_suggestion": {
      "file": "res://scripts/player/movement.gd",
      "location": "第 89 行 dash() 方法定义处",
      "expected": "func dash(direction: Vector2, speed: float) -> void:",
      "context": "该方法应与已有的 move(direction: Vector2, speed: float) 保持参数风格一致"
    }
  }
}
```

#### 可配置参数

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `cc_max_fix_retries` | int | 2 | 每个步骤验证失败后的最大自动修复次数 |
| `cc_fix_timeout_seconds` | int | 120 | 单次修复的超时时间（秒） |

### LOGIC_ERROR 处理

当代码语法正确、结构完整，但行为逻辑不符合预期时（如"玩家应该向左移动但实际向右移动了"），属于逻辑错误。此时：

1. Alpha 停止执行，汇总已验证结果
2. 向用户展示哪些步骤通过了验证、哪个步骤有逻辑问题
3. 用户输入新的修正指令
4. Alpha 根据用户的新指令重新规划（可能会复用部分已验证步骤，也可能推翻重来）

```
验证发现 LOGIC_ERROR
    │
    ▼
┌──────────────────────────────────────────────┐
│  Alpha 报告                                   │
│  ✅ Step 1: PASS - 基础结构正确               │
│  ✅ Step 2: PASS - dash 方法已添加            │
│  🔄 Step 3: LOGIC_ERROR - dash 方向与预期相反  │
│                                               │
│  请描述你期望的正确行为，或修改计划：            │
│  [用户输入框]                                  │
└──────────────────────────────────────────────┘
    │ 用户输入
    ▼
  重新进入 Phase 2 (PLAN)
```

---

## CC 的 Skill 和 MCP 支持

### 调研结论

经过对 CC CLI 文档的调研，**CC 在管道/stdin 模式下完全支持 skill 和 MCP**，无需特殊配置。

### 自动发现机制

CC 在启动时会自动加载以下配置（除非使用 `--bare` 标志）：

| 功能 | 配置位置 | 发现方式 |
|------|---------|---------|
| **Skills** | `.claude/skills/<name>/SKILL.md` | 项目目录下自动发现 |
| **Skills** | `~/.claude/skills/<name>/SKILL.md` | 用户级自动发现 |
| **Skills（旧版）** | `.claude/commands/<name>.md` | 向后兼容 |
| **MCP Servers** | `.mcp.json` | 项目目录下自动加载 |
| **MCP Servers** | `~/.claude.json` | 用户级自动加载 |
| **MCP Servers** | `--mcp-config <file>` | CLI 参数显式指定 |
| **CLAUDE.md** | `CLAUDE.md` / `.claude/CLAUDE.md` | 项目目录下自动加载 |
| **Settings** | `.claude/settings.json` | 项目目录下自动加载 |
| **Settings** | `.claude/settings.local.json` | 本地配置自动加载 |
| **Hooks** | `.claude/hooks/` | 自动发现 |
| **Plugins** | 通过 settings.json 配置 | 自动加载 |

### 关键要点

1. **`--bare` 模式会跳过一切**：只有显式使用 `--bare` 才会禁用 skills、MCP、hooks、plugins 等。Alpha 的雇佣模式**不使用 `--bare`**，因此所有配置均正常加载。

2. **`-p` (print) 模式同样加载**：headless/管道模式与交互模式的配置加载行为一致。

3. **CC 和 Alpha 工具隔离**：CC 使用自己的工具体系（Bash、Read、Write、Edit、Glob、Grep 等），Alpha 使用自己的工具体系（read_file、write_file、list_scene_nodes 等）。两者工具不共享，但通过**项目文件系统**作为中介：CC 修改文件后，Alpha 通过只读工具读取文件来验证结果。

4. **为 Alpha 项目预置 CC 配置**：Alpha 可以在项目初始化时自动创建 `.claude/skills/` 和 `.mcp.json`，为 CC 提供 Godot 相关的 skills（如 GDScript 代码规范、Godot 场景结构指南等）。

### 推荐的 CC 预置 Skills

可以在项目中创建以下 CC skills 来增强 CC 的 Godot 开发能力：

```
项目根目录/
├── .claude/
│   ├── settings.json              # CC 权限和配置
│   ├── skills/
│   │   ├── gdscript-style/
│   │   │   └── SKILL.md           # GDScript 代码风格指南
│   │   ├── godot-scene-structure/
│   │   │   └── SKILL.md           # Godot 场景结构规范
│   │   └── godot-animation/
│   │       └── SKILL.md           # Godot 动画系统操作指南
│   └── CLAUDE.md                  # 项目上下文说明
└── .mcp.json                      # MCP 服务器配置（可选）
```

这些 skills 由 Alpha 在首次使用雇佣模式时自动生成，内容基于 Godot 4 的最佳实践。

### 管道模式下的调用示例

```bash
# 首次执行：写入提示词到临时文件，管道传入（跨平台兼容编码）
# Windows: type temp_prompt.txt | claude --output-format stream-json --verbose
# Linux/macOS: cat temp_prompt.txt | claude --output-format stream-json --verbose
# CC 输出中会包含: {"type":"system","session_id":"abc123",...}
# Alpha 捕获 session_id = "abc123"

# 修复时：传入 --session-id 在同一 session 中继续
cat temp_prompt.txt | claude --session-id "abc123" --output-format stream-json --verbose
```

### CC Godot Skills 预置与管理

Alpha 提供一套预置的 CC skills，帮助 CC 更好地理解 Godot 4 项目的规范和最佳实践。这些 skills 以文件形式写入项目的 `.claude/skills/` 目录，CC 启动时自动加载。

#### 预置 Skills 清单

| Skill 名称 | 文件路径 | 内容 |
|-----------|---------|------|
| `gdscript-style` | `.claude/skills/gdscript-style/SKILL.md` | GDScript 代码风格指南：命名规范、类型注解、信号使用 |
| `godot-scene-structure` | `.claude/skills/godot-scene-structure/SKILL.md` | Godot 场景结构规范：节点树组织、场景引用、资源路径 |
| `godot-animation` | `.claude/skills/godot-animation/SKILL.md` | Godot 动画系统操作指南：AnimationPlayer API、轨道类型、关键帧 |

#### 安装检测逻辑

```
Alpha 插件启动 / 切换到雇佣模式
    │
    ▼
┌──────────────────────────────────────────────┐
│  检测 .claude/skills/gdscript-style/SKILL.md  │
│  检测 .claude/skills/godot-scene-structure/   │
│          SKILL.md                             │
│  检测 .claude/skills/godot-animation/         │
│          SKILL.md                             │
│                                               │
│  全部存在 → 无操作                             │
│  部分缺失 → 在设置页面显示"安装 CC Skills"按钮  │
└──────────────────────────────────────────────┘
```

#### 设置页面 UI

在设置面板的"雇佣"分组中增加 Skills 管理区域：

```
┌─────────────────────────────────────────────────┐
│  CC 雇佣设置                                     │
│  ┌─────────────────────────────────────────┐    │
│  │ ☑ 启用 CC 雇佣模式                       │    │
│  │ ☑ CC 沿用 Alpha 模型                     │    │
│  │ ...                                      │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  CC Godot Skills                                │
│  ┌─────────────────────────────────────────┐    │
│  │ ✅ gdscript-style         已安装  [卸载] │    │
│  │ ⚠️ godot-scene-structure 未安装  [安装] │    │
│  │ ✅ godot-animation         已安装  [卸载] │    │
│  │                                         │    │
│  │ [全部安装]  [全部卸载]                   │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

#### 安装/卸载实现

```gdscript
class CCSkillInstaller:
    # Skills 模板存放位置（Alpha 插件自带）
    const SKILL_TEMPLATES_DIR = "res://addons/agent/cc_config/skills/"
    # 目标安装位置（项目根目录）
    const TARGET_DIR = "res://.claude/skills/"

    var skill_list = [
        {
            "name": "gdscript-style",
            "description": "GDScript 代码风格指南"
        },
        {
            "name": "godot-scene-structure",
            "description": "Godot 场景结构规范"
        },
        {
            "name": "godot-animation",
            "description": "Godot 动画系统操作指南"
        }
    ]

    func check_install_status() -> Dictionary:
        var status = {}
        for skill in skill_list:
            var skill_file = TARGET_DIR + skill.name + "/SKILL.md"
            status[skill.name] = FileAccess.file_exists(skill_file)
        return status

    func install_skill(skill_name: String) -> bool:
        var src_dir = SKILL_TEMPLATES_DIR + skill_name + "/"
        var dst_dir = TARGET_DIR + skill_name + "/"

        # 创建目标目录
        DirAccess.make_dir_recursive_absolute(dst_dir)

        # 复制 SKILL.md 及其他文件
        var src = DirAccess.open(src_dir)
        if not src:
            return false
        src.list_dir_begin()
        var file_name = src.get_next()
        while file_name != "":
            if not src.current_is_dir():
                DirAccess.copy_absolute(
                    ProjectSettings.globalize_path(src_dir + file_name),
                    ProjectSettings.globalize_path(dst_dir + file_name)
                )
            file_name = src.get_next()
        src.list_dir_end()
        return true

    func uninstall_skill(skill_name: String) -> bool:
        var dst_dir = TARGET_DIR + skill_name + "/"
        var abs_path = ProjectSettings.globalize_path(dst_dir)

        # 递归删除目录
        var dir = DirAccess.open(dst_dir)
        if not dir:
            return true  # 已不存在，视为成功
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if not dir.current_is_dir():
                DirAccess.remove_absolute(abs_path + file_name)
            file_name = dir.get_next()
        dir.list_dir_end()
        DirAccess.remove_absolute(abs_path)
        return true

    func install_all() -> Dictionary:
        var results = {}
        for skill in skill_list:
            results[skill.name] = install_skill(skill.name)
        return results

    func uninstall_all() -> Dictionary:
        var results = {}
        for skill in skill_list:
            results[skill.name] = uninstall_skill(skill.name)
        return results
```

#### Skills 模板文件结构

```
addons/agent/cc_config/skills/
├── gdscript-style/
│   └── SKILL.md           # GDScript 代码风格指南
├── godot-scene-structure/
│   └── SKILL.md           # Godot 场景结构规范
└── godot-animation/
    └── SKILL.md           # Godot 动画系统操作指南
```

这些模板文件随 Alpha 插件一起分发。安装时从 `addons/agent/cc_config/skills/` 复制到项目根目录的 `.claude/skills/`；卸载时删除对应目录。

---

## Pi Agent 支持

### 与 CC 的对比

| 维度 | Claude Code (CC) | Pi |
|------|-----------------|-----|
| **CLI 模式** | 默认交互模式，通过管道传入 prompt | `--mode json` JSON 事件流模式 |
| **生命周期** | 需手动管理 session（`--session-id`） | 需手动管理 session（`--session <id>`） |
| **Session 管理** | Alpha 捕获 `session_id`，修复时传入 `--session-id` | Alpha 捕获 `session_id`，修复时传入 `--session`，新步骤可 `--fork` |
| **输出格式** | `--output-format stream-json` | `--mode json` 自动输出 JSON 事件流 |
| **模型配置** | 环境变量透传（`ANTHROPIC_*`） | Pi 自己的 settings.json / auth.json |
| **Ctrl+C 处理** | 需要四级回退策略 | 直接 `OS.kill()` 终止进程（session 已持久化在磁盘） |
| **修复循环** | 同一 session 内重试（`--session-id`） | 同一 session 内重试（`--session`） |
| **编码方案** | 临时文件 + `type`/`cat` 管道 | 同左 |
| **预置 Skills** | `.claude/skills/` | `.pi/skills/` |

### Pi 可用性检测

```gdscript
class PiChecker:
    var is_available: bool = false
    var pi_path: String = ""
    var pi_version: String = ""
    var error_message: String = ""

    func check() -> bool:
        var find_cmd: String
        match OS.get_name():
            "Windows":
                find_cmd = "where pi"
            "Linux", "macOS":
                find_cmd = "which pi"

        var output = []
        var exit_code = OS.execute(find_cmd.split(" ")[0],
            PackedStringArray(find_cmd.split(" ").slice(1)), output, true)
        if exit_code != 0:
            error_message = "未找到 pi 命令。请确保 Pi 已安装并在 PATH 中。\n"
            error_message += "安装: npm install -g @earendil-works/pi-coding-agent"
            return false

        pi_path = output[0].strip_edges() if output.size() > 0 else "pi"
        output.clear()
        exit_code = OS.execute(pi_path, PackedStringArray(["--version"]), output, true)
        if exit_code != 0:
            error_message = "pi 命令执行失败 (exit code: %d)。" % exit_code
            return false

        pi_version = output[0].strip_edges() if output.size() > 0 else "unknown"
        is_available = true
        return true
```

### Pi 执行流程

Pi 的 `--mode json` 同样支持 session 管理（`--session <id>` 续接 / `--fork <id>` 分叉）。Ctrl+C 可直接 `OS.kill()`（session 已持久化在磁盘文件中，进程终止不影响数据）。

```gdscript
func send_task_to_pi(task_prompt: String, session_id: String, is_fix: bool):
    # Step 1: 写入临时文件
    var file = FileAccess.open(TEMP_PROMPT_FILE, FileAccess.WRITE)
    file.store_string(task_prompt)
    file.close()
    var abs_path = ProjectSettings.globalize_path(TEMP_PROMPT_FILE)

    # Step 2: 构造平台命令（含 session 选项）
    var pi_args = "--mode json"
    if not session_id.is_empty():
        pi_args += ' --session "%s"' % session_id

    var command: String
    match OS.get_name():
        "Windows":
            command = 'type "%s" | pi %s\n' % [abs_path, pi_args]
        "Linux", "macOS":
            command = 'cat "%s" | pi %s\n' % [abs_path, pi_args]

    # Step 3: 写入 shell stdin
    _write_to_stdin(command)

    # Step 4: 读取 stdout JSON 事件流，捕获 session_id
    while not _pi_has_exited():
        var event = _read_pi_event()
        if event.type == "agent_start" and event.has("session_id"):
            session_id = event["session_id"]  # 首次执行时捕获
        _emit_event(event)

    # Step 5: Pi 退出后关闭 pipe
    _close_pipe()
```

### Pi 输出解析

Pi 的 `--mode json` 输出 JSONL（每行一个 JSON 对象），与 CC 的 `stream-json` 格式不同：

| Pi 事件类型 | 含义 | 处理 |
|-----------|------|------|
| `agent_start` | Agent 开始执行 | 显示"Pi 执行中..." |
| `message_update` | 流式文本输出 | 提取 `text_delta` 展示给用户 |
| `tool_execution_start` | 工具开始执行 | 显示工具名和参数 |
| `tool_execution_end` | 工具执行完成 | 显示结果摘要 |
| `agent_end` | Agent 执行完毕 | **Pi 进程即将退出，pipe 可关闭** |

```gdscript
func parse_pi_output(raw_line: String) -> Dictionary:
    var json = JSON.parse_string(raw_line)
    if json == null:
        return {"type": "raw", "text": raw_line}

    match json.get("type"):
        "agent_start":
            return {"type": "pi_started"}
        "message_update":
            var delta = json.get("assistantMessageEvent", {})
            if delta.get("type") == "text_delta":
                return {"type": "text", "content": delta.get("delta", "")}
            elif delta.get("type") == "toolcall_end":
                return {"type": "tool_call", "name": delta.get("toolCall", {}).get("name", ""), "args": delta.get("toolCall", {}).get("arguments", {})}
            return {"type": "ignored"}
        "agent_end":
            return {"type": "pi_finished", "messages": json.get("messages", [])}
        _:
            return {"type": "other", "data": json}
```

### Pi 的修复循环

Pi 支持 session，修复时在同一 session 内重试：

```
验证失败 (FAIL)
    │
    ▼
Alpha 分析失败 → 构造修复提示词
    │
    ▼
同一 Pi session 中发送修复指令：
  cat fix_prompt.txt | pi --mode json --session "<id>"
    │  (Pi 使用 --session 续接已有 session，能看到之前的修改和错误)
    ▼
Alpha 重新验证
```

> **注意**：使用 `--session` 续接时，Pi 保留上次对话的完整上下文，无需重复包含原任务描述。修复提示词只需指出需要修正的具体位置和期望行为。

### Pi 模型配置

Pi 使用自己的配置体系（`~/.pi/agent/settings.json` + `auth.json`），不通过环境变量透传。Alpha **不干预** Pi 的模型配置，用户需自行配置好 Pi 的 provider 和 API key。

### Pi 终止

Pi 的终止比 CC 简单：Pi 的 session 数据已持久化在磁盘文件中，直接 `OS.kill(pid)` 即可，无数据丢失风险。下次通过 `--session <id>` 可恢复。

---

## 统一 Agent 抽象层

### 设计目标

CC 和 Pi 的输出格式不同（CC: `stream-json`，Pi: `--mode json` JSONL），但行为语义高度一致。抽象层的目标是将这些差异封装在 Adapter 内部，让 Alpha 的 `HireController` 只需面对一套统一接口。新 Agent 只要实现该接口即可接入。

### 统一事件模型

从 CC 和 Pi 的事件流中提取公共语义，定义 6 类统一事件：

| 统一事件 | CC 来源 | Pi 来源 | 语义 |
|---------|---------|---------|------|
| `agent_started` | `system/init` | `agent_start` | Agent 开始处理任务 |
| `agent_finished` | `result` (subtype=success) | `agent_end` | Agent 执行完毕 |
| `text_delta` | `stream_event` + `text_delta` | `message_update` + `text_delta` | 流式文本输出 |
| `tool_started` | `stream_event` + `tool_use` | `tool_execution_start` | 工具开始执行 |
| `tool_updated` | — (CC 不提供) | `tool_execution_update` | 工具执行中（可选） |
| `tool_finished` | `user` (tool_result) | `tool_execution_end` | 工具执行完成 |
| `error` | `system/api_retry` / exit code | `extension_error` / exit code | 错误发生 |

### 统一接口

```gdscript
# addons/agent/scripts/hire/agent_adapter.gd
class_name AgentAdapter
extends RefCounted

## 抽象基类 — 所有外部 Agent 的 Adapter 必须继承

# -- 生命周期 --

## 检测 Agent 是否可用（where/which + --version）
func check_availability() -> bool:
    push_error("check_availability() must be implemented by subclass")
    return false

## 启动 Agent 子进程，返回成功/失败
func start() -> bool:
    push_error("start() must be implemented by subclass")
    return false

## 终止 Agent 子进程
func terminate():
    push_error("terminate() must be implemented by subclass")

# -- 对话控制 --

## 发送提示词给 Agent
func send_prompt(prompt: String):
    push_error("send_prompt() must be implemented by subclass")

## 中断当前执行（类似 Ctrl+C）
func abort():
    push_error("abort() must be implemented by subclass")

# -- 输出读取 --

## 非阻塞读取一行输出，返回统一事件 Dictionary
## 返回格式: {"type": "agent_started"|"text_delta"|"tool_started"|...}
## 无数据时返回 {"type": "empty"}
func read_event() -> Dictionary:
    push_error("read_event() must be implemented by subclass")
    return {"type": "empty"}

## Agent 是否已退出
func has_exited() -> bool:
    push_error("has_exited() must be implemented by subclass")
    return true

## 获取 Agent 的退出码
func get_exit_code() -> int:
    push_error("get_exit_code() must be implemented by subclass")
    return -1

# -- 上下文管理（可选） --

## 是否支持 session 管理
func supports_session() -> bool:
    return false

## 获取当前 session ID（仅 supports_session()=true 时有效）
func get_session_id() -> String:
    return ""

## 恢复指定 session（仅 supports_session()=true 时有效）
func resume_session(session_id: String):
    pass
```

### 统一事件数据结构

```gdscript
# 所有 Adapter 输出的统一事件格式

# agent_started
{"type": "agent_started"}

# agent_finished
{"type": "agent_finished", "messages": [...]}  # 可选

# text_delta — 流式文本
{"type": "text_delta", "text": "def dash("}

# tool_started — 工具开始
{"type": "tool_started", "tool_name": "bash", "tool_args": {"command": "ls"}}

# tool_updated — 工具执行中（可选，Pi 支持，CC 无）
{"type": "tool_updated", "tool_name": "bash", "partial_output": "partial..."}

# tool_finished — 工具结束
{"type": "tool_finished", "tool_name": "bash", "result": {"content": [...], "is_error": false}}

# error
{"type": "error", "message": "...", "is_retryable": false}

# empty — 无数据
{"type": "empty"}

# raw — 未识别的原始行（调试用）
{"type": "raw", "text": "..."}
```

### CC Adapter 实现

```gdscript
class_name CCAdapter
extends AgentAdapter

var _process_manager: CCProcessManager
var _output_parser: CCOutputParser
var _session_id: String = ""

func check_availability() -> bool:
    return CCChecker.new().check()

func start() -> bool:
    _process_manager = CCProcessManager.new()
    return _process_manager.start()

func supports_session() -> bool:
    return true

func get_session_id() -> String:
    return _session_id

func resume_session(id: String):
    _session_id = id

func send_prompt(prompt: String):
    var is_new = _session_id == ""
    CCPromptFileWriter.write_and_send(prompt, _session_id, is_new)
    if is_new:
        # 等待 system/init 事件以捕获 session_id
        pass

func abort():
    CCProcessController.new(_process_manager).pause()

func read_event() -> Dictionary:
    var raw = _process_manager.read_line()
    if raw == "":
        return {"type": "empty"}

    var event = _output_parser.parse(raw)

    match event.get("type"):
        "system/init":
            _session_id = event.get("session_id", "")
            return {"type": "agent_started"}
        "stream_event":
            var delta = event.get("event", {}).get("delta", {})
            if delta.get("type") == "text_delta":
                return {"type": "text_delta", "text": delta.get("text", "")}
            elif delta.get("type") == "tool_use":
                return {"type": "tool_started", "tool_name": delta.get("name", ""), "tool_args": delta.get("input", {})}
        "user":
            var content = event.get("message", {}).get("content", [])
            return {"type": "tool_finished", "tool_name": "unknown", "result": {"content": content}}
        "result":
            return {"type": "agent_finished"}
        "system/api_retry":
            return {"type": "error", "message": event.get("error", ""), "is_retryable": true}
        _:
            return {"type": "empty"}

    return {"type": "empty"}

func has_exited() -> bool:
    return not OS.is_process_running(_process_manager._pid)

func get_exit_code() -> int:
    return OS.get_process_exit_code(_process_manager._pid)

func terminate():
    _process_manager.terminate()
```

### Pi Adapter 实现

```gdscript
class_name PiAdapter
extends AgentAdapter

var _process_manager: PiProcessManager
var _output_parser: PiOutputParser
var _buffer: String = ""

func check_availability() -> bool:
    return PiChecker.new().check()

func start() -> bool:
    _process_manager = PiProcessManager.new()
    return _process_manager.start()

func send_prompt(prompt: String):
    # Pi 不需要 session 管理，每次发送就是新进程内的新对话
    PiPromptFileWriter.write_and_send(prompt)

func abort():
    # Pi 直接终止
    _process_manager.terminate()

func read_event() -> Dictionary:
    var raw = _process_manager.read_line()
    if raw == "":
        return {"type": "empty"}

    var event = _output_parser.parse(raw)

    match event.get("type"):
        "agent_start":
            return {"type": "agent_started"}
        "agent_end":
            return {"type": "agent_finished", "messages": event.get("messages", [])}
        "message_update":
            var delta = event.get("assistantMessageEvent", {})
            match delta.get("type"):
                "text_delta":
                    return {"type": "text_delta", "text": delta.get("delta", "")}
                "thinking_delta":
                    return {"type": "text_delta", "text": "[思考] " + delta.get("delta", "")}
                "toolcall_start":
                    return {"type": "tool_started", "tool_name": delta.get("name", ""), "tool_args": delta.get("arguments", {})}
                _:
                    return {"type": "empty"}
        "tool_execution_start":
            return {"type": "tool_started", "tool_name": event.get("toolName", ""), "tool_args": event.get("args", {})}
        "tool_execution_update":
            return {"type": "tool_updated", "tool_name": event.get("toolName", ""), "partial_output": str(event.get("partialResult", {}))}
        "tool_execution_end":
            return {"type": "tool_finished", "tool_name": event.get("toolName", ""), "result": event.get("result", {})}
        "extension_error":
            return {"type": "error", "message": event.get("error", ""), "is_retryable": false}
        _:
            return {"type": "empty"}

    return {"type": "empty"}

func has_exited() -> bool:
    return not OS.is_process_running(_process_manager._pid)

func get_exit_code() -> int:
    return OS.get_process_exit_code(_process_manager._pid)

func terminate():
    _process_manager.terminate()
```

### HireController 使用抽象层

```gdscript
# hire_controller.gd — 完全 Agent 无关
class_name HireController

var _adapter: AgentAdapter  # CCAdapter 或 PiAdapter，多态

func initialize(agent_type: String):
    match agent_type:
        "cc":
            _adapter = CCAdapter.new()
        "pi":
            _adapter = PiAdapter.new()
        # 未来: "opencode":
        #     _adapter = OpenCodeAdapter.new()

    if not _adapter.check_availability():
        push_error("Agent %s not available" % agent_type)
        return

func execute_step(step, is_fix: bool):
    if is_fix and _adapter.supports_session():
        _adapter.resume_session(_adapter.get_session_id())

    _adapter.start()
    _adapter.send_prompt(step.description)

    # 统一的事件循环
    while not _adapter.has_exited():
        var event = _adapter.read_event()
        match event.type:
            "agent_started":
                emit_signal("agent_started")
            "text_delta":
                emit_signal("text", event.text)
            "tool_started":
                emit_signal("tool_started", event.tool_name, event.tool_args)
            "tool_finished":
                emit_signal("tool_finished", event.tool_name, event.result)
            "agent_finished":
                emit_signal("agent_finished", event.messages)
                break
            "error":
                emit_signal("error", event.message)
            "empty":
                await get_tree().create_timer(0.05).timeout

    _adapter.terminate()
```

### 接入新 Agent 的步骤

1. 创建 `XxxAdapter` 继承 `AgentAdapter`
2. 实现 `check_availability()` — 检测 CLI 是否存在
3. 实现 `start()` / `terminate()` — 管理子进程
4. 实现 `send_prompt()` — 将提示词以 Agent 期望的格式发送
5. 实现 `read_event()` — **核心工作**：将 Agent 特有的 JSON 输出映射为统一事件
6. 实现 `abort()` — 中断执行
7. （可选）重写 `supports_session()` / `get_session_id()` / `resume_session()`
8. 在 `HireController.initialize()` 中注册新的 agent_type

### CC 与 Pi 事件映射速查

```
CC stream-json 事件              →  统一事件              ←  Pi --mode json 事件
─────────────────────────────────────────────────────────────────────────────
system/init                      →  agent_started          ←  agent_start
stream_event.text_delta          →  text_delta             ←  message_update.text_delta
stream_event.tool_use            →  tool_started           ←  message_update.toolcall_start / tool_execution_start
(user message with tool_result)  →  tool_finished          ←  tool_execution_end
result (subtype=success)         →  agent_finished         ←  agent_end
system/api_retry                 →  error                  ←  extension_error
—                                →  tool_updated           ←  tool_execution_update (CC 不提供此事件)
```

---

## UI 设计

### 模式切换控件

```
┌─────────────────────────────────────────────────┐
│  [⚡ 直接 ▼]  [角色: Default ▼]                  │
│  ┌─────────────────────────────────────────┐    │
│  │ 请输入任务...                            │    │
│  └─────────────────────────────────────────┘    │
│  [发送]                                         │
└─────────────────────────────────────────────────┘
```

### 执行 Agent 选择 + CC 执行面板

```
┌─────────────────────────────────────────────────┐
│  🔁 雇佣模式: [CC ▼] [暂停] [跳过] [终止]       │
│  Session: abc123...       重试: 0/2              │
│  ┌─────────────────────────────────────────┐    │
│  │ 步骤 2/5: 添加 dash 动画                 │    │
│  │ ████████████░░░░░░░░ 60%                │    │
│  └─────────────────────────────────────────┘    │
│  ┌─ CC 输出 ───────────────────────────────┐    │
│  │ > Reading movement.gd...                │    │
│  │ > Adding dash() method at line 89       │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘

Pi 执行面板（无需 session 信息）：
┌─────────────────────────────────────────────────┐
│  🔁 雇佣模式: [Pi ▼] [终止]      重试: 0/2       │
│  ┌─────────────────────────────────────────┐    │
│  │ 步骤 2/5: 添加 dash 动画                 │    │
│  │ Pi 执行中...                             │    │
│  └─────────────────────────────────────────┘    │
│  ┌─ Pi 输出 ───────────────────────────────┐    │
│  │ > Reading movement.gd...                │    │
│  │ > Adding dash() method at line 89       │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

### 验证报告 + 修复建议

```
┌─────────────────────────────────────────────────┐
│  ❌ 步骤 2 验证失败（第 1 次）                    │
│  ┌─────────────────────────────────────────┐    │
│  │ ❌ dash() 参数签名不正确                 │    │
│  │    文件: res://scripts/player/movement.gd│    │
│  │    位置: 第 89 行                        │    │
│  │    期望: func dash(direction: Vector2,   │    │
│  │           speed: float)                  │    │
│  │    实际: func dash(speed: float)         │    │
│  │    建议: 参考 move() 方法签名，增加       │    │
│  │          direction 参数                  │    │
│  │                                          │    │
│  │ ✅ 脚本无语法错误                         │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  🔧 Alpha 正在同一 session 中发送修复指令...      │
└─────────────────────────────────────────────────┘
```

---

## 技术架构

### 新增文件

```
addons/agent/
├── scripts/
│   └── hire/
│       ├── agent_adapter.gd             # 统一 Agent 抽象基类（接口定义）
│       ├── agent_hire_initializer.gd    # 雇佣仪式初始化（发布广告→面试→就绪）
│       ├── cc_adapter.gd                # CC Adapter 实现
│       ├── pi_adapter.gd                # Pi Adapter 实现
│       ├── cc_process_manager.gd        # CC 子进程生命周期管理
│       ├── cc_output_parser.gd          # CC stream-json 输出解析器
│       ├── cc_prompt_builder.gd         # CC 提示词构造器（含修复提示词）
│       ├── cc_prompt_file_writer.gd     # 提示词文件写入 + 平台管道命令构造
│       ├── cc_session_manager.gd        # CC Session 管理
│       ├── cc_checker.gd                # CC 可用性检测
│       ├── cc_process_controller.gd     # CC 进程控制（Ctrl+C 多级回退）
│       ├── cc_model_config.gd           # CC 模型配置
│       ├── cc_skill_installer.gd        # CC Skills 安装/卸载/检测
│       ├── pi_process_manager.gd        # Pi 子进程管理
│       ├── pi_output_parser.gd          # Pi JSONL 输出解析器
│       ├── pi_checker.gd                # Pi 可用性检测
│       ├── hire_controller.gd         # 雇佣模式主控制器（状态机，Agent 无关，通过 AgentAdapter 多态）
│       └── verification_engine.gd       # 验证引擎
├── ui/
│   └── hire/
│       ├── cc_mode_switcher.gd        # 模式切换控件
│       ├── cc_execution_panel.gd      # CC 执行进度面板
│       ├── cc_output_view.gd          # CC 输出视图
│       └── cc_verification_card.gd    # 验证报告卡片（含修复建议展示）
├── tools/
│   └── tools_nodes/
│       ├── cc_hire_task_tool.gd     # 雇佣任务给 CC 的工具
│       └── cc_verify_step_tool.gd     # 验证步骤结果的工具
└── cc_config/
    └── skills/                        # CC 预置 skills 模板
        ├── gdscript-style/
        │   └── SKILL.md
        ├── godot-scene-structure/
        │   └── SKILL.md
        └── godot-animation/
            └── SKILL.md
```

### 核心类关系

```
HireController (状态机，Agent 无关)
├── 持有 → AgentAdapter (抽象基类，多态)
│   ├── CCAdapter → CCProcessManager / CCOutputParser / CCSessionManager / CCProcessController
│   └── PiAdapter  → PiProcessManager / PiOutputParser
├── 持有 → VerificationEngine (验证 + 失败分析)
├── 持有 → CCSkillInstaller (CC Skills)
├── 使用 → CCPromptBuilder (提示词 + 修复指令)
├── 使用 → CCPromptFileWriter (文件写入 + 管道命令)
├── 信号 → MainPanel (UI 更新)
└── 调用 → AgentTools (只读工具)
```

### 关键流程伪代码

```gdscript
# 雇佣模式主流程
func execute_step_with_retry(step, step_index):
    var session_id = session_manager.get_or_create_session(step_index)
    var retry_count = 0
    var max_retries = config.get("cc_max_fix_retries", 2)

    while retry_count <= max_retries:
        # Phase 3: Hire
        var cc_result = await hire_to_cc(step, session_id, is_fix=(retry_count > 0))
        display_cc_output(cc_result)

        # Phase 4: Verify
        var verification = await verification_engine.verify(step)
        display_verification(verification)

        match verification.status:
            "PASS":
                return {"status": "pass", "step": step}
            "WARN":
                warnings.append(verification)
                return {"status": "pass_with_warnings", "step": step, "warnings": warnings}
            "LOGIC_ERROR":
                # 逻辑错误：停止，交给用户重新规划
                return {"status": "logic_error", "step": step, "verification": verification}
            "FAIL":
                retry_count += 1
                if retry_count > max_retries:
                    return {"status": "failed_max_retries", "step": step, "verification": verification}
                # Alpha 分析失败 → 生成修复建议 → 同一 session 中发送修复
                var fix_analysis = await verification_engine.analyze_failure(verification, step)
                var fix_prompt = prompt_builder.build_fix_prompt(fix_analysis, step)
                step.description = fix_prompt  # 更新步骤描述为修复指令
                # 继续循环，在同一 session 中执行修复
```

---

## 配置项

### 雇佣配置

在设置面板中新增"雇佣"配置分组：

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `hire_mode_enabled` | bool | false | 是否开启雇佣模式（默认关闭） |
| `hire_agent` | string | `"cc"` | 默认执行 Agent：`"cc"` (Claude Code) 或 `"pi"` |
| `cc_use_alpha_model` | bool | true | CC：是否让 CC 沿用 Alpha 的模型配置。false 时 Alpha 不设置任何模型环境变量，由用户自行配置 |
| `cc_max_steps_per_task` | int | 10 | CC：每个任务最大步骤数 |
| `cc_timeout_per_step` | int | 300 | CC：每个步骤超时时间（秒） |
| `cc_max_fix_retries` | int | 2 | CC：验证失败最大自动修复次数 |
| `cc_fix_timeout_seconds` | int | 120 | CC：单次修复超时时间（秒） |
| `cc_verbose_output` | bool | true | CC：是否显示 CC 详细输出 |
| `cc_auto_install_skills` | bool | true | CC：首次使用雇佣模式时自动安装 CC 预置 skills |
| `cc_skills_allow_uninstall` | bool | true | CC：是否允许在设置页面卸载 CC skills |
| `pi_timeout_per_step` | int | 300 | Pi：每个步骤超时时间（秒） |
| `pi_max_fix_retries` | int | 2 | Pi：验证失败最大自动修复次数 |

### CC 第一阶段支持的模型

| 厂商 | 透传方式 | 说明 |
|------|---------|------|
| **DeepSeek** | 环境变量 `ANTHROPIC_BASE_URL` + `ANTHROPIC_API_KEY` + `ANTHROPIC_MODEL` | 通过 OpenAI 兼容接口，设置 `ANTHROPIC_CUSTOM_PROVIDER=openai-compatible` |

> Pi 不通过环境变量透传模型，用户需自行在 `~/.pi/agent/settings.json` 及 `auth.json` 中配置 provider 和 API key。

后续版本逐步添加 OpenAI、Gemini、Moonshot、MiniMax 等厂商支持。

---

## 安全考量

1. **进程隔离**：执行 Agent 运行在独立子进程中，崩溃不影响 Alpha
2. **文件操作边界**：Agent 只能操作项目目录内的文件
3. **验证不可跳过**：Agent 执行完成后，验证阶段必须运行
4. **用户确认门控**：计划阶段必须用户确认后才进入执行
5. **超时保护**：每个步骤和每次修复有独立超时，防止无限执行
6. **只读验证**：验证阶段 Alpha 只使用只读工具，不会二次修改文件
7. **重试上限**：修复循环有最大次数限制（CC 同 session 内重试 + session 恢复；Pi 每次重建进程）

---

## 平台兼容性

| 平台 | Shell | CC 命令 | 注意事项 |
|------|-------|---------|---------|
| Windows | `cmd.exe` | `claude` | 需确保 claude 在 PATH 中；注意编码页设置 |
| Linux | `/bin/sh` 或 `/bin/bash` | `claude` | 推荐使用绝对路径 |
| macOS | `/bin/sh` 或 `/bin/bash` | `claude` | 注意沙盒权限 |

### 编码处理

使用管道符 `|` 传递输入可绕过部分编码问题。在 Godot 侧 `FileAccess.get_line()` 自动处理 UTF-8。

---

## 与现有待定决策的确认

| # | 决策项 | 确认结果 |
|---|--------|---------|
| 1 | 验证失败处理 | ✅ Alpha 提供修复建议，重新执行（CC: 同 session 重试；Pi: 新进程重试），最多重试 2 次 |
| 2 | 模型支持 | ✅ CC 第一阶段仅支持 DeepSeek 透传；Pi 用户自行配置。提供用户选项控制是否沿用 Alpha 模型 |
| 3 | Session 策略 | ✅ CC：每步骤独立 session，修复时同 session 继续；Pi：无 session，每次新进程 |
| 4 | 调研阶段 | ✅ 由 Alpha 自己完成 |
| 5 | 逻辑错误 | ✅ 停止执行，反馈用户，用户输入新计划指令 |
| 6 | Skill / MCP 支持 | ✅ CC 自动发现 `.claude/skills/` 和 `.mcp.json`；Pi 自动发现 `.pi/skills/` 和 extensions |
| 7 | 多 Agent 支持 | ✅ 已设计 CC 和 Pi 两种 Agent；后续可能添加 OpenCode |
| 8 | 模式切换 | ✅ 设置面板 + 首页 LinkButton 双入口；开启后隐藏角色选择器 |
| 9 | 对话锁定 | ✅ 对话开始后 Agent 不可修改，保存在历史记录中 |
| 10 | 初始化流程 | ✅ 雇佣仪式：发布广告 → 面试 → 雇佣成功/拒绝 |
| 11 | 配置持久化 | ✅ `hire_mode_enabled` + `hire_agent` 保存到 setting.json |

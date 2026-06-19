# Agent 雇佣模式（Agent Hire Mode）开发任务清单

> 基于 `docs/agent_hire_mode.md` 需求文档拆解。本文档追踪开发进度，部分无法一次性完成的任务存放于此。

---

## Phase 1: 基础设施 — 配置系统

| # | 任务 | 状态 | 文件 |
|---|------|------|------|
| 1.1 | GlobalSetting 新增 hire 相关配置项 | ✅ | `agent.gd` |
| 1.2 | setting.json 持久化 hire 配置 | ✅ | `agent.gd` → `save_global_setting()` |
| 1.3 | 创建设置项 UI 组件（hire_mode 开关、agent 选择等） | ✅ | `ui/setting/setting.tscn` + `setting.gd` |
| 1.4 | 设置面板中新增「雇佣」分组区域 | ✅ | `ui/setting/setting.tscn` |

## Phase 2: Agent 可用性检测（雇佣仪式）

| # | 任务 | 状态 | 文件 |
|---|------|------|------|
| 2.1 | CCChecker — 检测 claude 命令是否存在 + 获取版本 | ✅ | `scripts/hire/cc/cc_checker.gd` |
| 2.2 | PiChecker — 检测 pi 命令是否存在 + 获取版本 | ✅ | `scripts/hire/pi/pi_checker.gd` |
| 2.3 | AgentHireInitializer — 三阶段检测流程（广告→面试→就绪）| ✅ | `scripts/hire/agent_hire_initializer.gd` |
| 2.4 | 首页展示初始化状态 UI（招聘/面试/成功/失败）| ✅ | `ui/main_panel.gd` (tooltip 实时状态) |

## Phase 3: 模式切换 UI

| # | 任务 | 状态 | 文件 |
|---|------|------|------|
| 3.1 | 首页 LinkButton「切换到雇佣模式 →」 | ✅ | `ui/main_panel.tscn` + `main_panel.gd` |
| 3.2 | 开启雇佣模式后隐藏角色选择器 | ✅ | `ui/chat/input_container.gd` |
| 3.3 | 设置面板与首页 LinkButton 双向同步 | ✅ | `ui/setting/setting.gd` + `main_panel.gd` |
| 3.4 | 对话锁定规则：对话开始后 Agent 不可修改 | ✅ | `singleton` + `setting.gd` + `main_panel.gd` |

## Phase 4: Agent 统一抽象层

| # | 任务 | 状态 | 文件 |
|---|------|------|------|
| 4.1 | AgentAdapter 抽象基类 | ✅ | `scripts/hire/agent_adapter.gd` |
| 4.2 | CCAdapter 实现 | ✅ | `scripts/hire/cc_adapter.gd` |
| 4.3 | PiAdapter 实现 | ✅ | `scripts/hire/pi_adapter.gd` |
| 4.4 | CCProcessManager — 子进程生命周期管理 | ✅ | `scripts/hire/cc_process_manager.gd` |
| 4.5 | CCOutputParser — stream-json 解析器 | ✅ | `scripts/hire/cc_output_parser.gd` |
| 4.6 | CCSessionManager — Session 管理 | ✅ | `scripts/hire/cc_session_manager.gd` |
| 4.7 | CCProcessController — Ctrl+C 四级回退 | ✅ | `scripts/hire/cc_process_controller.gd` |
| 4.8 | CCPromptBuilder — 提示词构造器 | ✅ | `scripts/hire/cc_prompt_builder.gd` |
| 4.9 | CCPromptFileWriter — 文件写入 + 管道命令 | ✅ | `scripts/hire/cc_prompt_file_writer.gd` |
| 4.10 | CCModelConfig — CC 模型环境变量透传 | ✅ | `scripts/hire/cc_model_config.gd` |
| 4.11 | PiProcessManager — Pi 子进程管理 | ✅ | `scripts/hire/pi_process_manager.gd` |
| 4.12 | PiOutputParser — Pi JSONL 解析器 | ✅ | `scripts/hire/pi_output_parser.gd` |

## Phase 5: 雇佣模式主控制器

| # | 任务 | 状态 | 文件 |
|---|------|------|------|
| 5.1 | HireController — 状态机（Research→Plan→Hire→Verify→Fix） | ✅ | `scripts/hire/hire_controller.gd` |
| 5.2 | VerificationEngine — 验证引擎 | ✅ | `scripts/hire/verification_engine.gd` |

## Phase 6: CC Skills 预置与管理

| # | 任务 | 状态 | 文件 |
|---|------|------|------|
| 6.1 | gdscript-style SKILL.md 模板 | ✅ | `cc_config/skills/gdscript-style/SKILL.md` |
| 6.2 | godot-scene-structure SKILL.md 模板 | ✅ | `cc_config/skills/godot-scene-structure/SKILL.md` |
| 6.3 | godot-animation SKILL.md 模板 | ✅ | `cc_config/skills/godot-animation/SKILL.md` |
| 6.4 | CCSkillInstaller — 安装/卸载/检测 | ✅ | `scripts/hire/cc_skill_installer.gd` |
| 6.5 | 设置面板 Skills 管理 UI | ⬜ | `ui/setting/setting.tscn` |

## Phase 7: 执行 UI 组件

| # | 任务 | 状态 | 文件 |
|---|------|------|------|
| 7.1 | CCExecutionPanel — 执行进度面板 | ✅ (.gd) | `ui/hire/cc_execution_panel.gd` |
| 7.2 | CCOutputView — CC 输出实时展示 | ✅ (.gd) | `ui/hire/cc_output_view.gd` |
| 7.3 | CCVerificationCard — 验证报告卡片 | ✅ (.gd) | `ui/hire/cc_verification_card.gd` |
| 7.4 | HireWorkflowDisplay — 工作流展示器 | ✅ | `ui/hire/hire_workflow_display.gd` |
| 7.5 | 组件 .tscn 场景文件 | ⬜ | 待后续在 Godot 编辑器中创建 |

## Phase 8: 集成与测试

| # | 任务 | 状态 | 文件 |
|---|------|------|------|
| 8.1 | send_messages() 中接入雇佣模式分支 | ✅ | `ui/main_panel.gd` |
| 8.2 | 完整 Research→Plan→Hire→Verify 流程展示 | ✅ | `ui/main_panel.gd` + `hire_workflow_display.gd` |
| 8.3 | CC/Pi 子进程实际调用集成 | ⬜ | 待实现 OS.execute_with_pipe |
| 8.4 | 错误处理与边界情况完善 | ⬜ | — |

---

## 状态图例

| 符号 | 含义 |
|------|------|
| ⬜ | 待开始 |
| 🔄 | 进行中 |
| ✅ | 已完成 |
| ⏸️ | 暂停/阻塞 |
| ❌ | 已取消 |

---

> 最后更新：2026-06-19

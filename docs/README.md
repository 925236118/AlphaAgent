# Alpha Agent 开发者文档

本文档面向插件辅助开发，分为**架构文档**和**功能实现文档**两大类。

## 架构文档


| 文档                                         | 说明                           |
| ------------------------------------------ | ---------------------------- |
| [架构概览](architecture/overview.md)           | 模块关系图、目录结构、核心设计模式            |
| [插件生命周期](architecture/plugin-lifecycle.md) | 启停流程、GlobalSetting、单例信号与扩展钩子 |
| [数据持久化](architecture/data-persistence.md)  | 配置路径、JSON schema、项目级覆盖       |
| [工具系统架构](architecture/tool-system.md)      | 工具注册、并行执行、截断、白名单过滤           |


## 功能实现文档

### 核心流程


| 文档                                       | 说明                                  |
| ---------------------------------------- | ----------------------------------- |
| [聊天流程](features/chat-flow.md)            | 消息循环、Compaction、Steering、工具并行       |
| [上下文压缩](features/context-compaction.md)  | Token 估算、自动摘要、切分策略                  |
| [Chat Wrapper](features/chat-wrapper.md) | 7 家 LLM 适配器、Gemini Thinking、Mock 测试 |
| [模型配置](features/models.md)               | ModelManager、供应商 UI、持久化             |
| [角色系统](features/roles.md)                | RoleManager、工具白名单、ASK 模式联动          |
| [Skill 系统](features/skills.md)           | SkillManager、渐进披露、load_skill        |


### UI 模块


| 文档                                               | 说明                             |
| ------------------------------------------------ | ------------------------------ |
| [聊天 UI](features/ui/chat.md)                     | Agent/ASK 模式、Steering、Token 显示 |
| [输入框快捷菜单](features/input-menu.md)                | `/` 命令/Skill/模板、`@` 文件路径补全     |
| [设置系统](features/setting.md)                      | 全局设置、项目级 `settings.json` 覆盖    |
| [记忆系统](features/memory.md)                       | 全局/项目记忆注入 system prompt        |
| [计划列表](features/plan.md)                         | PlanItem、update_plan_list 工具契约 |
| [聊天历史](features/history.md)                      | history.json、mode 恢复、标题生成      |
| [文件编辑回滚](features/edit-file.md)                  | 临时备份、diff、接受/撤销                |
| [扩展钩子 API](features/extension-api.md)            | before/after tool_call、拦截器     |
| [Prompt Templates](features/prompt-templates.md) | 提示词模板与 `/` 补全                  |
| [测试基础设施](features/testing.md)                    | MockChatStream、Headless 测试     |


### 工具


| 文档                                          | 说明                        |
| ------------------------------------------- | ------------------------- |
| [工具总索引](features/tools/index.md)            | 37 个工具按分组归类               |
| [工具开发指南](features/tools/developer-guide.md) | AgentToolBase、只读/写操作、截断   |
| [基础工具](features/tools/base.md)              | 29 个基础工具简介                |
| [动画工具](features/tools/animation.md)         | AnimationPlayer 8 个工具完整文档 |


## 源码入口

- 插件入口：`addons/agent/agent.gd`
- 单例与扩展钩子：`addons/agent/agent_singleton.gd`
- 聊天编排：`addons/agent/ui/main_panel.gd`
- 上下文压缩：`addons/agent/scripts/context_compaction.gd`
- 工具注册：`addons/agent/tools/tools.tscn`
- 工具实现：`addons/agent/tools/tools_nodes/`
- 内置 Skill：`addons/agent/skills/default_skills/`
- 内置 Prompt 模板：`addons/agent/prompts/`
- Mock 测试：`addons/agent/scripts/test/`

## 其他


| 文档                           | 说明              |
| ---------------------------- | --------------- |
| [项目 README](../README.md)    | 项目简介与用户快速开始     |
| [CHANGELOG](../CHANGELOG.md) | 版本变更历史          |
| [AI 协作约定](../CLAUDE.md)      | 面向 AI 辅助开发的代码约定 |

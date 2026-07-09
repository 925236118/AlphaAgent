# Changelog

## [0.5.1] - 2026-07-09

### Added
- Agent/ASK 模式业务绑定：ASK 模式自动限制为只读工具
- 上下文 Token 监控与自动 Compaction 摘要机制
- Skill 渐进式披露：系统提示中注入技能目录 XML
- 只读工具并行执行，写操作保持串行
- Steering 消息队列：对话生成中可插队发送新消息
- 项目级 `.alpha/settings.json` 覆盖全局设置
- Prompt Templates 提示词模板系统（`/review-script` 等）
- GDScript 扩展钩子 API（`before_tool_call` / `after_tool_call` / `before_agent_finish`）
- Mock Provider 测试基础设施（`MockChatStream`）
- 开发者文档全面同步（聊天流程、架构、Compaction、测试等）

### Fixed
- 无角色选中时不再暴露全部工具，回退为只读工具集
- Gemini Thinking 推理文本解析（`thought` part 与 `thinkingConfig`）
- 恢复 `CHANGELOG.md`，修正文档交叉引用
- CustomDropdown 调试输出与未绑定信号

### Changed
- 工具输出统一截断，防止超大结果撑爆上下文
- 文档体系同步 v0.5.1：`chat-flow`、`overview`、`tool-system`、`setting`、`history`、`input-menu`、`chat-wrapper` 等

## [0.5.0]

### Added
- 文档体系重构：`docs/architecture/` 与 `docs/features/`
- CustomDropdown UI 组件（Agent/ASK 模式切换）
- 新图标集 `icons/newicon/`
- 19 个内置 Godot Skill
- 角色系统与工作流角色
- 文件编辑 diff 与回滚

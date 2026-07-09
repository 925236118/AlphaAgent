# Alpha Agent

一款为 Godot 4.x 编写的 AI 编辑器助手插件，在编辑器右侧 Dock 提供智能对话、工具调用、Skill 技能系统与角色管理能力。

## 功能亮点

- **多模型支持**：OpenAI、Anthropic、DeepSeek、Moonshot、MiniMax、Gemini、Ollama 等 7 家供应商
- **Agent / ASK 双模式**：Agent 可按角色调用写操作工具；ASK 仅暴露只读工具，适合纯问答
- **37 个 AI 工具**：文件读写、场景编辑、动画操作、脚本检查、全局搜索等
- **Skill 技能系统**：19 个内置 Godot 开发 Skill，系统提示渐进披露 + `load_skill` 按需加载
- **角色管理**：自定义人设与工具权限白名单
- **上下文管理**：Token 用量显示、超长对话自动 Compaction 摘要
- **Steering 插队**：对话生成或工具执行中可发送新消息插入队列
- **计划任务**：复杂任务自动拆分为多阶段执行
- **文件变更追踪**：编辑文件 diff 对比与回滚
- **Prompt 模板**：内置常用提示词，`/` 补全快速填入
- **扩展钩子**：`before_tool_call` / `after_tool_call` 等信号，支持工具拦截

## 快速开始

1. 将 `addons/agent/` 放入你的 Godot 项目
2. 在 **项目 → 项目设置 → 插件** 中启用 **AlphaAgent**
3. 点击 **Manage Models...** 配置 API Key 和模型
4. 在右侧面板选择 **Agent** 或 **ASK** 模式，开始对话

可选：在项目根创建 `res://.alpha/settings.json` 覆盖全局设置（如代理、发送快捷键）。

## 开发者文档

| 文档                                    | 说明            |
| ------------------------------------- | ------------- |
| [开发者文档导航](docs/README.md)             | 架构文档与功能实现文档索引 |
| [架构概览](docs/architecture/overview.md) | 插件模块与数据流      |
| [聊天流程](docs/features/chat-flow.md)   | 消息循环、Compaction、Steering |
| [工具总索引](docs/features/tools/index.md) | 37 个 AI 工具列表  |
| [CHANGELOG](CHANGELOG.md)             | 版本变更历史        |

## 项目结构

```
addons/agent/          # 插件核心代码
├── agent.gd             # 插件入口
├── scripts/             # 配置、Compaction、Prompt 模板
├── tools/tools_nodes/   # AI 工具实现
├── ui/                  # 编辑器面板 UI
├── prompts/             # 内置 Prompt 模板
├── scripts/chat_wrapper/ # LLM 供应商适配
└── skills/default_skills/ # 内置 Skill
docs/                  # 开发者文档
├── architecture/      # 架构文档
└── features/          # 功能实现文档
```

## 环境要求

- Godot 4.5 或更高版本
- 至少一个 AI 模型的 API Key

## 主题色

Godot 图标蓝 `#478cbf`

## 反馈

如有问题或建议，请通过 [反馈表单](https://ai.feishu.cn/share/base/form/shrcncDRFhpbbhOqR9AMBKMOuBe) 提交。

## 许可证

MIT License，详见 [LICENSE.txt](LICENSE.txt)。

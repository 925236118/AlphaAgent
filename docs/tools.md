# Godot AI Agent 工具文档

本文档仅保留工具介绍文案。
工具清单来源于 `addons/agent/tools/tools_nodes` 目录下的全部工具脚本。

## 工具列表

| # | 工具名称 | 介绍文案 |
|---|---|---|
| 1 | `add_node_to_scene` | 添加节点到场景中。 |
| 2 | `add_script_to_scene` | 将脚本加载到节点上。 |
| 3 | `check_script_error` | 检查脚本中的语法与静态解析错误。 |
| 4 | `create_folder` | 创建文件夹。 |
| 5 | `create_scene_or_resource` | 创建场景或资源文件。 |
| 6 | `create_script` | 通过继承创建脚本文件。 |
| 7 | `execute_command` | 执行命令行命令。 |
| 8 | `get_class_doc` | 获取Godot原生类的文档信息。 |
| 9 | `get_editor_info` | 获取当前编辑器相关信息。 |
| 10 | `get_image_info` | 获取图片文件信息。 |
| 11 | `get_project_file_list` | 获取当前项目中文件以及其UID列表。 |
| 12 | `get_project_info` | 获取当前的引擎信息和项目配置信息。 |
| 13 | `get_tileset_info` | 获取TileSet信息。 |
| 14 | `global_search` | 全局搜索脚本文件。 |
| 15 | `list_scene_nodes` | 列出场景中的所有节点信息。 |
| 16 | `load_skill` | 加载技能。 |
| 17 | `open_resource` | 使用编辑器打开资源文件（支持 `scene` / `script` / `resource`）。 |
| 18 | `read_file` | 读取文件内容。 |
| 19 | `read_script_outline` | 读取脚本大纲（声明与行号范围）。 |
| 20 | `resource_inspector` | 获取资源的文件结构。 |
| 21 | `sep_script_to_scene` | 将节点上的脚本分离。 |
| 22 | `set_resource_property` | 调用编辑器接口设置资源属性。 |
| 23 | `set_singleton` | 调用编辑器接口设置自动加载脚本或场景。 |
| 24 | `update_plan_list` | 用于管理Agent的计划列表 |
| 25 | `update_scene_node_property` | 调用编辑器接口设置场景中的节点的属性。 |
| 26 | `update_script_file_content` | 调用编辑器接口更新脚本文件的内容。 |
| 27 | `write_file` | 全量替换写入文件内容。 |
| 28 | `web_search` | 联网搜索，返回标题、链接与摘要。支持 Kimi、知乎和 DeepSeek，在设置的「搜索配置」中选择供应商并填写对应密钥。 |

### DeepSeek 搜索源

在「设置 → 搜索配置」选择 **DeepSeek**，填写 DeepSeek 开放平台 API Key，配置自动保存。搜索密钥独立于对话模型及其它搜索源，任何支持工具调用的对话模型均可通过 `web_search` 使用该搜索源。

- 接口：`POST https://api.deepseek.com/v1/tools/search`，使用 Bearer 鉴权，遵循全局 HTTP/HTTPS 代理设置。
- 工具调用示例：`web_search({"query": "Godot 4 site:docs.godotengine.org"})`。
- 搜索词须为 1～128 个字符，支持 `site:`、`-site:`、`lang:`、`after:`、`before:` 和引号精确匹配；`scope` 参数仅适用于知乎。
- 每次获取 10 条结果，优先使用 `summary` 长摘要，回退到 `snippet`，按项目统一规则截取前 500 字；保留发布时间、权威度和排序分数。无匹配结果时返回空数组。
- 密钥无效、余额不足、限流、网络超时及异常响应均作为工具错误返回。

接口与字段依据：[DeepSeek 网页搜索与抓取文档](https://api-docs.deepseek.com/zh-cn/guides/search/)。本适配使用 Search 接口。

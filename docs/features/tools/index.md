# 工具总索引

Alpha Agent 共提供 **37** 个 AI 可调用工具，按 `ToolGroup` 分为 7 组。工具实现在 `addons/agent/tools/tools_nodes/`，在 `tools.tscn` 中注册。

## 查询操作（QUERY）— 14 个


| 工具名                           | 简介                      | 详细文档                 |
| ----------------------------- | ----------------------- | -------------------- |
| `get_project_info`            | 获取引擎信息和项目配置信息           | [基础工具](base.md)      |
| `get_editor_info`             | 获取当前编辑器相关信息             | [基础工具](base.md)      |
| `get_project_file_list`       | 获取项目中文件及其 UID 列表        | [基础工具](base.md)      |
| `get_class_doc`               | 获取 Godot 原生类的文档信息       | [基础工具](base.md)      |
| `get_image_info`              | 获取图片文件信息                | [基础工具](base.md)      |
| `get_tileset_info`            | 获取 TileSet 信息           | [基础工具](base.md)      |
| `global_search`               | 全局搜索脚本文件                | [基础工具](base.md)      |
| `list_scene_nodes`            | 列出场景中的所有节点信息            | [基础工具](base.md)      |
| `read_script_outline`         | 读取脚本大纲（声明与行号范围）         | [基础工具](base.md)      |
| `resource_inspector`          | 获取资源的文件结构               | [基础工具](base.md)      |
| `load_skill`                  | 加载 Skill 技能文档           | [基础工具](base.md)      |
| `get_input_mappings`          | 获取项目的输入映射配置             | [基础工具](base.md)      |
| `get_animation_player_detail` | 获取 AnimationPlayer 完整信息 | [动画工具](animation.md) |
| `get_animation_info`          | 获取动画详情（轨道 + 关键帧）        | [动画工具](animation.md) |


## 文件操作（FILE）— 5 个


| 工具名                        | 简介         | 详细文档            |
| -------------------------- | ---------- | --------------- |
| `read_file`                | 读取文件内容     | [基础工具](base.md) |
| `write_file`               | 全量替换写入文件内容 | [基础工具](base.md) |
| `create_folder`            | 创建文件夹      | [基础工具](base.md) |
| `create_script`            | 通过继承创建脚本文件 | [基础工具](base.md) |
| `create_scene_or_resource` | 创建场景或资源文件  | [基础工具](base.md) |


## 场景操作（SCENE）— 9 个


| 工具名                        | 简介              | 详细文档                 |
| -------------------------- | --------------- | -------------------- |
| `add_node_to_scene`        | 添加节点到场景中        | [基础工具](base.md)      |
| `add_script_to_scene`      | 将脚本加载到节点上       | [基础工具](base.md)      |
| `sep_script_to_scene`      | 将节点上的脚本分离       | [基础工具](base.md)      |
| `create_animation_library` | 创建动画库           | [动画工具](animation.md) |
| `create_animation`         | 创建或复制动画         | [动画工具](animation.md) |
| `edit_animation`           | 编辑动画属性、管理轨道与关键帧 | [动画工具](animation.md) |
| `delete_animation_library` | 删除动画库           | [动画工具](animation.md) |
| `delete_animation`         | 删除动画            | [动画工具](animation.md) |
| `delete_track_or_keyframe` | 删除轨道或关键帧        | [动画工具](animation.md) |


## 编辑器操作（EDITOR）— 6 个


| 工具名                          | 简介             | 详细文档            |
| ---------------------------- | -------------- | --------------- |
| `open_resource`              | 使用编辑器打开资源文件    | [基础工具](base.md) |
| `set_resource_property`      | 调用编辑器接口设置资源属性  | [基础工具](base.md) |
| `set_singleton`              | 设置自动加载脚本或场景    | [基础工具](base.md) |
| `update_scene_node_property` | 设置场景中节点的属性     | [基础工具](base.md) |
| `update_script_file_content` | 更新脚本文件的内容      | [基础工具](base.md) |
| `update_plan_list`           | 管理 Agent 的计划列表 | [基础工具](base.md) |


## 命令行操作（COMMAND）— 1 个


| 工具名               | 简介      | 详细文档            |
| ----------------- | ------- | --------------- |
| `execute_command` | 执行命令行命令 | [基础工具](base.md) |


## 调试操作（DEBUG）— 1 个


| 工具名                  | 简介              | 详细文档            |
| -------------------- | --------------- | --------------- |
| `check_script_error` | 检查脚本中的语法与静态解析错误 | [基础工具](base.md) |


## 项目配置操作（PROJECT）— 1 个


| 工具名                     | 简介           | 详细文档            |
| ----------------------- | ------------ | --------------- |
| `input_mapping_actions` | 对输入映射进行增删改操作 | [基础工具](base.md) |


## 新增工具

1. 在 `addons/agent/tools/tools_nodes/` 新建脚本，继承 `AgentToolBase`
2. 在 `addons/agent/tools/tools.tscn` 添加子节点挂载脚本
3. 在本索引和对应分类文档中补充条目

详见 [工具开发指南](developer-guide.md)。工具分组枚举定义见 `addons/agent/tools/tool_base.gd`。
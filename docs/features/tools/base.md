# 基础工具

本文档介绍除动画工具外的 29 个工具简介。动画相关 8 个工具见 [动画工具](animation.md)。

工具清单来源于 `addons/agent/tools/tools_nodes/` 目录下的工具脚本。

## 查询操作（QUERY）


| #   | 工具名称                    | 介绍文案                 |
| --- | ----------------------- | -------------------- |
| 1   | `get_project_info`      | 获取当前的引擎信息和项目配置信息。    |
| 2   | `get_editor_info`       | 获取当前编辑器相关信息。         |
| 3   | `get_project_file_list` | 获取当前项目中文件以及其 UID 列表。 |
| 4   | `get_class_doc`         | 获取 Godot 原生类的文档信息。   |
| 5   | `get_image_info`        | 获取图片文件信息。            |
| 6   | `get_tileset_info`      | 获取 TileSet 信息。       |
| 7   | `global_search`         | 全局搜索脚本文件。            |
| 8   | `list_scene_nodes`      | 列出场景中的所有节点信息。        |
| 9   | `read_script_outline`   | 读取脚本大纲（声明与行号范围）。     |
| 10  | `resource_inspector`    | 获取资源的文件结构。           |
| 11  | `load_skill`            | 加载技能。                |
| 12  | `get_input_mappings`    | 获取项目的输入映射配置。         |


## 文件操作（FILE）


| #   | 工具名称                       | 介绍文案        |
| --- | -------------------------- | ----------- |
| 13  | `read_file`                | 读取文件内容。     |
| 14  | `write_file`               | 全量替换写入文件内容。 |
| 15  | `create_folder`            | 创建文件夹。      |
| 16  | `create_script`            | 通过继承创建脚本文件。 |
| 17  | `create_scene_or_resource` | 创建场景或资源文件。  |


## 场景操作（SCENE）


| #   | 工具名称                  | 介绍文案       |
| --- | --------------------- | ---------- |
| 18  | `add_node_to_scene`   | 添加节点到场景中。  |
| 19  | `add_script_to_scene` | 将脚本加载到节点上。 |
| 20  | `sep_script_to_scene` | 将节点上的脚本分离。 |


## 编辑器操作（EDITOR）


| #   | 工具名称                         | 介绍文案                                             |
| --- | ---------------------------- | ------------------------------------------------ |
| 21  | `open_resource`              | 使用编辑器打开资源文件（支持 `scene` / `script` / `resource`）。 |
| 22  | `set_resource_property`      | 调用编辑器接口设置资源属性。                                   |
| 23  | `set_singleton`              | 调用编辑器接口设置自动加载脚本或场景。                              |
| 24  | `update_scene_node_property` | 调用编辑器接口设置场景中的节点的属性。                              |
| 25  | `update_script_file_content` | 调用编辑器接口更新脚本文件的内容。                                |
| 26  | `update_plan_list`           | 用于管理 Agent 的计划列表。                                |


## 命令行操作（COMMAND）


| #   | 工具名称              | 介绍文案     |
| --- | ----------------- | -------- |
| 27  | `execute_command` | 执行命令行命令。 |


## 调试操作（DEBUG）


| #   | 工具名称                 | 介绍文案             |
| --- | -------------------- | ---------------- |
| 28  | `check_script_error` | 检查脚本中的语法与静态解析错误。 |


## 项目配置操作（PROJECT）


| #   | 工具名称                    | 介绍文案          |
| --- | ----------------------- | ------------- |
| 29  | `input_mapping_actions` | 对输入映射进行增删改操作。 |


## 输入映射工具说明

### get_input_mappings

只读工具，获取 `project.godot` 中所有已配置的输入动作及其绑定的按键/手柄按钮。

- 可选参数 `include_ui`：是否包含 `ui_*` 系统输入事件，默认 `false`

### input_mapping_actions

写入工具，直接修改 `project.godot` 文件中的输入映射。

- `action=add`：向指定动作追加新按键
- `action=modify`：替换指定动作的全部按键
- `action=remove`：删除指定输入动作

完整工具索引见 [工具总索引](tools/index.md)。开发新工具见 [工具开发指南](tools/developer-guide.md)。
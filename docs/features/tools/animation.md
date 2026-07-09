# AnimationPlayer 工具集

## 功能概述

提供对 Godot 4 `AnimationPlayer` 节点的完整操作能力。Godot 4 中动画的组织结构为：

```
AnimationPlayer
 ├── AnimationLibrary "default"   (键名为空字符串 "")
 │    ├── Animation "idle"
 │    ├── Animation "walk"
 │    └── Animation "run"
 └── AnimationLibrary "fx"
      ├── Animation "explode"
      └── Animation "flash"
```

动画的完整引用格式为 `"library_name/animation_name"`（默认库可省略库名前缀）。


| 工具名                           | 功能                              | 分组    |
| ----------------------------- | ------------------------------- | ----- |
| `get_animation_player_detail` | 获取 AnimationPlayer 完整信息（所有库及动画） | QUERY |
| `get_animation_info`          | 获取动画详情（轨道 + 关键帧）                | QUERY |
| `create_animation_library`    | 创建动画库                           | SCENE |
| `create_animation`            | 创建或复制动画                         | SCENE |
| `edit_animation`              | 编辑动画属性 + 管理轨道 + 管理关键帧           | SCENE |
| `delete_animation_library`    | 删除动画库                           | SCENE |
| `delete_animation`            | 删除动画                            | SCENE |
| `delete_track_or_keyframe`    | 删除轨道或关键帧                        | SCENE |


---

## 工具详细说明

### 1. get_animation_player_detail

获取 AnimationPlayer 节点的完整信息，包括所有动画库及其包含的动画列表（不含关键帧详情）。

- **只读**: 是
- **参数**:


| 参数                      | 类型     | 说明                                        |
| ----------------------- | ------ | ----------------------------------------- |
| `scene_path`            | string | 场景路径，以 `res://` 开头                        |
| `animation_player_path` | string | AnimationPlayer 节点在场景树中的路径（从根节点开始，`/` 分隔） |


- **返回示例**:

```json
{
  "animation_player": "Player/AnimationPlayer",
  "libraries": [
    {
      "library_name": "",
      "display_name": "default",
      "animations": [
        {
          "name": "idle",
          "full_path": "idle",
          "length": 1.0,
          "loop_mode": "none",
          "track_count": 3
        },
        {
          "name": "walk",
          "full_path": "walk",
          "length": 2.5,
          "loop_mode": "linear",
          "track_count": 5
        }
      ]
    },
    {
      "library_name": "fx",
      "animations": [
        {
          "name": "explode",
          "full_path": "fx/explode",
          "length": 1.5,
          "loop_mode": "none",
          "track_count": 4
        }
      ]
    }
  ],
  "total_libraries": 2,
  "total_animations": 3
}
```

---

### 2. get_animation_info

获取指定动画的详细信息，包括所有轨道及关键帧数据。

- **只读**: 是
- **参数**:


| 参数                        | 类型     | 说明                      |
| ------------------------- | ------ | ----------------------- |
| `scene_path`              | string | 场景路径，以 `res://` 开头      |
| `animation_player_path`   | string | AnimationPlayer 节点路径    |
| `library_name`            | string | 动画库名称（默认库传 `""`）        |
| `animation_name`          | string | 动画名称                    |
| `include_keyframe_values` | bool   | 是否需要同时返回关键帧的值，默认 `true` |


- **返回示例**:

```json
{
  "library_name": "",
  "animation_name": "walk",
  "full_path": "walk",
  "length": 2.5,
  "loop_mode": "none",
  "step": 0.1,
  "tracks": [
    {
      "index": 0,
      "type": "property",
      "node_path": "Character/Sprite2D",
      "property": "position",
      "keyframes": [
        { "time": 0.0, "value": "(0, 0)" },
        { "time": 1.0, "value": "(100, 0)" }
      ]
    }
  ]
}
```

---

### 3. create_animation_library

创建新的动画库。

- **只读**: 否
- **参数**:


| 参数                      | 类型     | 说明                    |
| ----------------------- | ------ | --------------------- |
| `scene_path`            | string | 场景路径，以 `res://` 开头    |
| `animation_player_path` | string | AnimationPlayer 节点路径  |
| `library_name`          | string | 新库名称（不能为空字符串，默认库自动存在） |


---

### 4. create_animation

创建新动画或复制已有动画。

- **只读**: 否
- **参数**:


| 参数                           | 类型     | 说明                                           |
| ---------------------------- | ------ | -------------------------------------------- |
| `scene_path`                 | string | 场景路径                                         |
| `animation_player_path`      | string | AnimationPlayer 节点路径                         |
| `library_name`               | string | 目标动画库名称（默认库传 `""`）                           |
| `animation_name`             | string | 新动画名称                                        |
| `source_animation_full_path` | string | 可选。源动画完整路径(如 `"fx/explode"`)，提供则复制该动画的所有内容   |
| `length`                     | float  | 可选。动画长度（秒），默认 1.0                            |
| `loop_mode`                  | string | 可选。循环模式：`"none"` / `"linear"` / `"pingpong"` |


---

### 5. edit_animation

编辑动画属性、管理轨道、添加/修改关键帧。

- **只读**: 否
- **参数**:


| 参数                      | 类型     | 说明                   |
| ----------------------- | ------ | -------------------- |
| `scene_path`            | string | 场景路径                 |
| `animation_player_path` | string | AnimationPlayer 节点路径 |
| `library_name`          | string | 动画库名称                |
| `animation_name`        | string | 目标动画名称               |


**动画属性编辑（可选字段）**:


| 参数          | 类型     | 说明                                          |
| ----------- | ------ | ------------------------------------------- |
| `new_name`  | string | 重命名动画                                       |
| `length`    | float  | 修改动画长度                                      |
| `loop_mode` | string | 修改循环模式：`"none"` / `"linear"` / `"pingpong"` |
| `step`      | float  | 修改时间轴步进值                                    |


**轨道操作（`track_actions` 数组）**:

每个轨道操作对象：


| 参数            | 类型     | 说明                                        |
| ------------- | ------ | ----------------------------------------- |
| `action`      | string | `"add"` / `"edit"`                        |
| `track_index` | int    | 编辑已有轨道时传入索引；新增时不传                         |
| `track_type`  | string | 新增时指定（见下方轨道类型对照表）                         |
| `node_path`   | string | 轨道绑定的节点路径（相对 AnimationPlayer 的 root_node） |
| `property`    | string | `value`/`bezier` 类型轨道时指定属性名               |


**关键帧操作（`keyframe_actions` 数组）**:

每个关键帧操作对象。注意：不同轨道类型的关键帧插入方法不同，所需的参数字段也不同：


| 参数             | 适用类型                                                                       | 类型      | 说明                        |
| -------------- | -------------------------------------------------------------------------- | ------- | ------------------------- |
| `action`       | 全部                                                                         | string  | `"add"` / `"edit"`        |
| `track_index`  | 全部                                                                         | int     | 目标轨道索引                    |
| `time`         | 全部                                                                         | float   | 关键帧时间位置（秒）                |
| `value`        | `value`, `bezier`, `blend_shape`, `position_3d`, `rotation_3d`, `scale_3d` | string  | 关键帧值，使用 `var_to_str` 兼容格式 |
| `transition`   | `value`                                                                    | float   | 可选。过渡曲线时间，默认 1.0          |
| `in_handle`    | `bezier`                                                                   | Vector2 | 贝塞尔入控制手柄                  |
| `out_handle`   | `bezier`                                                                   | Vector2 | 贝塞尔出控制手柄                  |
| `stream`       | `audio`                                                                    | string  | 音频流资源路径（`res://`）         |
| `start_offset` | `audio`                                                                    | float   | 音频起始偏移（秒）                 |
| `end_offset`   | `audio`                                                                    | float   | 音频结束偏移（秒）                 |
| `animation`    | `animation`                                                                | string  | 引用的动画名称                   |


> **实现说明**：工具内部通过 `animation.track_get_type(track_idx)` 获取轨道类型，自动选择对应的插入方法。用户只需根据目标轨道类型传入所需的参数。**不允许**在 `keyframe_actions` 中跨类型使用不兼容的方法。

---

### 6. delete_animation_library

删除指定动画库及其所有动画。

- **只读**: 否
- **参数**:


| 参数                      | 类型     | 说明                   |
| ----------------------- | ------ | -------------------- |
| `scene_path`            | string | 场景路径                 |
| `animation_player_path` | string | AnimationPlayer 节点路径 |
| `library_name`          | string | 要删除的动画库名称（不能删除默认库）   |


---

### 7. delete_animation

删除指定动画。

- **只读**: 否
- **参数**:


| 参数                      | 类型     | 说明                   |
| ----------------------- | ------ | -------------------- |
| `scene_path`            | string | 场景路径                 |
| `animation_player_path` | string | AnimationPlayer 节点路径 |
| `library_name`          | string | 动画库名称                |
| `animation_name`        | string | 要删除的动画名称             |


---

### 8. delete_track_or_keyframe

删除指定轨道或指定关键帧。

- **只读**: 否
- **参数**:


| 参数                      | 类型     | 说明                                         |
| ----------------------- | ------ | ------------------------------------------ |
| `scene_path`            | string | 场景路径                                       |
| `animation_player_path` | string | AnimationPlayer 节点路径                       |
| `library_name`          | string | 动画库名称                                      |
| `animation_name`        | string | 动画名称                                       |
| `target_type`           | string | `"track"` 或 `"keyframe"`                   |
| `track_index`           | int    | 目标轨道索引                                     |
| `keyframe_time`         | float  | target_type 为 `"keyframe"` 时，指定要删除的关键帧时间位置 |


---

## 各工具实现思路

### 通用流程

所有工具的第一步都是通过 `AgentToolUtils.get_target_node()` 获取目标 `AnimationPlayer` 节点，然后通过以下方式获取 AnimationLibrary 和 Animation：

```gdscript
# 获取 AnimationPlayer
var anim_player = get_target_node(scene_path, node_path)

# 获取动画库
var library = anim_player.get_animation_library(library_name)
if not library:
    return {"error": "动画库不存在"}

# 获取动画
var animation = library.get_animation(animation_name)
if not animation:
    return {"error": "动画不存在"}
```

### get_animation_player_detail 实现

```
1. 获取 AnimationPlayer 节点
2. 调用 anim_player.get_animation_library_list() 获取所有库名称列表
3. 遍历每个库名称：
   a. anim_player.get_animation_library(lib_name) 获取 AnimationLibrary
   b. 调用 library.get_animation_list() 获取该库下所有动画名称
   c. 遍历每个动画名称：
      - library.get_animation(name) 获取 Animation 资源
      - 读取 animation.length、animation.loop_mode
      - 读取 animation.get_track_count()
      - 组装 full_path = (lib_name 为空 ? "" : lib_name + "/") + name
   d. 库名为空时 display_name 标记为 "default"
4. 统计总量，组装返回结果
```

### get_animation_info 实现

```
1. 获取 AnimationPlayer 节点和 AnimationLibrary
2. 调用 library.get_animation(animation_name) 获取 Animation 资源
3. 读取基础属性（length, loop_mode, step）
4. 遍历每个轨道（get_track_count()）：
   a. track_get_type(idx) → 判断轨道类型
   b. track_get_path(idx) → 获取绑定的节点路径和属性
   c. 遍历关键帧（track_get_key_count(idx)）：
      - track_get_key_time(idx, key_idx) → 时间
      - track_get_key_value(idx, key_idx) → 值
5. 组装返回结果
```

### create_animation_library 实现

```
1. 获取 AnimationPlayer 节点
2. 检查库名不能为空字符串
3. 检查 anim_player.has_animation_library(library_name)，已存在则返回错误
4. var new_lib = AnimationLibrary.new()
5. anim_player.add_animation_library(library_name, new_lib)
6. 返回成功信息
```

### create_animation 实现

```
1. 获取 AnimationPlayer 节点和目标 AnimationLibrary
2. 检查 animation_name 是否已存在（library.has_animation()）
3. 分支逻辑：
   a. 如果传入了 source_animation_full_path：
      - 解析出源动画的库名和动画名
      - 获取源 AnimationLibrary 和源 Animation
      - var new_anim = src_anim.duplicate()
   b. 否则创建新动画：
      - var new_anim = Animation.new()
      - 如果传入了 length，设置 new_anim.length
      - 如果传入了 loop_mode，设置 new_anim.loop_mode
4. 调用 library.add_animation(animation_name, new_anim)
5. 返回成功信息
```

### edit_animation 实现

三个阶段依次执行：

**阶段一：修改动画属性**

```
1. 获取 Animation 资源
2. 如有 new_name → 调用 library.rename_animation(old_name, new_name)
3. 如有 length → 设置 animation.length
4. 如有 loop_mode → 设置 animation.loop_mode
5. 如有 step → 设置 animation.step
```

**阶段二：处理轨道操作（track_actions）**

```
遍历每个 track_action：
1. action == "add":
   a. 将 track_type 转为 Animation.TYPE_* 枚举
   b. 调用 animation.add_track(type_enum, at_position=-1)
   c. 取 get_track_count() - 1 作为新轨道索引
   d. 设置 track_set_path(new_idx, NodePath(node_path + ":" + property))
   e. method 类型只需 NodePath(node_path)
2. action == "edit":
   a. 更新 track_set_path()
```

**阶段三：处理关键帧操作（keyframe_actions）— 按轨道类型分发**

```
遍历每个 keyframe_action：
1. 通过 animation.track_get_type(track_idx) 获取轨道类型
2. 根据轨道类型调用对应的插入方法：
   a. TYPE_VALUE → track_insert_key(track_idx, time, str_to_var(value), transition)
   b. TYPE_BEZIER → bezier_track_insert_key(track_idx, time, value, in_handle, out_handle)
   c. TYPE_AUDIO → audio_track_insert_key(track_idx, time, load(stream), start_offset, end_offset)
   d. TYPE_ANIMATION → animation_track_insert_key(track_idx, time, animation)
   e. TYPE_BLEND_SHAPE → blend_shape_track_insert_key(track_idx, time, value)
   f. TYPE_POSITION_3D → position_track_insert_key(track_idx, time, str_to_var(value))
   g. TYPE_ROTATION_3D → rotation_track_insert_key(track_idx, time, str_to_var(value))
   h. TYPE_SCALE_3D → scale_track_insert_key(track_idx, time, str_to_var(value))
   i. TYPE_METHOD → track_insert_key(track_idx, time, str_to_var(value), transition)
```

### delete_animation_library 实现

```
1. 获取 AnimationPlayer 节点
2. 检查库名不能为空字符串（不能删除默认库）
3. 检查库是否存在，不存在则返回错误
4. anim_player.remove_animation_library(library_name)
5. 返回成功信息
```

### delete_animation 实现

```
1. 获取 AnimationPlayer 节点和 AnimationLibrary
2. 检查 animation_name 是否存在，不存在则返回错误
3. library.remove_animation(animation_name)
4. 返回成功信息
```

### delete_track_or_keyframe 实现

```
1. 获取 AnimationPlayer 节点、AnimationLibrary、Animation
2. 根据 target_type 分支：
   a. "track":
      - 检查 track_index 有效
      - animation.remove_track(track_index)
   b. "keyframe":
      - 检查 track_index 有效
      - 遍历关键帧，找到时间匹配 keyframe_time 的关键帧
      - animation.track_remove_key(track_idx, key_idx)
3. 返回操作结果
```

---

## 技术实现

### 关键文件


| 文件         | 路径                                |
| ---------- | --------------------------------- |
| tools.tscn | `addons/agent/tools/tools.tscn`   |
| 各工具脚本      | `addons/agent/tools/tools_nodes/` |


通过 `AgentToolUtils.get_target_node()` 获取目标 AnimationPlayer 节点。对 AnimationLibrary 和 Animation 资源的读写直接操作 `AnimationPlayer` / `AnimationLibrary` 的内置方法。

### 核心 API 参考

#### AnimationPlayer API


| 方法                                         | 说明                       |
| ------------------------------------------ | ------------------------ |
| `get_animation_library_list()`             | 获取所有动画库名称列表              |
| `get_animation_library(name)`              | 获取指定名称的 AnimationLibrary |
| `add_animation_library(name, library)`     | 添加动画库                    |
| `remove_animation_library(name)`           | 删除动画库                    |
| `rename_animation_library(name, new_name)` | 重命名动画库                   |
| `has_animation_library(name)`              | 检查动画库是否存在                |
| `get_animation_list()`                     | 获取所有动画完整路径列表             |


#### AnimationLibrary API


| 方法                                     | 说明                   |
| -------------------------------------- | -------------------- |
| `get_animation_list()`                 | 获取库中所有动画名称列表         |
| `get_animation(name)`                  | 获取指定名称的 Animation 资源 |
| `add_animation(name, animation)`       | 添加动画资源               |
| `remove_animation(name)`               | 删除指定动画               |
| `rename_animation(old_name, new_name)` | 重命名动画                |
| `has_animation(name)`                  | 检查动画是否存在             |


#### 轨道类型对照表

`track_actions.track_type` 的字符串值与 Godot 4 `Animation.TrackType` 枚举的映射：


| 参数字符串         | Godot 枚举                     | 关键帧插入方法                                                                       |
| ------------- | ---------------------------- | ----------------------------------------------------------------------------- |
| `value`       | `Animation.TYPE_VALUE`       | `track_insert_key(track_idx, time, Variant, transition)`                      |
| `method`      | `Animation.TYPE_METHOD`      | `track_insert_key(track_idx, time, Variant, transition)`                      |
| `bezier`      | `Animation.TYPE_BEZIER`      | `bezier_track_insert_key(track_idx, time, float, in_handle, out_handle)`      |
| `audio`       | `Animation.TYPE_AUDIO`       | `audio_track_insert_key(track_idx, time, Resource, start_offset, end_offset)` |
| `animation`   | `Animation.TYPE_ANIMATION`   | `animation_track_insert_key(track_idx, time, StringName)`                     |
| `blend_shape` | `Animation.TYPE_BLEND_SHAPE` | `blend_shape_track_insert_key(track_idx, time, float)`                        |
| `position_3d` | `Animation.TYPE_POSITION_3D` | `position_track_insert_key(track_idx, time, Vector3)`                         |
| `rotation_3d` | `Animation.TYPE_ROTATION_3D` | `rotation_track_insert_key(track_idx, time, Quaternion)`                      |
| `scale_3d`    | `Animation.TYPE_SCALE_3D`    | `scale_track_insert_key(track_idx, time, Vector3)`                            |


> 注意：`method` 类型的轨道实际上不需要 `add_track` 时提供路径后缀，其 `track_set_path` 只需 `NodePath(node_path)` 即可。

#### Animation 资源 API


| 方法                                                   | 说明          |
| ---------------------------------------------------- | ----------- |
| `get_track_count()`                                  | 获取轨道数量      |
| `track_get_path(track_idx)`                          | 获取轨道绑定的节点路径 |
| `track_get_type(track_idx)`                          | 获取轨道类型      |
| `add_track(type, at_position)`                       | 添加轨道        |
| `remove_track(track_idx)`                            | 删除轨道        |
| `track_insert_key(track_idx, time, key, transition)` | 插入关键帧       |
| `track_remove_key(track_idx, key_idx)`               | 删除关键帧       |
| `track_get_key_count(track_idx)`                     | 获取关键帧数量     |
| `track_get_key_time(track_idx, key_idx)`             | 获取关键帧时间     |
| `track_get_key_value(track_idx, key_idx)`            | 获取关键帧值      |
| `track_set_key_value(track_idx, key_idx, value)`     | 设置关键帧值      |
| `track_set_key_time(track_idx, key_idx, time)`       | 设置关键帧时间     |
| `track_find_key(track_idx, time, exact)`             | 按时间查找关键帧索引  |
| `length`                                             | 动画长度        |
| `loop_mode`                                          | 循环模式        |
| `step`                                               | 时间轴步进值      |


---

## 注意事项

1. **场景必须已保存**：所有操作依赖 `EditorInterface.open_scene_from_path()`，场景文件必须已保存到磁盘。
2. **节点路径格式**：节点路径从场景根节点开始，用 `/` 分隔，例如 `"Player/AnimationPlayer"`。
3. **关键帧值格式**：传递关键帧值时使用 `var_to_str` 兼容格式，Godot 支持自动转换基础类型和 Vector2/Vector3/Color 等引擎类型。
4. **轨道类型**：Godot 4 支持 9 种轨道类型：`TYPE_VALUE`、`TYPE_METHOD`、`TYPE_BEZIER`、`TYPE_AUDIO`、`TYPE_ANIMATION`、`TYPE_BLEND_SHAPE`、`TYPE_POSITION_3D`、`TYPE_ROTATION_3D`、`TYPE_SCALE_3D`。3D 变换专用类型（`position_3d`/`rotation_3d`/`scale_3d`）通常由引擎内部使用。
5. **Property 轨道路径格式**：Godot 4 中 property 轨道的 `track_set_path()` 格式为 `"NodePath:property"`，例如 `"Character/Sprite2D:position"`，method 轨道只需 `"NodePath"`。
6. **默认库（default library）**：键名为空字符串 `""`，由 Godot 自动创建，不可删除。
7. **关键帧查找**：删除关键帧时通过遍历匹配时间（容差 `abs(time - target) < 0.001`）来定位目标。

---

## 测试用例

以下测试假设场景路径为 `res://player/player.tscn`，AnimationPlayer 节点路径为 `"Player/AnimationPlayer"`，场景中有一个 `Sprite2D` 节点路径为 `"Player/Sprite2D"`。

### 测试场景准备

在开始前，确保你有一个包含 `AnimationPlayer` 节点的已保存场景。如果没有，先用以下提示词创建一个简单测试场景：

> 在 `res://test_anim.tscn` 创建一个场景，根节点为 `Node2D` 命名为 `TestRoot`，添加一个 `Sprite2D` 子节点命名为 `TestSprite`，再添加一个 `AnimationPlayer` 子节点命名为 `AnimPlayer`。保存场景。

---

### 测试流程

按顺序执行以下测试，每个测试依赖上一个测试的结果。

#### 测试 1：查询 AnimationPlayer 基本信息（初始状态）

> 查看 `res://test_anim.tscn` 中 `AnimPlayer` 节点的所有动画库和动画信息。

- **预期结果**：返回 `total_libraries` 为 1（默认库），`total_animations` 为 0，`display_name` 为 `"default"`。

---

#### 测试 2：创建动画库

> 在 `res://test_anim.tscn` 的 `AnimPlayer` 节点下，创建一个名为 `"actions"` 的动画库。

- **预期结果**：返回 `success: true`。再次执行测试 1 会看到 `total_libraries` 为 2。

---

#### 测试 3：创建动画（新建）

> 在 `res://test_anim.tscn` 的 `AnimPlayer` 节点的默认库（库名传空字符串）中，创建一个名为 `"idle"` 的动画，长度 2.0 秒，循环模式为 `linear`。

- **预期结果**：返回 `success: true`。再次执行测试 1 会看到 `total_animations` 为 1。

---

#### 测试 4：创建动画（带轨道）

> 在 `res://test_anim.tscn` 的 `AnimPlayer` 节点的默认库中，创建一个名为 `"walk"` 的动画，长度 1.5 秒，循环模式为 `none`。

然后继续：

> 在上一步的 `walk` 动画中添加一个 value 类型轨道，绑定节点 `TestSprite`，属性 `position`。

再继续：

> 在 `walk` 动画的轨道 0 上，在时间 0.0 处添加关键帧，值为 `"(0, 0)"`，再在时间 1.0 处添加关键帧，值为 `"(100, 0)"`。

- **预期结果**：动画创建成功，轨道和关键帧添加成功。

---

#### 测试 5：创建动画（复制）

> 在 `res://test_anim.tscn` 的 `AnimPlayer` 节点的 `actions` 库中，从 `"walk"` 复制创建一个名为 `"run"` 的动画。

- **预期结果**：返回 `success: true`。`run` 动画应包含与 `walk` 相同的轨道和关键帧。

---

#### 测试 6：查询动画详情

> 查看 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `idle` 动画的详细信息。

- **预期结果**：返回 `length: 2.0`、`loop_mode: "linear"`、`tracks` 为空数组。

> 查看 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `walk` 动画的详细信息，包含关键帧值。

- **预期结果**：返回 `length: 1.5`、1 条轨道（类型 `value`，属性 `position`）、2 个关键帧（时间 0.0 值为 `"(0, 0)"`，时间 1.0 值为 `"(100, 0)"`）。

> 查看 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `walk` 动画的详细信息，不包含关键帧值。

- **预期结果**：关键帧只返回 `time`，不返回 `value`。

---

#### 测试 7：编辑动画属性

> 修改 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `idle` 动画，将长度改为 3.0 秒，循环模式改为 `pingpong`。

- **预期结果**：返回 `success: true`。再次查看 `idle` 详情会看到 `length: 3.0`、`loop_mode: "pingpong"`。

---

#### 测试 8：编辑动画（重命名）

> 将 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `idle` 动画重命名为 `idle_new`。

- **预期结果**：返回 `success: true`。再次查询时动画名变为 `idle_new`。

---

#### 测试 9：编辑动画（轨道操作）

> 在 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `idle_new` 动画中添加一个 method 类型轨道，绑定节点 `TestSprite`。

- **预期结果**：返回 `success: true`，动画的 `track_count` 变为 1。

---

#### 测试 10：编辑动画（添加关键帧 - 不同类型）

method 类型轨道的值应为一个包含 `"method"` 和 `"args"` 的 Dictionary：

> 在 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `idle_new` 动画的轨道 0（method 类型）上，在时间 0.5 处添加关键帧，值为 `{"method": "play", "args": ["idle"]}`。

- **预期结果**：关键帧添加成功。

---

#### 测试 11：查询确认编辑结果

> 查看 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `idle_new` 动画的详细信息。

- **预期结果**：`length: 3.0`、`loop_mode: "pingpong"`、1 条 method 轨道、1 个关键帧。

---

#### 测试 12：删除关键帧

> 删除 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `idle_new` 动画轨道 0 上时间 0.5 处的关键帧。

- **预期结果**：返回 `success: true`，再次查询该动画的关键帧数量为 0。

---

#### 测试 13：删除轨道

> 删除 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `idle_new` 动画的轨道 0。

- **预期结果**：返回 `success: true`，`track_count` 变为 0。

---

#### 测试 14：删除动画

> 删除 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `idle_new` 动画。

- **预期结果**：返回 `success: true`，再次执行测试 1 会看到 `total_animations` 减少了。

---

#### 测试 15：删除动画库

> 删除 `res://test_anim.tscn` 中 `AnimPlayer` 节点的 `actions` 动画库。

- **预期结果**：返回 `success: true`，再次执行测试 1 会看到 `total_libraries` 为 1。

---

### 异常场景测试

#### 异常 1：节点路径错误

> 查看 `res://test_anim.tscn` 中 `WrongNode` 节点的所有动画库信息。

- **预期结果**：返回错误信息，提示找不到节点。

#### 异常 2：非 AnimationPlayer 节点

> 查看 `res://test_anim.tscn` 中 `TestSprite` 节点的所有动画库信息。

- **预期结果**：返回错误信息，提示目标节点不是 AnimationPlayer 类型。

#### 异常 3：动画库不存在

> 删除 `res://test_anim.tscn` 中 `AnimPlayer` 节点的 `nonexistent_lib` 动画库。

- **预期结果**：返回错误信息，提示动画库不存在。

#### 异常 4：动画不存在

> 删除 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库的 `nonexistent_anim` 动画。

- **预期结果**：返回错误信息，提示动画不存在。

#### 异常 5：删除默认库

> 删除 `res://test_anim.tscn` 中 `AnimPlayer` 节点的默认库（库名传空字符串）。

- **预期结果**：返回错误信息，提示不能删除默认库。

#### 异常 6：创建已存在的动画

> 在 `res://test_anim.tscn` 的 `AnimPlayer` 节点默认库中，创建一个名为 `walk` 的动画（walk 已存在）。

- **预期结果**：返回错误信息，提示动画已存在。

#### 异常 7：场景路径错误

> 查看 `res://nonexistent.tscn` 中 `AnimPlayer` 节点的所有动画库信息。

- **预期结果**：返回错误信息，提示无法获取目标节点。

#### 异常 8：创建库时名称为空

> 在 `res://test_anim.tscn` 的 `AnimPlayer` 节点下，创建一个名为 `""`（空字符串）的动画库。

- **预期结果**：返回错误信息，提示库名称不能为空字符串。

#### 异常 9：轨道索引越界

> 删除 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库 `walk` 动画的轨道 99。

- **预期结果**：返回错误信息，提示轨道索引无效。

#### 异常 10：无效的循环模式

> 修改 `res://test_anim.tscn` 中 `AnimPlayer` 节点默认库 `walk` 动画的循环模式为 `"invalid_mode"`。

- **预期结果**：返回错误信息，提示无效的循环模式。


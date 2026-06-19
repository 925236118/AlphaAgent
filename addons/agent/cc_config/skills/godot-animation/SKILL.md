# Godot 动画系统操作指南

## AnimationPlayer 基础

```gdscript
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# 播放动画
animation_player.play("walk")

# 带过渡的播放
animation_player.play("run", -1, 0.2)  # 0.2s 混合时间

# 停止动画
animation_player.stop()

# 检查是否正在播放
if animation_player.is_playing():
    pass
```

## 动画信号

```gdscript
func _ready():
    animation_player.animation_started.connect(_on_anim_start)
    animation_player.animation_finished.connect(_on_anim_finish)

func _on_anim_start(anim_name: String):
    print("开始: ", anim_name)

func _on_anim_finish(anim_name: String):
    print("完成: ", anim_name)
```

## 动画库（AnimationLibrary）

Godot 4 使用 AnimationLibrary 管理动画：

```gdscript
# 获取动画
var anim = animation_player.get_animation("walk")

# 修改动画属性
anim.length = 2.0
anim.loop_mode = Animation.LOOP_LINEAR

# 添加关键帧
var track = anim.add_track(Animation.TYPE_VALUE)
anim.track_set_path(track, ".:position")
anim.track_insert_key(track, 0.0, Vector2(0, 0))
anim.track_insert_key(track, 1.0, Vector2(100, 0))
```

## 动画树（AnimationTree）

使用 AnimationTree 实现复杂混合：

```gdscript
@onready var anim_tree: AnimationTree = $AnimationTree
var playback: AnimationNodeStateMachinePlayback

func _ready():
    playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

func set_state(state_name: String):
    playback.travel(state_name)
```

## 代码控制属性

直接使用 Tween 做简单动画：

```gdscript
var tween = create_tween()
tween.tween_property($Sprite, "modulate", Color.RED, 0.5)
tween.tween_property($Sprite, "modulate", Color.WHITE, 0.5)
```

## 最佳实践

- 为常用动画创建 AnimationLibrary
- 使用 AnimationTree 管理复杂动画状态
- 使用 Tween 做一次性动画效果
- 动画文件放在 res://assets/animations/ 目录下

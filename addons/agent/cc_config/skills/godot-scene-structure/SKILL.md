# Godot 场景结构规范

## 场景文件组织

```
res://
├── scenes/           # 场景文件 (.tscn)
│   ├── ui/           # UI 场景
│   ├── levels/       # 关卡场景
│   └── characters/   # 角色场景
├── scripts/          # GDScript 文件
│   ├── autoload/     # 自动加载脚本
│   └── components/   # 组件脚本
├── assets/           # 资源文件
│   ├── textures/
│   ├── sounds/
│   └── fonts/
└── shaders/          # 着色器
```

## 节点树组织规范

- 根节点类型应与场景用途匹配（UI 用 Control，2D 用 Node2D，3D 用 Node3D）
- 使用有意义的节点名称
- 将相关节点分组到容器节点下
- 使用 `unique_name` (%) 标记关键节点以便引用

## 场景引用

- 使用 `@export var` 在编辑器中配置场景引用
- 使用 `preload()` 加载频繁使用的资源
- 使用 `load()` 按需加载资源

```gdscript
@export var bullet_scene: PackedScene
const HIT_EFFECT = preload("res://scenes/effects/hit_effect.tscn")
```

## 资源路径

- 始终使用 `res://` 前缀引用项目文件
- 使用 `user://` 前缀引用用户数据
- 避免硬编码路径，应使用导出变量

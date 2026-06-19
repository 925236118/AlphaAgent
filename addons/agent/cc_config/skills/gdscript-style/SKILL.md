# GDScript 代码风格指南

## 命名规范

- **类名**: PascalCase（如 `PlayerController`）
- **函数/变量**: snake_case（如 `move_player`、`max_speed`）
- **常量**: UPPER_SNAKE_CASE（如 `MAX_HEALTH`）
- **信号**: snake_case + 过去式（如 `player_died`、`item_collected`）
- **私有成员**: 前缀 `_`（如 `_internal_state`）
- **文件命名**: snake_case（如 `player_controller.gd`）

## 类型注解

始终使用静态类型注解：

```gdscript
var health: int = 100
var player_name: String = ""
var is_alive: bool = true
var position: Vector2 = Vector2.ZERO

func take_damage(amount: int) -> void:
    health -= amount
```

## 信号使用

- 信号声明在文件顶部，紧接 class_name 和 extends
- 信号参数使用类型注解

```gdscript
signal health_changed(new_health: int, old_health: int)
signal player_died
```

## 代码组织

按以下顺序组织脚本：
1. `class_name` / `extends`
2. 信号声明
3. 枚举
4. 常量
5. `@export` 变量
6. `@onready` 变量
7. 公共变量
8. 私有变量
9. 生命周期方法（`_ready`, `_process`, `_physics_process`）
10. 公共方法
11. 私有方法

## 最佳实践

- 优先使用 `match` 而非多层 `if-elif-else`
- 使用 `@export` 暴露可配置属性到编辑器
- 避免在 `_process` 中执行重型操作
- 使用 `await` 处理异步逻辑
- 文档字符串使用 `##` 注释

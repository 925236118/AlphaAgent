---
name: review-script
description: 审查当前 Godot 脚本质量
---

请审查我引用的 Godot 脚本，重点关注：
1. GDScript 类型注解与空值安全
2. 信号连接与生命周期管理
3. 性能热点（_process/_physics_process 中的重复计算）
4. 与 Godot 4.x API 的兼容性

输出格式：问题列表（严重度 + 位置 + 建议修复）。

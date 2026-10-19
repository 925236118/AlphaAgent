# AlphaAgent 功能扩展设计：图片输入 / 上下文压缩 / 错误码统一

> 分支：`dev-v1.0` · 状态：设计阶段 · 日期：2026-09-29

## 一、现状调研结论

### 消息流程
```
input_container.on_click_send_message()
  → emit send_message(user_message: Dictionary, message_content: String)
  → main_panel.on_input_container_send_message()
      → messages.push_back(user_message)
      → send_messages()
          → 按 supplier.provider 创建 chat 实例（流式 current_chat_stream + 非流式 current_title_chat）
          → current_chat_stream.post_message(messages)
```
- **主对话**用流式版 `*_chat_stream.gd`；**标题生成**用非流式版 `*_chat.gd`，两版都要改。
- 当前 `user_message.content` 全部是 **String**，图片需改为 **Array**（OpenAI vision 格式）。

### chat_wrapper 架构
- 各厂商独立类（`DeepSeekChat`/`MiniMaxChat`/`OpenAIChat`/...），无公共基类。
- DeepSeek / MiniMax / OpenAI / MoonShot 都是 OpenAI 兼容（messages 透传，`JSON.stringify` 对 Array content 天然支持）。
- 流式版用原生 `HTTPClient` 手动处理 SSE；非流式版用 `HTTPRequest` 节点。

### 模型配置（`model_config.gd`）
- `ModelInfo` 字段：`id`/`name`/`model_name`/`supports_thinking`/`supports_tools`/`max_tokens`/`active`/`supplier_id`。
- **无 `supports_vision`**，**无独立的上下文长度字段**（`max_tokens` 既当输出上限又当上下文上限，概念混淆）。
- 默认配置：DeepSeek 是 `deepseek-v4-flash`/`deepseek-v4-pro`（max_tokens=384k，但实际 V4 Flash 上下文应为 **1M**，需修正）；MiniMax 默认是 M2.7（无 M3）。

### Token 统计
- `on_agent_finish(finish_reason, total_tokens)` → `input_container.set_usage_label(total_tokens, 128)`，128k **写死**。
- API 返回的 `usage.total_tokens` 反映当前上下文实际占用（含历史），可作为压缩触发依据。

### 错误处理现状
- 所有厂商在 HTTP≠200 时笼统 `error.emit({"error_msg":"HTTP错误: 401","data":body})`。
- 无错误码区分、无重试、无超时、无 MiniMax `base_resp.status_code` 解析。

### API 格式确认
- **DeepSeek vision**：`content` 为块数组，`image_url` 块，`data:image/jpeg;base64,...`，模型 `deepseek-flash`，图片仅 user 消息。支持 JPEG/PNG/GIF/WebP。
- **MiniMax 图片**：格式与 DeepSeek **完全一致**（content 数组 + image_url 块）。模型 `MiniMax-M3`/`MiniMax-M3.1-Flash-Preview` 支持多模态。
- 两者图片输入格式统一，chat_wrapper 层几乎不用改请求构造（messages 透传）。

---

## 二、数据结构变更（`model_config.gd`）

### `ModelInfo` 新增字段
```gdscript
var supports_vision: bool = false       # 是否支持图片输入
var context_length: int = 0             # 上下文窗口大小（token 数），0 表示未知
```
- `to_dict()` / `from_dict()` 同步加这两个字段（`from_dict` 缺省时 supports_vision=false、context_length=0，兼容旧配置）。
- `context_length` 与 `max_tokens`（输出上限，传给 API）**分离**，消除概念混淆。
- `set_usage_label` 改用 `context_length` 作分母（而非写死 128）。

### 默认配置修正
| 供应商 | 模型 | model_name | context_length | supports_vision | supports_thinking | max_tokens(输出) |
|---|---|---|---|---|---|---|
| DeepSeek | DeepSeek V4 Flash | `deepseek-v4-flash` | 1048576 (1M) | true | true | 8192 |
| DeepSeek | DeepSeek V4 Pro | `deepseek-v4-pro` | 1048576 (1M) | true | true | 8192 |
| MiniMax | MiniMax-M3 | `MiniMax-M3` | 1048576 (1M) | true | true | 8192 |
| MiniMax | MiniMax-M3.1-Flash-Preview | `MiniMax-M3.1-Flash-Preview` | 1048576 (1M) | true | true | 8192 |
| MiniMax | MiniMax-M2.7 | `MiniMax-M2.7` | 204800 | false | true | 8192 |
| MiniMax | MiniMax-M2.7-highspeed | `MiniMax-M2.7-highspeed` | 204800 | false | true | 8192 |

> 旧的 DeepSeek `max_tokens=384*1024` 修正为 `context_length=1048576` + `max_tokens=8192`。
> MiniMax M2.7 `max_tokens=64*1024` 修正为 `context_length=204800` + `max_tokens=8192`。

---

## 三、功能一：图片输入（DeepSeek + MiniMax 统一）

### 3.1 UI 改动（`input_container.tscn` / `input_container.gd`）

**新增"上传图片"按钮**：放在底部工具栏左侧 `HBoxContainer`（`RoleButton` 前）。
- 节点名 `ImageButton`，`unique_name_in_owner=true`，图标用图片 icon。
- 配套一个 `FileDialog`（`file_mode=FILE_MODE_OPEN_FILE`，过滤器 `.png,.jpg,.jpeg,.gif,.webp`，`access=ACCESS_FILESYSTEM`）。

**模型切换时显隐**（`_on_model_selected`）：
```gdscript
var supports_vision: bool = model.supports_vision
image_button.visible = supports_vision
```
参照 `supports_thinking` 控制 `UseThinking` 按钮的现有模式。

**选图回调**：
```gdscript
func _on_image_button_pressed():
    file_dialog.popup_centered()

func _on_file_dialog_file_selected(path: String):
    if not FileAccess.file_exists(path):        # 转换前判断图片是否存在
        push_warning("图片文件不存在: " + path)
        return
    var ext = path.get_extension().to_lower()
    if not ["png","jpg","jpeg","gif","webp"].has(ext):
        push_warning("不支持的图片格式: " + ext)
        return
    # 在 reference_list 添加图片引用项
    var reference_item = REFERENCE_ITEM.instantiate()
    reference_item.info = {"type": "image", "path": path}
    reference_list.add_child(reference_item)
    reference_item.set_label(path.get_file())
    reference_item.set_tooltip(path)
```

### 3.2 引用项支持图片类型（`reference_item.gd` / `reference_item.tscn`）
- `info.type == "image"` 时：用 `ImageTexture.load_from_file(path)` 加载缩略图显示 + 文件名 + 删除按钮。
- 复用现有 reference_item 的删除机制。

### 3.3 发送逻辑改造（`input_container.gd` `on_click_send_message`）
当存在图片引用时，`content` 从 String 改为 Array：
```gdscript
var info_list = reference_list.get_children().map(func(node): return node.info)
var image_refs = info_list.filter(func(i): return i.type == "image")

var content
if image_refs.is_empty():
    # 无图片：保持 String（兼容现状）
    content = "用户输入的内容：" + message_text + "\n引用的内容信息：" + JSON.stringify(info_list)
else:
    # 有图片：构造 content 数组（OpenAI vision 格式）
    var parts: Array = [{
        "type": "text",
        "text": "用户输入的内容：" + message_text + "\n引用的内容信息：" + JSON.stringify(info_list)
    }]
    for img in image_refs:
        var f = FileAccess.open(img.path, FileAccess.READ)
        if f == null:
            push_warning("无法读取图片: " + img.path)
            continue
        var bytes: PackedByteArray = f.get_buffer(f.get_length())
        f.close()
        var b64: String = Marshalls.raw_to_base64(bytes)   # ← 正确的 base64 转换
        var mime = "image/" + img.path.get_extension().to_lower().replace("jpg","jpeg")
        parts.append({
            "type": "image_url",
            "image_url": {"url": "data:%s;base64,%s" % [mime, b64]}
        })
    content = parts

send_message.emit({"role": "user", "content": content}, message_text)
```
> 关键：`Marshalls.raw_to_base64(PackedByteArray)` 是正确的 base64 转换函数；`FileAccess.file_exists()` 先判断存在。

### 3.4 用户消息展示（`message_item.gd`）
- `update_user_message_content` 需判断 content 类型：String → 直接显示；Array → 提取 `type=="text"` 的文字 + `type=="image_url"` 渲染缩略图。

### 3.5 main_panel 透传
- `on_input_container_send_message` 已透传 `user_message`，content 是 Array 时无需特殊处理（`messages.push_back(user_message)` 即可）。

### 3.6 chat_wrapper 确认（无需改请求构造）
- 流式 `_process_chunk` 解析的 `delta.content` 仍是 String 增量，不受请求端 content 是 Array 的影响 ✅。
- `JSON.stringify(request_data)` 对 Array content 天然支持 ✅。

### 3.7 体积检查
- DeepSeek：请求体≤48MiB，单图≤32MiB(base64)，单请求≤600图。
- base64 编码后体积约为原文件 1.33 倍，发送前对总 base64 长度做检查，超 48MiB 拒绝并提示用户。

---

## 四、功能二：上下文压缩

### 4.1 触发条件
`on_agent_finish` 中：
```gdscript
var model = model_manager.get_current_model()
var threshold = int(model.context_length * 0.8)   # 达到最大上下文长度 80%
if total_tokens >= threshold and not _compressing:
    _compress_context()
```
- DeepSeek V4 Flash/Pro：threshold = 838860 (1M*0.8)
- MiniMax M3/M3.1：threshold = 838860
- MiniMax M2.7：threshold = 163840

### 4.2 压缩流程
1. `on_agent_finish` 检测超阈值 → 设 `_compressing = true`，UI 提示"正在压缩上下文..."。
2. **新建独立 chat 实例**做压缩（不复用 `current_title_chat`，避免与标题生成信号冲突）。
3. 构造压缩请求：`[压缩 system prompt, {role:user, content: 序列化全部历史}]`。
4. 拿到摘要后，`messages = [原 system_prompt, {role:system, content: "## 对话上下文摘要\n" + 摘要}]`。
5. **图片 base64 在压缩时丢弃**（只保留文字摘要，否则摘要仍占大量 token）。序列化历史时把 image_url 块替换为 `[图片: 文件名]` 占位。
6. UI 提示"上下文已压缩，保留 N 轮要点"，`_compressing = false`。

### 4.3 压缩 Prompt（`config.gd` 新增 `compress_prompt`，可配置）
```
你是对话压缩专家。请将以下 AI 对话历史压缩成一份结构化的上下文摘要，供后续对话延续使用。

必须保留：
1. 【重要事实】已确定的结论、关键数据、关键文件路径与改动
2. 【待验证猜测】标注为"（待验证）"，不要当作事实
3. 【当前任务进度】已完成 / 进行中 / 待办，明确列出下一步
4. 【工具调用要点】调用了哪些工具、关键返回结果
5. 【用户偏好与约束】明确的指令、风格要求、约束条件

丢弃：寒暄、重复内容、已失效的中间尝试、图片原始数据。

输出结构化 Markdown，精简但信息无损。
```

### 4.4 压缩请求的消息序列化
- 把 `messages` 数组转成文本喂给模型（assistant/tool 消息都纳入）。
- image_url 块替换为 `[图片: 文件名或序号]`。
- tool_calls 字段保留 name + arguments 摘要。

### 4.5 改动点
- `main_panel.gd`：新增 `_compress_context()` 协程 + `_compressing` 标志 + 压缩完成回调。
- `config.gd`：新增 `compress_prompt`。
- `input_container.gd`：`set_usage_label` 改用 `context_length`，并在超 80% 时高亮提示（如变色）。

---

## 五、功能三：错误码统一

### 5.1 扩展 error_info 结构
```gdscript
{
    "error_msg": "API 密钥错误，请在模型设置中检查密钥",  # 友好提示
    "error_code": 401,            # HTTP 状态码 或 MiniMax base_resp.status_code
    "error_type": "auth",         # 分类: network/auth/rate_limit/server/request/balance
    "data": "<原始响应体>",        # 原始数据，便于排查
    "retryable": false            # 是否建议重试
}
```

### 5.2 DeepSeek 错误码（HTTP 状态码体系）
来源：https://api-docs.deepseek.com/zh-cn/quick_start/error_codes

| 错误码 | error_type | 友好提示 | retryable |
|---|---|---|---|
| 400 | request | 请求体格式错误，请检查消息内容 | ❌ |
| 401 | auth | API 密钥错误，请在模型设置中检查密钥 | ❌ |
| 402 | balance | 账号余额不足，请充值后重试 | ❌ |
| 422 | request | 请求参数错误，请检查模型/消息参数 | ❌ |
| 429 | rate_limit | 请求过于频繁，已触发限流 | ✅ |
| 500 | server | DeepSeek 服务器故障，请稍后重试 | ✅ |
| 503 | server | DeepSeek 服务器繁忙，请稍后重试 | ✅ |

### 5.3 MiniMax 错误码（base_resp.status_code 体系）
来源：https://platform.minimax.cn/docs/api-reference/errorcode.md

MiniMax 错误有两层：
1. HTTP 层（401/429 等）—— 与 DeepSeek 同样处理 HTTP 状态码。
2. **业务层 `base_resp.status_code`** —— 即使 HTTP 200 也可能携带错误。

| status_code | error_type | 友好提示 | retryable |
|---|---|---|---|
| 1000 | server | 未知错误，请稍后再试 | ✅ |
| 1001 | network | 请求超时，请稍后再试 | ✅ |
| 1002 | rate_limit | 请求频率超限，请稍后再试 | ✅ |
| 1004 | auth | 未授权，请检查 API Key | ❌ |
| 1008 | balance | 余额不足，请检查账户余额 | ❌ |
| 1024 | server | 内部错误，请稍后再试 | ✅ |
| 1026 | request | 输入内容涉敏，请调整输入内容 | ❌ |
| 1027 | request | 输出内容涉敏，请调整输入内容 | ❌ |
| 1033 | server | 系统错误/下游服务错误，请稍后再试 | ✅ |
| 1039 | request | Token 限制，请调整 max_tokens | ❌ |
| 2049 | auth | 无效的 API Key | ❌ |

### 5.4 实现方式
**提取公共错误映射**（建议在 `model_utils.gd` 新增工具函数）：
```gdscript
# OpenAI 兼容厂商（DeepSeek/OpenAI/MoonShot/MiniMax-HTTP层）的 HTTP 错误映射
static func map_http_error(code: int, body: String) -> Dictionary:
    var type = "server"
    var msg = "HTTP错误: " + str(code)
    var retryable = false
    match code:
        400: type="request"; msg="请求体格式错误，请检查消息内容"; retryable=false
        401: type="auth"; msg="API 密钥错误，请在模型设置中检查密钥"; retryable=false
        402: type="balance"; msg="账号余额不足，请充值后重试"; retryable=false
        403: type="auth"; msg="无访问权限"; retryable=false
        404: type="request"; msg="模型名或接口地址错误"; retryable=false
        413: type="request"; msg="请求体过大（图片太多/太大）"; retryable=false
        422: type="request"; msg="请求参数错误，请检查模型/消息参数"; retryable=false
        429: type="rate_limit"; msg="请求过于频繁，已触发限流"; retryable=true
        500, 502, 503: type="server"; msg="服务暂不可用，请稍后重试"; retryable=true
    return {"error_msg":msg, "error_code":code, "error_type":type, "data":body, "retryable":retryable}

# MiniMax 业务层错误映射
static func map_minimax_base_resp(status_code: int) -> Dictionary:
    match status_code:
        1000: return {"error_msg":"未知错误，请稍后再试","error_type":"server","retryable":true}
        1001: return {"error_msg":"请求超时，请稍后再试","error_type":"network","retryable":true}
        1002: return {"error_msg":"请求频率超限，请稍后再试","error_type":"rate_limit","retryable":true}
        1004: return {"error_msg":"未授权，请检查 API Key","error_type":"auth","retryable":false}
        1008: return {"error_msg":"余额不足，请检查账户余额","error_type":"balance","retryable":false}
        1024: return {"error_msg":"内部错误，请稍后再试","error_type":"server","retryable":true}
        1026: return {"error_msg":"输入内容涉敏，请调整输入内容","error_type":"request","retryable":false}
        1027: return {"error_msg":"输出内容涉敏，请调整输入内容","error_type":"request","retryable":false}
        1033: return {"error_msg":"系统错误/下游服务错误，请稍后再试","error_type":"server","retryable":true}
        1039: return {"error_msg":"Token 限制，请调整 max_tokens","error_type":"request","retryable":false}
        2049: return {"error_msg":"无效的 API Key","error_type":"auth","retryable":false}
        _: return {"error_msg":"MiniMax错误码: "+str(status_code),"error_type":"server","retryable":false}
```

**各 chat_wrapper 改造点**：
- 流式版（`*_chat_stream.gd`）`get_response_code() != 200` 分支：调用 `map_http_error(code, body)` 构造结构化 error_info。
- 非流式版（`*_chat.gd`）`_http_request_completed`：解析 `_response_code` + body，调用 `map_http_error`。
- **MiniMax 额外**：HTTP 200 时也要检查响应体 `base_resp.status_code != 0`，调用 `map_minimax_base_resp`。

### 5.5 重试策略（`main_panel.gd` `on_generate_error`）
- 仅对 `retryable == true` 的错误（429/5xx/超时/MiniMax 1000/1001/1002/1024/1033）自动重试。
- 指数退避：1s → 2s → 4s，最多 3 次。
- 重试期间保持"停止"按钮可中断（检查 `AlphaAgentPlugin.is_chat_stopped`）。
- 重试时 UI 提示"正在重试(N/3)..."。
- `retryable == false` 的错误：只显示友好提示，不重试。

---

## 六、其他说明

### MiniMax API 细节
- base_url：项目默认 `https://api.minimaxi.com/v1`（国际版 minimaxi），文档示例 `https://api.minimax.cn`（国内版）。两者图片接口格式一致，域名差异需用户在配置里按实际使用。
- MiniMax M3 用 `reasoning_content` 字段返回思考（非旧版 `reasoning_details`），现有 `minimax_chat_stream.gd` 已有 `elif delta.has("reasoning_content")` 兼容 ✅。
- MiniMax 推荐 `max_completion_tokens` 替代 `max_tokens`（后者已 deprecated），后续可调整。

### MiniMax 图片输出（后续预留）
MiniMax 图片生成是独立 API（非 chat completion），本次仅在 `ModelInfo` 预留 `supports_image_generation` 字段位，后续单独接入，不影响当前方案。

### 实施顺序建议
1. **错误码统一**（改动相对独立、风险低，最先做，打好 error_info 基础）
2. **图片输入**（DeepSeek + MiniMax 统一，UI 改动较多）
3. **上下文压缩**（依赖前两者稳定后做，逻辑最复杂）

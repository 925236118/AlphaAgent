# 联网搜索 Tool 设计方案

## 一、需求概述

为 AI Agent 提供联网搜索能力，由 AI 决定搜索关键字，调用搜索 API，将结果返回给 AI 继续对话。

支持 4 个搜索供应商：Brave Search API、Tavily、SearXNG、知乎数据开放平台。

## 二、现有架构分析

### Tool 系统

- **基类**：`AgentToolBase`（`tools/tool_base.gd`）— 继承 `Node`，抽象方法 `do_action(tool_call) -> Dictionary`
- **注册**：`tools.tscn` 场景树驱动，添加子 Node + attach script 即自动注册到 `tool_map`
- **执行流**：AI 返回 `finish_reason="tool_calls"` → `on_use_tool()` → `tools.use_tool(tool_call)` → `tool.do_action()` → 结果 JSON 字符串放入 `role:"tool"` 消息 → 重新发送给 AI
- **结果格式**：`Dictionary` → `JSON.stringify()` → 作为 `content` 放入 `role:"tool"` 消息

### 设置系统

- **GlobalSetting**（`agent.gd` 内部类）— 全局配置，`load_global_setting()` / `save_global_setting()` 读写 JSON
- **setting.gd** — 设置面板 UI，`@onready` 变量引用控件，`_try_init()` 初始化，`_on_show_setting()` 每次打开刷新
- **setting.tscn** — 设置面板场景，VBoxContainer 布局

### Chat Wrapper 模式（参考）

- 基类 + 子类继承，按 `supplier.provider` 分发
- `_create_chat_by_provider()` 中 match provider 创建实例
- HTTPRequest 发送请求，`_on_request_completed` 处理响应

## 三、各供应商 API 调研

### 1. Brave Search API

| 项目 | 内容 |
|------|------|
| 文档 | https://brave.com/search/api/ · https://api.search.brave.com/app/documentation |
| 端点 | `https://api.search.brave.com/res/v1/web/search` |
| 方法 | GET |
| 认证 | Header `X-Subscription-Token: <API_KEY>` + `Accept: application/json` |
| 必填参数 | `q` — 搜索查询 |
| 可选参数 | `count`(1-20)、`country`、`search_lang`(如 zh-Hans)、`offset`、`safesearch`(off/moderate/strict) |
| 响应 | `web.results[]` — 每项含 `title`、`url`、`description`、`age` |
| 费用 | 免费额度 2000次/月，付费 $3/1000次 |
| 特点 | 无需 OAuth，API Key 即可 |

**请求示例**：
```
GET https://api.search.brave.com/res/v1/web/search?q=Godot+4&count=10&search_lang=zh-Hans
Headers: X-Subscription-Token: <KEY>, Accept: application/json
```

**响应示例**：
```json
{
  "web": {
    "results": [
      {"title": "...", "url": "https://...", "description": "...", "age": "2天前"}
    ]
  }
}
```

### 2. Tavily

| 项目 | 内容 |
|------|------|
| 文档 | https://docs.tavily.com |
| 端点 | `https://api.tavily.com/search` |
| 方法 | POST |
| Content-Type | application/json |
| 必填参数 | `query` — 搜索查询；`api_key` — API Key |
| 可选参数 | `search_depth`(basic/advanced)、`topic`(general/news)、`max_results`(默认10)、`include_answer`(bool)、`include_raw_content`(bool) |
| 响应 | `answer`(可选) + `results[]` — 每项含 `title`、`url`、`content`、`score` |
| 费用 | 免费额度 1000次/月，付费 $30/月 15000次 |
| 特点 | 专为 AI 设计，可返回 AI 摘要答案，结果含相关性评分 |

**请求示例**：
```json
POST https://api.tavily.com/search
{"query": "Godot 4", "api_key": "<KEY>", "search_depth": "basic", "max_results": 10, "include_answer": true}
```

**响应示例**：
```json
{
  "answer": "Godot 4 是...",
  "results": [
    {"title": "...", "url": "https://...", "content": "...", "score": 0.99}
  ]
}
```

### 3. SearXNG

| 项目 | 内容 |
|------|------|
| 文档 | https://docs.searxng.org/dev/search_api.html |
| 端点 | `<instance_url>/search`（自部署实例） |
| 方法 | GET 或 POST |
| 必填参数 | `q` — 搜索查询；`format` — 必须设为 `json`（实例需在 settings.yml 启用 json 格式） |
| 可选参数 | `categories`、`language`、`pageno`、`time_range`(day/month/year)、`safesearch`(0/1/2) |
| 响应 | `results[]` — 每项含 `title`、`url`、`content`、`engine`、`score` |
| 费用 | 完全免费，自部署 |
| 特点 | 元搜索引擎，聚合 Google/Bing/DuckDuckGo 等结果，无需 API Key，需自部署或使用公共实例 |

**请求示例**：
```
GET https://searx.example.com/search?q=Godot+4&format=json&categories=general&language=zh
```

**响应示例**：
```json
{
  "query": "Godot 4",
  "results": [
    {"title": "...", "url": "https://...", "content": "...", "engine": "google", "score": 1.0}
  ]
}
```

### 4. 知乎数据开放平台

| 项目 | 内容 |
|------|------|
| 文档 | https://developer.zhihu.com/docs?key=zhihu_search |
| 认证 | OAuth2 授权流程 |
| 端点 | `https://api.zhihu.com/search` |
| 方法 | GET |
| 必填参数 | `q` — 搜索查询 |
| 可选参数 | `type`(content/answer/article/topic/person/column/collection)、`offset`、`limit` |
| 响应 | 知乎特有 JSON 结构 |
| 费用 | 需申请开发者权限 |
| 特点 | OAuth2 流程复杂，需 client_id + client_secret 获取 access_token |

**认证方式**：用户在知乎开放平台申请 Access Secret（长期有效，申请一次即可），填入设置面板。调用 API 时使用 Header `Authorization: Bearer <access_secret>`。

**简化方案**：用户在知乎开放平台申请 Access Secret（长期有效，申请一次即可），直接填入设置面板，无需 OAuth2 授权流程。

### 5. Kimi (Moonshot) 联网搜索

| 项目 | 内容 |
|------|------|
| 文档 | https://platform.kimi.com/docs/api/tools-search |
| 端点 | `https://api.moonshot.cn/v1/tools/search` |
| 方法 | POST |
| Content-Type | application/json |
| 认证 | Header `Authorization: Bearer <MOONSHOT_API_KEY>` |
| 必填参数 | `text_query` — 搜索查询文本 |
| 可选参数 | `limit`(1-20，默认5)、`timeout_seconds`(1-60)、`include_content`(bool，默认false) |
| 响应 | `search_results[]` — 每项含 `title`、`url`、`snippet`、`site_name`、`date`、`authority`、`text`(可选正文) |
| 费用 | 请求成功且有结果时计费，失败或无结果不计费 |
| 特点 | API Key 与 Moonshot 对话 key 相同，简单易用，结果含权威性等级 |

**请求示例**：
```
POST https://api.moonshot.cn/v1/tools/search
Headers: Authorization: Bearer <KEY>, Content-Type: application/json
Body: {"text_query": "Godot 4", "limit": 10}
```

**响应示例**：
```json
{
  "search_results": [
    {"title": "...", "url": "https://...", "snippet": "摘要", "site_name": "站点", "authority": "S"}
  ]
}
```

## 四、架构设计

### 文件结构

```
addons/agent/
├── scripts/
│   └── search_wrapper/                    # 搜索供应商封装（参考 chat_wrapper 模式）
│       ├── search_provider_base.gd        # 基类：统一搜索接口
│       ├── brave_search.gd                # Brave Search API
│       ├── tavily_search.gd               # Tavily
│       ├── searxng_search.gd              # SearXNG
│       ├── kimi_search.gd                 # Kimi (Moonshot) 联网搜索
│       └── zhihu_search.gd                # 知乎数据开放平台
├── tools/
│   └── tools_nodes/
│       └── web_search_tool.gd             # web_search Tool（注册到 tools.tscn）
├── ui/
│   └── setting/
│       ├── setting.gd                     # 修改：加搜索配置 UI 逻辑
│       └── setting.tscn                   # 修改：加搜索配置 UI 控件
└── agent.gd                               # 修改：GlobalSetting 加搜索配置字段
```

### 类设计

#### SearchProviderBase（基类）

```gdscript
class_name SearchProviderBase
extends Node

# 统一搜索接口
func search(query: String, max_results: int = 10) -> Dictionary:
    # 子类实现，返回统一格式：
    # {"results": [{"title": "", "url": "", "content": "", "source": ""}], "answer": ""}
    return {"error": "未实现"}

# 统一结果格式转换（子类调用）
static func _format_result(title: String, url: String, content: String, source: String = "") -> Dictionary:
    return {"title": title, "url": url, "content": content, "source": source}
```

#### 各供应商子类

每个子类继承 `SearchProviderBase`，实现 `search()`：
- 创建 `HTTPRequest` 节点
- 构造请求（URL/Header/Body 按各供应商规范）
- 发送请求，await 响应
- 解析响应，转换为统一格式

#### WebSearchTool（Tool）

```gdscript
class_name WebSearchTool
extends AgentToolBase

func _get_tool_name() -> String: return "web_search"
func _get_tool_description() -> String: 
    return "联网搜索工具。当需要获取互联网上的最新信息时使用。由你决定搜索关键字。"
func _get_tool_parameters() -> Dictionary:
    return {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "搜索关键字，用简洁明确的语言描述要搜索的内容"
            }
        },
        "required": ["query"]
    }
func _get_tool_readonly() -> bool: return true
func _get_tool_group() -> ToolGroup: return ToolGroup.QUERY

func do_action(tool_call) -> Dictionary:
    var query = JSON.parse_string(tool_call.function.arguments).get("query", "")
    var gs = AlphaAgentPlugin.global_setting
    if gs.search_provider.is_empty():
        return {"error": "网络搜索未开启。请在设置面板的「搜索配置」中选择搜索供应商并配置 API Key。"}
    # 创建对应供应商实例
    var provider = _create_provider(gs.search_provider)
    if provider == null:
        return {"error": "不支持的搜索供应商: " + gs.search_provider}
    var result = await provider.search(query, 10)
    return result
```

### 统一结果格式

所有供应商返回统一结构，方便 AI 解析：

```json
{
  "query": "用户搜索的关键字",
  "results": [
    {
      "title": "结果标题",
      "url": "https://...",
      "content": "内容摘要（前200字）",
      "source": "google"  // 来源引擎或供应商
    }
  ],
  "answer": "可选，AI 生成的摘要答案（仅 Tavily）"
}
```

每个结果截取 `content` 前 500 字，最多返回 10 条，控制 token 数量。

## 五、设置面板设计

### setting.tscn 新增控件

在 QuickModelContainer 和 CompressThresholdContainer 之后，HSeparator 之前，新增「搜索配置」区块：

```
搜索配置（标题 Label）
├── SearchProviderContainer (HBoxContainer)
│   ├── Label "搜索供应商："
│   └── SearchProviderOption (OptionButton)  # 禁用/Brave/Tavily/SearXNG/Kimi/知乎
├── SearchApiKeyContainer (HBoxContainer)
│   ├── Label "API Key："
│   └── SearchApiKeyEdit (LineEdit)          # Brave/Tavily 的 key
├── SearchInstanceContainer (HBoxContainer)
│   ├── Label "实例地址："
│   └── SearchInstanceEdit (LineEdit)        # SearXNG 实例 URL
└── SearchZhihuContainer (HBoxContainer)     # 知乎专用
    ├── Label "Access Secret："
    └── ZhihuAccessSecretEdit (LineEdit)    # 知乎长期有效的 Access Secret
```

**动态显示逻辑**：根据选择的供应商，只显示对应配置项：
- Brave / Tavily / Kimi → 显示 API Key（Kimi 的 API Key 与 Moonshot 对话 key 相同）
- SearXNG → 显示实例地址
- 知乎 → 显示 Access Secret
- 禁用 → 全部隐藏

### GlobalSetting 新增字段

```gdscript
# agent.gd GlobalSetting 类
var search_provider: String = ""              # "" / "brave" / "tavily" / "searxng" / "kimi" / "zhihu"
var search_api_key: String = ""                # Brave / Tavily / Kimi 的 API Key
var search_instance_url: String = ""           # SearXNG 实例地址
var search_zhihu_access_secret: String = ""    # 知乎 Access Secret（长期有效）
```

**load_global_setting()** 中读取：
```gdscript
self.search_provider = str(json.get("search_provider", ""))
self.search_api_key = str(json.get("search_api_key", ""))
self.search_instance_url = str(json.get("search_instance_url", ""))
self.search_zhihu_access_secret = str(json.get("search_zhihu_access_secret", ""))
```

**save_global_setting()** 中写入对应的 key。

### setting.gd 新增逻辑

```gdscript
@onready var search_provider_option: OptionButton = %SearchProviderOption
@onready var search_api_key_edit: LineEdit = %SearchApiKeyEdit
@onready var search_instance_edit: LineEdit = %SearchInstanceEdit
@onready var search_zhihu_access_secret_edit: LineEdit = %ZhihuAccessSecretEdit

# _try_init() 中初始化
func _init_search_config():
    var gs = AlphaAgentPlugin.global_setting
    # 选中当前供应商
    var providers = ["", "brave", "tavily", "searxng", "kimi", "zhihu"]
    var idx = providers.find(gs.search_provider)
    search_provider_option.select(idx if idx >= 0 else 0)
    search_api_key_edit.text = gs.search_api_key
    search_instance_edit.text = gs.search_instance_url
    search_zhihu_access_secret_edit.text = gs.search_zhihu_access_secret
    _update_search_config_visibility()
    # 连接信号
    if not search_provider_option.item_selected.is_connected(_on_search_provider_selected):
        search_provider_option.item_selected.connect(_on_search_provider_selected)
    # ... 连接其他 LineEdit 的 text_changed

# 根据供应商动态显示/隐藏配置项
func _update_search_config_visibility():
    var provider_idx = search_provider_option.selected
    # provider_idx: 0=禁用, 1=brave, 2=tavily, 3=searxng, 4=kimi, 5=zhihu
    search_api_key_edit.get_parent().visible = provider_idx in [1, 2, 4]  # brave/tavily/kimi
    search_instance_edit.get_parent().visible = provider_idx == 3          # searxng
    search_zhihu_access_secret_edit.get_parent().visible = provider_idx == 5 # zhihu
```

## 六、Tool 注册

### tools.tscn

添加 ext_resource 和子 Node：

```
[ext_resource type="Script" path="res://addons/agent/tools/tools_nodes/web_search_tool.gd" id="..."]

[node name="WebSearchTool" type="Node" parent="."]
script = ExtResource("...")
```

`tools.gd` 的 `register_tools()` 会自动扫描子节点注册，无需修改。

### 默认角色

新 tool 需要加入默认角色的 tools 列表（`role_config.gd` 的 `add_default_roles()`），否则角色没有权限使用。

## 七、执行流程

```
1. 用户对话 → AI 需要联网信息
2. AI 决定搜索关键字，返回 tool_call: web_search(query="Godot 4 C# 使用方法")
3. main_panel.on_use_tool() → tools.use_tool() → WebSearchTool.do_action()
4. do_action 检查 search_provider：
   - 未配置 → 返回 {"error": "网络搜索未开启，请在设置面板配置"}
   - 已配置 → 创建对应 SearchProvider 实例
5. SearchProvider.search(query) → HTTPRequest 发送请求 → 解析响应 → 统一格式
6. 结果返回给 AI：
   {"query": "Godot 4 C# 使用方法", "results": [{title, url, content, source}]}
7. AI 根据搜索结果继续回答用户
```

## 八、各供应商实现要点

### BraveSearch

```gdscript
func search(query: String, max_results: int = 10) -> Dictionary:
    var url = "https://api.search.brave.com/res/v1/web/search"
    url += "?q=" + query.uri_encode()
    url += "&count=" + str(mini(max_results, 20))
    url += "&search_lang=zh-Hans"
    
    var http = HTTPRequest.new()
    add_child(http)
    var headers = ["Accept: application/json", "X-Subscription-Token: " + api_key]
    http.request(url, headers, HTTPClient.METHOD_GET, "")
    var resp = await http.request_completed
    # 解析 web.results[] → 统一格式
```

### TavilySearch

```gdscript
func search(query: String, max_results: int = 10) -> Dictionary:
    var body = {
        "query": query,
        "api_key": api_key,
        "search_depth": "basic",
        "max_results": max_results,
        "include_answer": true
    }
    var http = HTTPRequest.new()
    add_child(http)
    http.request("https://api.tavily.com/search", 
        ["Content-Type: application/json"], HTTPClient.METHOD_POST, 
        JSON.stringify(body))
    var resp = await http.request_completed
    # 解析 results[] + answer → 统一格式
```

### SearXNGSearch

```gdscript
func search(query: String, max_results: int = 10) -> Dictionary:
    var url = instance_url.rstrip("/") + "/search"
    url += "?q=" + query.uri_encode()
    url += "&format=json"
    url += "&categories=general"
    
    var http = HTTPRequest.new()
    add_child(http)
    http.request(url, [], HTTPClient.METHOD_GET, "")
    var resp = await http.request_completed
    # 解析 results[] → 统一格式
```

### ZhihuSearch

```gdscript
func search(query: String, max_results: int = 10) -> Dictionary:
    # 检查 access_secret
    if access_secret.is_empty():
        return {"error": "知乎搜索未配置 Access Secret"}
    
    var url = "https://api.zhihu.com/search"
    url += "?q=" + query.uri_encode()
    url += "&type=content"
    url += "&limit=" + str(max_results)
    
    var http = HTTPRequest.new()
    add_child(http)
    var headers = ["Authorization: Bearer " + access_secret]
    http.request(url, headers, HTTPClient.METHOD_GET, "")
    var resp = await http.request_completed
    # 解析知乎特有 JSON → 统一格式
```

### KimiSearch

```gdscript
func search(query: String, max_results: int = 10) -> Dictionary:
    var body = {
        "text_query": query,
        "limit": mini(max_results, 20)
    }
    var http = HTTPRequest.new()
    add_child(http)
    http.request("https://api.moonshot.cn/v1/tools/search", 
        ["Content-Type: application/json", "Authorization: Bearer " + api_key], 
        HTTPClient.METHOD_POST, JSON.stringify(body))
    var resp = await http.request_completed
    # 解析 search_results[] → 统一格式（snippet 作为 content，site_name 作为 source）
```

## 九、HTTP 代理支持

复用 GlobalSetting 的 `http_proxy_host` / `http_proxy_port`，在创建 HTTPRequest 时设置代理：

```gdscript
func _setup_proxy(http: HTTPRequest):
    var gs = AlphaAgentPlugin.global_setting
    if not gs.http_proxy_host.is_empty():
        http.set_http_proxy(gs.http_proxy_host, int(gs.http_proxy_port) if gs.http_proxy_port.is_valid_int() else 0)
```

## 十、错误处理

| 场景 | 返回 |
|------|------|
| 未配置供应商 | `{"error": "网络搜索未开启，请在设置面板的搜索配置中选择供应商并填写 API Key"}` |
| API Key 为空 | `{"error": "搜索供应商 API Key 未配置"}` |
| 网络请求失败 | `{"error": "搜索请求失败: <详细信息>"}` |
| API 返回错误 | `{"error": "<供应商错误信息>"}` |
| SearXNG 实例不可达 | `{"error": "SearXNG 实例不可达，请检查实例地址"}` |
| 知乎 Access Secret 无效 | `{"error": "知乎 Access Secret 可能无效，请检查配置"}` |

## 十一、实现步骤

1. **创建 search_wrapper 目录和文件**
   - `search_provider_base.gd` — 基类
   - `brave_search.gd` — Brave 实现
   - `tavily_search.gd` — Tavily 实现
   - `searxng_search.gd` — SearXNG 实现
   - `kimi_search.gd` — Kimi 实现
   - `zhihu_search.gd` — 知乎实现

2. **创建 web_search_tool.gd**
   - 继承 `AgentToolBase`
   - `do_action` 检查配置 → 创建供应商 → 调用 search → 返回结果
   - tool_name = "web_search"，ToolGroup.QUERY

3. **修改 agent.gd GlobalSetting**
   - 加 `search_provider` / `search_api_key` / `search_instance_url` / `search_zhihu_*` 字段
   - load/save 逻辑

4. **修改 setting.tscn / setting.gd**
   - 加搜索配置 UI 控件
   - 动态显示/隐藏配置项
   - 保存逻辑

5. **修改 tools.tscn**
   - 添加 WebSearchTool 节点

6. **修改 role_config.gd**
   - 默认角色 tools 列表加入 "web_search"

7. **测试**
   - 不配置供应商 → 返回未开启提示
   - 配置 Brave → 搜索测试
   - 配置 Tavily → 搜索测试
   - 配置 SearXNG → 搜索测试
   - 配置知乎 → 搜索测试

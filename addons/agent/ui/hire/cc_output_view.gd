@tool
class_name CCOutputView
extends RichTextLabel

## CC/Pi 输出实时展示视图
## 以不同样式显示 Agent 的文本输出、工具调用和错误信息

# -- 颜色配置 --
const COLOR_TEXT: Color = Color(0.9, 0.9, 0.9, 1.0)
const COLOR_TOOL: Color = Color(0.4, 0.6, 0.9, 1.0)
const COLOR_ERROR: Color = Color(0.9, 0.3, 0.3, 1.0)
const COLOR_SUCCESS: Color = Color(0.3, 0.8, 0.3, 1.0)
const COLOR_THINKING: Color = Color(0.5, 0.5, 0.5, 1.0)

# -- 内部状态 --
var _output_buffer: String = ""
var _tool_calls: Array[Dictionary] = []
var _bbcode_enabled: bool = true

func _ready() -> void:
	bbcode_enabled = true
	scroll_following = true
	clear()

## 清空输出
func clear_output() -> void:
	_output_buffer = ""
	_tool_calls.clear()
	clear()

## 追加文本输出
func append_text(text: String) -> void:
	_output_buffer += text
	append_text("[color=#e6e6e6]%s[/color]" % _escape_bbcode(text))

## 追加思考内容
func append_thinking(text: String) -> void:
	append_text("[color=#808080][i]%s[/i][/color]" % _escape_bbcode(text))

## 追加工具调用
func append_tool_call(tool_name: String, tool_args: Dictionary) -> void:
	_tool_calls.push_back({"name": tool_name, "args": tool_args, "status": "running"})
	var args_str = JSON.stringify(tool_args)
	if args_str.length() > 100:
		args_str = args_str.substr(0, 100) + "..."
	append_text("\n[color=#6699e6]🔧 %s(%s)[/color]\n" % [tool_name, args_str])

## 追加工具结果
func append_tool_result(result: Dictionary) -> void:
	var is_error = result.get("is_error", false)
	var content = str(result.get("content", ""))
	if content.length() > 200:
		content = content.substr(0, 200) + "..."
	if is_error:
		append_text("[color=#e65050]  ❌ %s[/color]\n" % _escape_bbcode(content))
	else:
		append_text("[color=#50e650]  ✅ 完成[/color]\n")

## 追加错误信息
func append_error(message: String) -> void:
	append_text("\n[color=#e65050]❌ 错误: %s[/color]\n" % _escape_bbcode(message))

## 追加 Agent 完成标记
func append_agent_finished() -> void:
	append_text("\n[color=#50e650]✅ Agent 执行完毕[/color]\n")

## 获取完整输出文本（纯文本）
func get_output_text() -> String:
	return _output_buffer

## 转义 BBCode 特殊字符
func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")

## 设置输出为 HTML 格式（用于复制等场景）
func to_html() -> String:
	var html = '<div style="font-family: monospace; background: #1a1a1a; color: #e6e6e6; padding: 12px;">'
	html += _output_buffer.replace("\n", "<br>")
	html += '</div>'
	return html

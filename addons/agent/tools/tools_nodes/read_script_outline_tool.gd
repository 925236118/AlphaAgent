@tool
class_name ReadScriptOutlineTool
extends AgentToolBase

const KEYWORD_KEYS: Array[String] = [
	"tab",
	"class",
	"class_name",
	"@tool",
	"@expand",
	"@onready",
	"func",
	"var",
	"signal",
	"const"
]

func _get_tool_name() -> String:
	return "read_script_outline"

func _get_tool_short_description() -> String:
	return "读取脚本大纲（声明与行号范围）。"

func _get_tool_description() -> String:
	return "读取脚本大纲，返回脚本类名、继承类、是否为工具脚本，以及函数声明、全局变量/常量/信号、内部类的声明行与结束行。通过行号范围可让模型按需读取局部代码，减少token消耗。"

func _get_tool_parameters() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"path": {
				"type": "string",
				"description": "需要分析的脚本路径，必须是以res://开头的.gd文件路径。",
			},
		},
		"required": ["path"]
	}

func _get_tool_readonly() -> bool:
	return true

func _get_tool_group() -> AgentToolBase.ToolGroup:
	return ToolGroup.QUERY

func do_action(tool_call: AgentModelUtils.ToolCallsInfo) -> Dictionary:
	var json = JSON.parse_string(tool_call.function.arguments)
	if json == null or not json.has("path"):
		return { "error": "调用失败。请检查参数是否正确。" }

	var path := String(json.path)
	if not path.begins_with("res://"):
		return { "error": "path必须是以res://开头的绝对路径。" }
	if not path.ends_with(".gd"):
		return { "error": "当前仅支持.gd脚本文件。" }
	if not FileAccess.file_exists(path):
		return { "error": "脚本文件不存在: %s" % path }

	var script_text := FileAccess.get_file_as_string(path)
	return _build_outline(path, script_text)


func _build_outline(path: String, script_text: String) -> Dictionary:
	var lines: PackedStringArray = script_text.split("\n")
	var total_lines := lines.size()

	var result := {
		"path": path,
		"total_lines": total_lines,
		"is_tool": false,
		"tool_tag": null,
		"script_class_name": null,
		"extends_class": null,
		"items": [],
		"detected_keywords": _new_keyword_map(),
		"has_tab_character": script_text.contains("\t"),
	}

	var regex_map := _build_regex_map()
	var regex_tool: RegEx = regex_map["tool"]
	var regex_class_name: RegEx = regex_map["class_name"]
	var regex_extends: RegEx = regex_map["extends"]
	var regex_class_decl: RegEx = regex_map["class_decl"]
	var regex_func: RegEx = regex_map["func"]
	var regex_var_decl: RegEx = regex_map["var_decl"]
	var regex_const_decl: RegEx = regex_map["const_decl"]
	var regex_signal_decl: RegEx = regex_map["signal_decl"]
	var pending_top_level_annotation_start := -1

	for i in total_lines:
		var line_no := i + 1
		var raw_line := lines[i]
		var line := raw_line.strip_edges(false, true)
		var stripped := line.strip_edges()
		var indent := _get_indent_width(raw_line)
		var is_top_level := indent == 0

		_collect_keyword_hits(result.detected_keywords, raw_line, stripped, line_no)

		if is_top_level and stripped == "":
			continue
		if is_top_level and stripped.begins_with("#"):
			continue
		if stripped == "" or stripped.begins_with("#"):
			continue

		if is_top_level and _is_annotation_line(stripped):
			if pending_top_level_annotation_start == -1:
				pending_top_level_annotation_start = line_no
		elif is_top_level:
			# 顶层遇到非注解有效行后，注解窗口即结束。
			pass
		else:
			pending_top_level_annotation_start = -1

		if is_top_level and regex_tool.search(stripped):
			result.is_tool = true
			result.tool_tag = {
				"start_line": line_no,
				"declaration_line": line_no,
				"end_line": line_no
			}
			continue

		if is_top_level:
			var class_name_match = regex_class_name.search(stripped)
			if class_name_match and result.script_class_name == null:
				var class_name_string := class_name_match.get_string(1)
				result.script_class_name = {
					"name": class_name_string,
					"start_line": line_no,
					"declaration_line": line_no,
					"end_line": line_no
				}
				pending_top_level_annotation_start = -1
				continue

			var extends_match = regex_extends.search(stripped)
			if extends_match and result.extends_class == null:
				var extends_name := extends_match.get_string(1)
				result.extends_class = {
					"name": extends_name,
					"start_line": line_no,
					"declaration_line": line_no,
					"end_line": line_no
				}
				pending_top_level_annotation_start = -1
				continue

		var start_line := line_no
		if is_top_level and pending_top_level_annotation_start != -1:
			start_line = pending_top_level_annotation_start

		var func_match = regex_func.search(stripped)
		if func_match:
			result.items.append({
				"type": "function",
				"name": func_match.get_string(1),
				"start_line": start_line,
				"declaration_line": line_no,
				"end_line": line_no,
				"indent": indent,
				"indent_has_tab": raw_line.contains("\t"),
				"_decl_index": i,
			})
			if is_top_level:
				pending_top_level_annotation_start = -1
			continue

		var class_match = regex_class_decl.search(stripped)
		if class_match and not regex_class_name.search(stripped):
			result.items.append({
				"type": "internal_class",
				"name": class_match.get_string(1),
				"start_line": start_line,
				"declaration_line": line_no,
				"end_line": line_no,
				"indent": indent,
				"indent_has_tab": raw_line.contains("\t"),
				"_decl_index": i,
			})
			if is_top_level:
				pending_top_level_annotation_start = -1
			continue

		if is_top_level:
			var var_match = regex_var_decl.search(stripped)
			if var_match:
				result.items.append({
					"type": "global_var",
					"name": var_match.get_string(1),
					"start_line": start_line,
					"declaration_line": line_no,
					"end_line": line_no,
					"indent": indent,
					"indent_has_tab": raw_line.contains("\t"),
				})
				pending_top_level_annotation_start = -1
				continue

			var const_match = regex_const_decl.search(stripped)
			if const_match:
				result.items.append({
					"type": "global_const",
					"name": const_match.get_string(1),
					"start_line": start_line,
					"declaration_line": line_no,
					"end_line": line_no,
					"indent": indent,
					"indent_has_tab": raw_line.contains("\t"),
				})
				pending_top_level_annotation_start = -1
				continue

			var signal_match = regex_signal_decl.search(stripped)
			if signal_match:
				result.items.append({
					"type": "global_signal",
					"name": signal_match.get_string(1),
					"start_line": start_line,
					"declaration_line": line_no,
					"end_line": line_no,
					"indent": indent,
					"indent_has_tab": raw_line.contains("\t"),
				})
				pending_top_level_annotation_start = -1
				continue

			pending_top_level_annotation_start = -1

	_resolve_block_ranges(result.items, lines)
	return result


func _resolve_block_ranges(items: Array, lines: PackedStringArray) -> void:
	for item in items:
		if not item.has("_decl_index"):
			continue
		var decl_index := int(item["_decl_index"])
		var indent := int(item.indent)
		item.end_line = _find_block_end_line(lines, decl_index, indent)
		item.erase("_decl_index")


func _find_block_end_line(lines: PackedStringArray, decl_index: int, decl_indent: int) -> int:
	var total_lines := lines.size()
	for i in range(decl_index + 1, total_lines):
		var current := lines[i].strip_edges(false, true).strip_edges()
		if current == "" or current.begins_with("#"):
			continue
		var indent := _get_indent_width(lines[i])
		if indent <= decl_indent:
			return i
	return total_lines


func _get_indent_width(line: String) -> int:
	var indent := 0
	for i in line.length():
		var c := line.unicode_at(i)
		if c == 9: # \t
			indent += 4
		elif c == 32: # space
			indent += 1
		else:
			break
	return indent


func _is_annotation_line(stripped_line: String) -> bool:
	return stripped_line.begins_with("@")


func _new_keyword_map() -> Dictionary:
	var map := {}
	for key in KEYWORD_KEYS:
		map[key] = []
	return map


func _collect_keyword_hits(keyword_map: Dictionary, raw_line: String, stripped_line: String, line_no: int) -> void:
	if raw_line.contains("\t"):
		keyword_map["tab"].append(line_no)
	if stripped_line.find("@tool") != -1:
		keyword_map["@tool"].append(line_no)
	if stripped_line.find("@expand") != -1:
		keyword_map["@expand"].append(line_no)
	if stripped_line.find("@onready") != -1:
		keyword_map["@onready"].append(line_no)
	if stripped_line.find("class_name") != -1:
		keyword_map["class_name"].append(line_no)
	if stripped_line.begins_with("class "):
		keyword_map["class"].append(line_no)
	if stripped_line.find("func ") != -1:
		keyword_map["func"].append(line_no)
	if stripped_line.find("var ") != -1:
		keyword_map["var"].append(line_no)
	if stripped_line.find("signal ") != -1:
		keyword_map["signal"].append(line_no)
	if stripped_line.find("const ") != -1:
		keyword_map["const"].append(line_no)


func _build_regex_map() -> Dictionary:
	return {
		"tool": _compile_regex("^@tool\\b"),
		"class_name": _compile_regex("^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)\\b"),
		"extends": _compile_regex("^extends\\s+([^\\s#]+)"),
		"class_decl": _compile_regex("^class\\s+([A-Za-z_][A-Za-z0-9_]*)\\b"),
		"func": _compile_regex("^(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\("),
		"var_decl": _compile_regex("^(?:@[A-Za-z_][A-Za-z0-9_]*(?:\\([^\\)]*\\))?\\s+)*var\\s+([A-Za-z_][A-Za-z0-9_]*)\\b"),
		"const_decl": _compile_regex("^(?:@[A-Za-z_][A-Za-z0-9_]*(?:\\([^\\)]*\\))?\\s+)*const\\s+([A-Za-z_][A-Za-z0-9_]*)\\b"),
		"signal_decl": _compile_regex("^signal\\s+([A-Za-z_][A-Za-z0-9_]*)\\b"),
	}


func _compile_regex(pattern: String) -> RegEx:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex

@tool
class_name CCPromptBuilder
extends RefCounted

## CC 提示词构造器
## 构造发送给 CC 的结构化提示词，包含项目上下文、任务描述、验收标准

## 构造步骤执行提示词
## step: 步骤数据 {title, description, context, acceptance_criteria, expected_files}
static func build_step_prompt(step: Dictionary) -> String:
	var parts: Array[String] = []
	parts.push_back("你是 Claude Code，一个在 Godot 4 项目中的代码助手。")
	parts.push_back("当前工作目录是 Godot 项目的根目录。")

	# 项目上下文
	if step.has("context") and not step["context"].is_empty():
		parts.push_back("")
		parts.push_back("## 项目上下文")
		parts.push_back(step["context"])

	# 当前任务
	parts.push_back("")
	parts.push_back("## 当前任务")
	parts.push_back(step.get("title", "执行任务"))

	# 详细说明
	if step.has("description") and not step["description"].is_empty():
		parts.push_back("")
		parts.push_back("## 详细说明")
		parts.push_back(step["description"])

	# 验收标准
	if step.has("acceptance_criteria") and step["acceptance_criteria"] is Array:
		var criteria: Array = step["acceptance_criteria"]
		if criteria.size() > 0:
			parts.push_back("")
			parts.push_back("## 验收标准")
			for c in criteria:
				parts.push_back("- " + str(c))

	# 约束
	parts.push_back("")
	parts.push_back("## 约束")
	parts.push_back("- 只修改预期范围内的文件")
	parts.push_back("- 保持现有代码风格一致")
	parts.push_back("- 完成后不要进行额外操作")
	parts.push_back("- 每次修改后检查语法是否正确")

	if step.has("expected_files") and step["expected_files"] is Array:
		var files: Array = step["expected_files"]
		if files.size() > 0:
			parts.push_back("- 预期修改的文件: " + ", ".join(files))

	return "\n".join(parts)

## 构造修复提示词（同一 Session 内使用）
## fix_analysis: {failed_criteria, root_cause, fix_suggestion}
## step: 原始步骤数据
static func build_fix_prompt(fix_analysis: Dictionary, step: Dictionary) -> String:
	var parts: Array[String] = []
	parts.push_back("## 上次执行的问题")
	parts.push_back("")
	parts.push_back("验证步骤发现以下问题：")

	var failed = fix_analysis.get("failed_criteria", [])
	if failed is Array:
		for item in failed:
			parts.push_back("- " + str(item))

	# 根因
	if fix_analysis.has("root_cause") and not str(fix_analysis["root_cause"]).is_empty():
		parts.push_back("")
		parts.push_back("根本原因: " + str(fix_analysis["root_cause"]))

	# 修复方案
	parts.push_back("")
	parts.push_back("## 修复要求")

	var suggestion = fix_analysis.get("fix_suggestion", {})
	if suggestion is Dictionary and not suggestion.is_empty():
		if suggestion.has("file"):
			parts.push_back("- 文件: " + suggestion["file"])
		if suggestion.has("location"):
			parts.push_back("- 位置: " + suggestion["location"])
		if suggestion.has("expected"):
			parts.push_back("- 期望: " + suggestion["expected"])
		if suggestion.has("context"):
			parts.push_back("- 上下文: " + suggestion["context"])

	parts.push_back("")
	parts.push_back("## 注意")
	parts.push_back("- 只修改需要修复的部分，不要改动已验证正确的代码")
	parts.push_back("- 修复后验证是否符合验收标准")

	return "\n".join(parts)

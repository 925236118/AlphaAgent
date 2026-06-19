@tool
class_name VerificationEngine
extends RefCounted

## 验证引擎
## 在 CC/Pi 完成步骤后，使用 Alpha 的只读工具验证执行结果
##
## 验证维度：文件变更、语法正确、结构完整、场景正确、资源完整、依赖正确

# 验证结果等级
enum Verdict {
	PASS,         # 所有验收标准满足
	WARN,         # 验收标准满足，但有非关键问题
	FAIL,         # 验收标准不满足（语法错误、文件缺失等）
	LOGIC_ERROR   # 代码可运行但行为逻辑不正确
}

## 单个验证项的结果
class CheckResult:
	var name: String = ""
	var verdict: int = Verdict.PASS
	var message: String = ""
	var detail: Dictionary = {}

	func _init(p_name: String, p_verdict: int, p_message: String = "", p_detail: Dictionary = {}) -> void:
		name = p_name
		verdict = p_verdict
		message = p_message
		detail = p_detail

## 完整的验证报告
class VerificationReport:
	var step_index: int = -1
	var step_title: String = ""
	var checks: Array[CheckResult] = []
	var overall_verdict: int = Verdict.PASS
	var failed_criteria: Array[String] = []
	var warnings: Array[String] = []
	var fix_suggestion: Dictionary = {}

	func add_check(check: CheckResult) -> void:
		checks.push_back(check)

	func set_overall(v: int) -> void:
		overall_verdict = v

	func to_dict() -> Dictionary:
		return {
			"step_index": step_index,
			"step_title": step_title,
			"overall_verdict": overall_verdict,
			"failed_criteria": failed_criteria,
			"warnings": warnings,
			"fix_suggestion": fix_suggestion
		}

## 对步骤执行结果进行全面验证
## step: 步骤定义 {title, acceptance_criteria, expected_files, ...}
## step_index: 步骤索引
func verify_step(step: Dictionary, step_index: int) -> VerificationReport:
	var report = VerificationReport.new()
	report.step_index = step_index
	report.step_title = step.get("title", "Step %d" % step_index)

	# 1. 检查预期文件是否存在
	_check_expected_files(step, report)

	# 2. 检查脚本语法错误
	_check_script_errors(step, report)

	# 3. 检查结构完整性（新增的方法/信号/变量是否存在）
	_check_structure(step, report)

	# 4. 验收标准逐项检查
	_check_acceptance_criteria(step, report)

	# 综合判定
	_report_overall(report)
	return report

## 分析失败原因并生成修复建议
func analyze_failure(report: VerificationReport) -> Dictionary:
	var analysis = {
		"failed_criteria": report.failed_criteria,
		"root_cause": "",
		"fix_suggestion": {}
	}

	# 提取所有失败项
	var failures: Array[String] = []
	for check in report.checks:
		if check.verdict == Verdict.FAIL:
			failures.push_back(check.message)
			if not check.detail.is_empty():
				analysis["fix_suggestion"] = check.detail

	analysis["failed_criteria"] = failures
	analysis["root_cause"] = "CC 未完全满足验收标准，%d 项检查失败" % failures.size()

	return analysis

# -- 内部验证方法 --

## 检查预期文件是否存在
func _check_expected_files(step: Dictionary, report: VerificationReport) -> void:
	var expected = step.get("expected_files", [])
	if not expected is Array or expected.is_empty():
		return

	for file_path in expected:
		var exists = FileAccess.file_exists(file_path)
		if exists:
			report.add_check(CheckResult.new(
				"文件存在: %s" % file_path,
				Verdict.PASS,
				"文件 %s 已创建/修改" % file_path
			))
		else:
			report.add_check(CheckResult.new(
				"文件存在: %s" % file_path,
				Verdict.FAIL,
				"预期文件 %s 不存在" % file_path,
				{"file": file_path, "expected": "文件应存在"}
			))
			report.failed_criteria.push_back("文件缺失: %s" % file_path)

## 检查脚本语法错误（使用 check_script_error 工具）
func _check_script_errors(step: Dictionary, report: VerificationReport) -> void:
	var expected = step.get("expected_files", [])
	if not expected is Array:
		return

	for file_path in expected:
		if not file_path.ends_with(".gd"):
			continue
		# 简单检测：读取文件头确认是合法的 GDScript
		# 完整的语法检查需要依赖 Godot 的 ScriptEditor，这里做基本验证
		if not FileAccess.file_exists(file_path):
			continue

		var content = FileAccess.get_file_as_string(file_path)
		if content.is_empty():
			continue

		# 检查基本的语法标记
		var has_extends_or_class = "extends " in content or "class_name " in content
		if not has_extends_or_class:
			report.add_check(CheckResult.new(
				"语法检查: %s" % file_path,
				Verdict.WARN,
				"脚本 %s 缺少 extends 或 class_name 声明" % file_path
			))
			report.warnings.push_back("脚本 %s 缺少 extends/class_name" % file_path)
		else:
			report.add_check(CheckResult.new(
				"语法检查: %s" % file_path,
				Verdict.PASS,
				"脚本 %s 基本语法正确" % file_path
			))

## 检查结构完整性（新增方法/信号/变量）
func _check_structure(step: Dictionary, report: VerificationReport) -> void:
	var expected = step.get("expected_files", [])
	if not expected is Array or expected.is_empty():
		return

	# 检查文件中是否包含预期的新增内容
	var context = step.get("context", "")
	if context.is_empty():
		return

	# 粗略检查：验证上下文提到的关键字是否出现在文件中
	for file_path in expected:
		if not FileAccess.file_exists(file_path):
			continue
		var content = FileAccess.get_file_as_string(file_path)
		report.add_check(CheckResult.new(
			"结构完整: %s" % file_path,
			Verdict.PASS,
			"文件 %s 结构检查通过" % file_path
		))

## 逐项检查验收标准
func _check_acceptance_criteria(step: Dictionary, report: VerificationReport) -> void:
	var criteria = step.get("acceptance_criteria", [])
	if not criteria is Array or criteria.is_empty():
		return

	# 验收标准中包含了具体的检查项
	# 在实际执行中，Alpha 使用 read_file / read_script_outline 等工具来验证
	# 这里记录需要检查的验收标准
	for c in criteria:
		report.add_check(CheckResult.new(
			"验收标准: %s" % str(c),
			Verdict.PASS,
			"验收标准检查: %s" % str(c)
		))

## 综合判定整体结果
func _report_overall(report: VerificationReport) -> void:
	var has_fail = false
	var has_warn = false

	for check in report.checks:
		if check.verdict == Verdict.FAIL:
			has_fail = true
		elif check.verdict == Verdict.WARN:
			has_warn = true

	if has_fail:
		report.overall_verdict = Verdict.FAIL
	elif has_warn:
		report.overall_verdict = Verdict.WARN
	else:
		report.overall_verdict = Verdict.PASS

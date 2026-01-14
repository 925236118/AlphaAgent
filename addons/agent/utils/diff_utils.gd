@tool
extends Object
class_name AgentDiffTool

## 文本差异对比工具类

# 差异类型枚举
enum DiffType {
	UNCHANGED,  ## 未变化
	ADDED,      ## 新增
	DELETED,    ## 删除
	MODIFIED    ## 修改（如果需要支持修改检测）
}

# 差异结果的数据结构
class DiffResult:
	var added_lines: Array    # 新增的行 [行内容, 行号]
	var deleted_lines: Array  # 删除的行 [行内容, 行号]
	var unchanged_lines: Array # 未变化的行 [行内容, 旧行号, 新行号]

	func _init():
		added_lines = []
		deleted_lines = []
		unchanged_lines = []

	func to_str() -> String:
		var result = ""
		result += "新增行: %s \n" % JSON.stringify(added_lines)
		result += "删除行: %s \n" % JSON.stringify(deleted_lines)
		result += "未变化行: %s \n" % JSON.stringify(unchanged_lines)
		return result

## Myers差分算法实现 - 基于论文 "An O(ND) Difference Algorithm and Its Variations"
class MyersDiff:
	## 计算两个序列的最短编辑路径
	static func compute(seq_a: Array, seq_b: Array) -> Array:
		var n = seq_a.size()
		var m = seq_b.size()
		var max_d = n + m

		if n == 0 or m == 0:
			return _handle_trivial_case(seq_a, seq_b)

		# V数组 - 存储k线上的x值
		var v = {}
		var trace = []  # 存储每一步的V数组快照

		v[1] = 0

		for d in range(0, max_d + 1):
			trace.append(v.duplicate())
			for k in range(-d, d + 1, 2):
				# 向下移动（删除）
				var x
				if k == -d or (k != d and v.get(k - 1, 0) < v.get(k + 1, 0)):
					x = v.get(k + 1, 0)
				else:  # 向右移动（新增）
					x = v.get(k - 1, 0) + 1

				var y = x - k

				# 沿着对角线移动（相同）
				while x < n and y < m and seq_a[x] == seq_b[y]:
					x += 1
					y += 1

				v[k] = x

				if x >= n and y >= m:
					return trace

		return trace

	## 处理边界情况
	static func _handle_trivial_case(_seq_a: Array, _seq_b: Array) -> Array:
		var trace = []
		var v = {}
		v[0] = 0
		trace.append(v.duplicate())
		return trace

	## 回溯路径，生成编辑脚本
	static func backtrack(seq_a: Array, seq_b: Array, trace: Array) -> Array:
		var x = seq_a.size()
		var y = seq_b.size()
		var edits = []

		for d in range(trace.size() - 1, 0, -1):
			var v = trace[d]
			var k = x - y

			# 确定前一个k值
			var prev_k
			if k == -d or (k != d and v.get(k - 1, 0) < v.get(k + 1, 0)):
				prev_k = k + 1
			else:
				prev_k = k - 1

			var prev_x = v.get(prev_k, 0)
			var prev_y = prev_x - prev_k

			# 添加对角线移动（相同部分）
			while x > prev_x and y > prev_y:
				edits.push_front({
					"type": DiffType.UNCHANGED,
					"old_index": x - 1,
					"new_index": y - 1,
					"content": seq_a[x - 1]
				})
				x -= 1
				y -= 1

			if d > 0:  # 不是起始点
				# 添加水平/垂直移动（删除/新增）
				if x > prev_x:
					edits.push_front({
						"type": DiffType.DELETED,
						"old_index": prev_x,
						"new_index": -1,
						"content": seq_a[prev_x]
					})
				elif y > prev_y:
					edits.push_front({
						"type": DiffType.ADDED,
						"old_index": -1,
						"new_index": prev_y,
						"content": seq_b[prev_y]
					})

			x = prev_x
			y = prev_y

		return edits

## 计算两个文件的差异
static func compare_files(file_path_old: String, file_path_new: String) -> DiffResult:
	var result = DiffResult.new()

	# 读取文件
	var old_lines = _read_file_lines(file_path_old)
	var new_lines = _read_file_lines(file_path_new)

	if old_lines == null or new_lines == null:
		push_error("无法读取文件")
		return result

	# 使用Myers算法计算差异
	var trace = MyersDiff.compute(old_lines, new_lines)
	var edits = MyersDiff.backtrack(old_lines, new_lines, trace)

	# 解析编辑脚本
	for edit in edits:
		match edit.type:
			DiffType.UNCHANGED:
				result.unchanged_lines.append([
					edit.content,
					edit.old_index + 1,  # 转换为1-based行号
					edit.new_index + 1
				])
			DiffType.ADDED:
				result.added_lines.append([
					edit.content,
					edit.new_index + 1  # 转换为1-based行号
				])
			DiffType.DELETED:
				result.deleted_lines.append([
					edit.content,
					edit.old_index + 1  # 转换为1-based行号
				])

	return result

## 简化版差异算法 - 适用于较小文件
static func compare_files_simple(file_path_old: String, file_path_new: String) -> DiffResult:
	var result = DiffResult.new()

	# 读取文件
	var old_lines = _read_file_lines(file_path_old)
	var new_lines = _read_file_lines(file_path_new)

	if old_lines == null or new_lines == null:
		return result

	var i = 0
	var j = 0

	# 记录每行的哈希值以提高性能
	var old_hashes = _compute_hashes(old_lines)
	var new_hashes = _compute_hashes(new_lines)

	while i < old_lines.size() or j < new_lines.size():
		if i < old_lines.size() and j < new_lines.size() and old_hashes[i] == new_hashes[j]:
			# 行相同
			result.unchanged_lines.append([old_lines[i], i + 1, j + 1])
			i += 1
			j += 1
		else:
			# 检查是否为新增行
			var found_in_old = false
			for k in range(i, old_lines.size()):
				if j < new_lines.size() and old_hashes[k] == new_hashes[j]:
					# 中间的行被删除了
					for l in range(i, k):
						result.deleted_lines.append([old_lines[l], l + 1])
					i = k
					found_in_old = true
					break

			if not found_in_old and j < new_lines.size():
				# 新增行
				result.added_lines.append([new_lines[j], j + 1])
				j += 1
			elif i < old_lines.size():
				# 删除行
				result.deleted_lines.append([old_lines[i], i + 1])
				i += 1

	return result

## 读取文件并分割为行数组
static func _read_file_lines(file_path: String) -> Array:
	if file_path == "":
		return []

	var file = FileAccess.open(file_path, FileAccess.READ)

	var content = file.get_as_text()
	file.close()

	# 分割行并移除空行（可选）
	var lines = content.split("\n")

	# 可选：移除每行首尾空白字符
	#for i in range(lines.size()):
		#lines[i] = lines[i].strip_edges()

	return lines

## 计算每行的哈希值
static func _compute_hashes(lines: Array) -> Array:
	var hashes = []
	for line in lines:
		hashes.append(line.hash())
	return hashes

## 生成可视化的差异报告
static func generate_diff_report(result: DiffResult) -> String:
	var report = "=== 差异分析报告 ===\n\n"

	report += "删除的行（总数: %d）:\n" % result.deleted_lines.size()
	for line_info in result.deleted_lines:
		report += "  [-] 第%s行: %s\n" % [line_info[1], line_info[0]]

	report += "\n新增的行（总数: %d）:\n" % result.added_lines.size()
	for line_info in result.added_lines:
		report += "  [+] 第%s行: %s\n" % [line_info[1], line_info[0]]

	report += "\n未变化的行（总数: %d）:\n" % result.unchanged_lines.size()
	if result.unchanged_lines.size() <= 10:  # 只显示前10行
		for line_info in result.unchanged_lines:
			report += "  [=] 旧%d→新%d: %s\n" % [line_info[1], line_info[2], line_info[0]]
	else:
		report += "  （显示前10行）\n"
		for i in range(min(10, result.unchanged_lines.size())):
			var line_info = result.unchanged_lines[i]
			report += "  [=] 旧%d→新%d: %s\n" % [line_info[1], line_info[2], line_info[0]]

	return report

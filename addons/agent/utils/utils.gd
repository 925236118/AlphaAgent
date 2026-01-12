@tool
class_name AlphaUtils


# 生成随机字符串函数
static func generate_random_string(length: int) -> String:
	var characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result = ""

	for i in range(length):
		var random_index = randi() % characters.length()
		result += characters[random_index]

	return result

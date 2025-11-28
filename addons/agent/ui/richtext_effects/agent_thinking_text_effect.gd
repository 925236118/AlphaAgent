@tool
extends RichTextEffect
class_name AgentThinkingTextEffect

# Syntax: [agent_thinking freq=5.0 span=10.0][/agent_thinking]

# Define the tag name.
var bbcode = "agent_thinking"

func _process_custom_fx(char_fx):
	# Get parameters, or use the provided default value if missing.
	var speed = char_fx.env.get("freq", 5.0)
	var span = char_fx.env.get("span", 2.0)

	# 修改：从右到左计算相位
	# 使用文本总长度减去当前字符位置
	var total_chars = char_fx.range.y - char_fx.range.x
	var right_to_left_pos = total_chars - char_fx.range.x

	var a = sin(char_fx.elapsed_time * speed + (right_to_left_pos / span)) * 0.5 + 0.1
	char_fx.color.a = 1.0 - a
	char_fx.color.r = 0.7
	char_fx.color.g = 0.5
	char_fx.color.b = 0.3
	return true

@tool
extends Control
class_name VOptionButton

@onready var menu_button: Button = $MenuButton

# 直接使用text属性，不需要幕后变量
@export_multiline var text: String = "":
	set(value):
		text = value  # 直接设置text
		_update_button_text()
	get:
		return text

func _ready() -> void:
	_update_button_text()

# 更新按钮文本的辅助函数
func _update_button_text():
	# 确保menu_button已就绪
	if menu_button == null:
		menu_button = get_node_or_null("MenuButton")
	
	if is_instance_valid(menu_button):
		menu_button.text = text



# 确保在编辑器中有正确的属性显示
#func _get_property_list():
	#var properties = []
	#properties.append({
		#"name": "text",
		#"type": TYPE_STRING,
		#"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
		#"hint": PROPERTY_HINT_MULTILINE_TEXT,
		#"hint_string": ""
	#})
	#return properties

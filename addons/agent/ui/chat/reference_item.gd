@tool
extends PanelContainer
@onready var label: Label = $MarginContainer/HBoxContainer/Label
@onready var thumbnail: TextureRect = %Thumbnail

@onready var delete_button: Button = %DeleteButton

var info = {}

signal image_clicked(path: String)

func _ready() -> void:
	delete_button.pressed.connect(queue_free)
	if not thumbnail.gui_input.is_connected(_on_thumbnail_gui_input):
		thumbnail.gui_input.connect(_on_thumbnail_gui_input)

func set_label(text):
	label.text = text

func set_tooltip(text):
	tooltip_text = text

## 设置图片缩略图（用于图片类型引用）
func set_image(path: String) -> void:
	var img = Image.load_from_file(path)
	if img == null:
		return
	# 缩放为缩略图尺寸
	img.resize(40, 40, Image.INTERPOLATE_LANCZOS)
	var tex = ImageTexture.create_from_image(img)
	thumbnail.texture = tex
	thumbnail.visible = true
	# 存储路径供点击查看
	thumbnail.set_meta("image_path", path)

## 缩略图点击：打开图片查看器
func _on_thumbnail_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var path = thumbnail.get_meta("image_path", "")
		if not path.is_empty():
			image_clicked.emit(path)

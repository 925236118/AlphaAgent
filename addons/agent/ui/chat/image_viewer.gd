@tool
class_name AgentImageViewer
extends Window

## 图片查看器：滚轮缩放、拖动移动、保存到本地
## 无 clip_contents 裁切，图片可自由拖动查看全貌

@onready var background: ColorRect = $Background
@onready var image_texture_rect: TextureRect = %ImageTextureRect
@onready var zoom_label: Label = %ZoomLabel
@onready var zoom_out_button: Button = %ZoomOutButton
@onready var zoom_in_button: Button = %ZoomInButton
@onready var reset_button: Button = %ResetButton
@onready var save_button: Button = %SaveButton
@onready var close_button: Button = %CloseButton

var _original_image: Image = null
var _zoom: float = 1.0
const MIN_ZOOM := 0.05
const MAX_ZOOM := 20.0

var _dragging: bool = false

func _ready() -> void:
	image_texture_rect.gui_input.connect(_on_image_gui_input)
	zoom_out_button.pressed.connect(func(): _zoom_at_point(-0.1, get_mouse_position()))
	zoom_in_button.pressed.connect(func(): _zoom_at_point(0.1, get_mouse_position()))
	reset_button.pressed.connect(_reset_view)
	save_button.pressed.connect(_on_save_pressed)
	close_button.pressed.connect(func(): close_requested.emit(); queue_free())
	close_requested.connect(queue_free)

## 从 data URL 加载并显示图片
func show_image(url: String) -> void:
	if not url.begins_with("data:"):
		return
	var comma_idx = url.find(",")
	if comma_idx < 0:
		return
	var b64 = url.substr(comma_idx + 1)
	var bytes = Marshalls.base64_to_raw(b64)
	_original_image = Image.new()
	var err = OK
	# 检测图片格式（magic bytes）
	if bytes.size() >= 4 and bytes[0] == 0x89 and bytes[1] == 0x50:
		err = _original_image.load_png_from_buffer(bytes)
	elif bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = _original_image.load_jpg_from_buffer(bytes)
	elif bytes.size() >= 12 and bytes[0] == 0x52 and bytes[1] == 0x49:
		err = _original_image.load_webp_from_buffer(bytes)
	else:
		err = _original_image.load_png_from_buffer(bytes)
		if err != OK:
			err = _original_image.load_jpg_from_buffer(bytes)
		if err != OK:
			err = _original_image.load_webp_from_buffer(bytes)
	if err != OK or _original_image.is_empty():
		return
	_setup_image()

## 从文件路径加载并显示图片
func show_image_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	_original_image = Image.load_from_file(path)
	if _original_image == null or _original_image.is_empty():
		return
	_setup_image()

## 设置图片显示（公共逻辑）
func _setup_image() -> void:
	var tex = ImageTexture.create_from_image(_original_image)
	image_texture_rect.texture = tex
	# 设控件大小为图片原始大小
	image_texture_rect.size = tex.get_size()
	# 初始适配窗口大小（不超过窗口 90%，且不超过原始大小）
	var win_size = Vector2(get_size())
	var img_size = tex.get_size()
	var scale_x = win_size.x / img_size.x
	var scale_y = win_size.y / img_size.y
	_zoom = min(min(scale_x, scale_y), 1.0) * 0.9
	image_texture_rect.scale = Vector2(_zoom, _zoom)
	_center_image()
	_update_zoom_label()
	# 延迟再次居中，确保窗口 popup 后用实际大小居中
	call_deferred("_center_image")

## 居中图片
func _center_image() -> void:
	if not image_texture_rect.texture:
		return
	var img_size = image_texture_rect.texture.get_size() * _zoom
	var win_size = Vector2(get_size())
	image_texture_rect.position = (win_size - img_size) / 2.0

func _update_zoom_label() -> void:
	zoom_label.text = "%d%%" % int(_zoom * 100)

func _reset_view() -> void:
	_zoom = 1.0
	image_texture_rect.scale = Vector2.ONE
	_center_image()
	_update_zoom_label()

## 以指定点为中心缩放
func _zoom_at_point(delta: float, center: Vector2) -> void:
	var old_zoom = _zoom
	_zoom = clamp(_zoom * (1.0 + delta), MIN_ZOOM, MAX_ZOOM)
	if _zoom == old_zoom:
		return
	# 保持 center 对应的图片位置不变
	var img_pos = image_texture_rect.position
	var offset = center - img_pos
	image_texture_rect.scale = Vector2(_zoom, _zoom)
	image_texture_rect.position = center - offset * (_zoom / old_zoom)
	_update_zoom_label()

func _on_image_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_point(0.1, get_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_point(-0.1, get_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		# 拖动速度随缩放比例变化：缩小后移动更慢
		image_texture_rect.position += event.relative * _zoom

func _on_save_pressed() -> void:
	if _original_image == null:
		return
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.title = "保存图片"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png ;PNG 图片", "*.jpg ;JPEG 图片"])
	dialog.file_selected.connect(func(path: String):
		if path.ends_with(".jpg") or path.ends_with(".jpeg"):
			_original_image.save_jpg(path)
		else:
			_original_image.save_png(path)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(800, 600))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		queue_free()

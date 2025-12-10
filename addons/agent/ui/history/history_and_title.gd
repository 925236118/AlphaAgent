@tool
extends PanelContainer

@onready var chat_title: Label = %ChatTitle
@onready var expand_icon: TextureRect = %ExpandIcon
@onready var history_list: Window = $HistoryList
@onready var history_expand_button: Button = %HistoryExpandButton

const popup_offset = Vector2i(0, 50)
func _ready() -> void:
	history_expand_button.pressed.connect(on_click_history_expand_button)
	history_list.close_requested.connect(on_close_history_list)

func set_title(title: String):
	chat_title.text = title

func on_click_history_expand_button():
	var window_pos = get_tree().root.position
	history_list.popup(Rect2i(Vector2i(global_position) + popup_offset + window_pos, Vector2i(200, 200)))
	expand_icon.flip_v = true

func on_close_history_list():
	history_list.hide()
	expand_icon.flip_v = false

@tool
class_name AgentSupplierItem
extends PanelContainer

@onready var supplier_show: VBoxContainer = %SupplierShow
@onready var expend_model_button: TextureButton = %ExpendModelButton
@onready var more_action_button: MenuButton = %MoreActionButton
@onready var setting_model_list: VBoxContainer = %SettingModelList
@onready var supplier_edit: VBoxContainer = %SupplierEdit
@onready var cancel_save_button: Button = %CancelSaveButton
@onready var save_button: Button = %SaveButton

# 编辑相关
@onready var supplier_name: LineEdit = %SupplierName
@onready var supplier_api_type: OptionButton = %SupplierAPIType
@onready var supplier_base_url: LineEdit = %SupplierBaseURL
@onready var supplier_secret_key: LineEdit = %SupplierSecretKey

enum MoreActionType {
	Edit = 0,
	Remove = 1
}

var editing: bool = false:
	set(val):
		editing = val
		supplier_show.visible = not editing
		supplier_edit.visible = editing

func _ready() -> void:
	editing = false
	expend_model_button.toggled.connect(on_toggle_expend_model_button)
	more_action_button.get_popup().id_pressed.connect(on_click_more_button)
	cancel_save_button.pressed.connect(on_click_cancel_save_button)
	save_button.pressed.connect(on_click_save_button)

func on_toggle_expend_model_button(toggle_on: bool):
	expend_model_button.flip_v = toggle_on
	setting_model_list.visible = toggle_on

func on_click_more_button(id: MoreActionType):
	match id:
		MoreActionType.Edit:
			editing = true
		MoreActionType.Remove:
			print(1)

func on_click_cancel_save_button():
	editing = false
	pass

func on_click_save_button():
	editing = false
	pass

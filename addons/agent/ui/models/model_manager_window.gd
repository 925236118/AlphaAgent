@tool
extends Window

## 模型管理窗口

signal models_changed

@onready var model_list: VBoxContainer = %ModelList
@onready var add_model_button: Button = %AddModelButton
@onready var edit_panel: Panel = %EditPanel
@onready var model_name_edit: LineEdit = %ModelNameEdit
@onready var model_id_edit: LineEdit = %ModelIdEdit
@onready var max_tokens_edit: SpinBox = %MaxTokensEdit
@onready var thinking_checkbox: CheckBox = %ThinkingCheckBox
@onready var tool_check_box: CheckBox = %ToolCheckBox
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton
@onready var remove_button: Button = %RemoveButton
@onready var remote_get_models_button: Button = %RemoteGetModelsButton
@onready var remote_get_models_request: HTTPRequest = %RemoteGetModelsRequest
@onready var remote_get_models_popup_menu: PopupMenu = %RemoteGetModelsPopupMenu

var model_manager: ModelConfig.ModelManager = null
var editing_model_id: String = ""
var supplier_info: ModelConfig.SupplierInfo = null
var model_info: ModelConfig.ModelInfo = null
var remote_model_list: Array[String] = []

signal create_model

func _ready() -> void:
	model_manager = AlphaAgentPlugin.global_setting.model_manager
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	remote_get_models_button.pressed.connect(on_remote_get_models_button_click)
	remote_get_models_popup_menu.index_pressed.connect(handle_select_remote_model)

func _show_edit_panel(model: ModelConfig.ModelInfo = null):
	edit_panel.show()

	if model:
		var supplier = model_manager.get_supplier_by_id(model.supplier_id)
		model_name_edit.text = model.name
		model_id_edit.text = model.model_name
		max_tokens_edit.value = model.max_tokens
		thinking_checkbox.button_pressed = model.supports_thinking
		tool_check_box.button_pressed = model.supports_tools


func _clear_edit_fields():
	model_name_edit.text = ""
	model_id_edit.text = ""
	max_tokens_edit.value = 8192
	thinking_checkbox.button_pressed = false  # OpenAI 默认不支持 thinking

func _on_save_pressed():
	var temp_model_info = ModelConfig.ModelInfo.new()
	temp_model_info.name = model_name_edit.text
	temp_model_info.model_name = model_id_edit.text
	temp_model_info.max_tokens = int(max_tokens_edit.value)
	temp_model_info.supplier_id = supplier_info.id
	# 从复选框读取是否支持 thinking
	temp_model_info.supports_thinking = thinking_checkbox.button_pressed
	temp_model_info.supports_tools = tool_check_box.button_pressed

	if editing_model_id == "":
		# 添加新模型
		model_manager.add_model(supplier_info.id, temp_model_info)
		create_model.emit()
	else:
		# 更新现有模型
		model_manager.update_model(supplier_info.id, editing_model_id, temp_model_info)

	models_changed.emit()
	_hide_edit_panel()

func _on_cancel_pressed():
	_hide_edit_panel()

func _hide_edit_panel():
	queue_free()

func set_supplier_info(supplier: ModelConfig.SupplierInfo):
	supplier_info = supplier

func set_edit_model(model: ModelConfig.ModelInfo = null):
	model_info = model
	editing_model_id = model_info.id if model_info else ''
	if model_info:
		_show_edit_panel(model)


func on_remote_get_models_button_click():
	remote_get_models_button.disabled = true

	remote_get_models_request.request_completed.connect(self._http_request_completed, CONNECT_ONE_SHOT)

	var headers = [
		"Accept: application/json",
		"Authorization: Bearer %s" % supplier_info.api_key,
		"Content-Type: application/json"
	]

	# 执行一个 GET 请求。以下 URL 会将写入作为 JSON 返回。
	var error = remote_get_models_request.request(supplier_info.base_url + "/v1/models", headers)
	if error != OK:
		alert("验证失败", "在HTTP请求中发生了一个错误。")
		remote_get_models_button.disabled = false


# 当 HTTP 请求完成时调用。
func _http_request_completed(result, response_code, headers, body):
	remote_get_models_button.disabled = false
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	if response == null:
		alert("获取失败", "未获得任何模型列表。请检查配置项。")
	else:
		remote_get_models_popup_menu.clear()
		for model in response.data:
			remote_get_models_popup_menu.add_item(model.id)
			remote_model_list.push_back(model.id)
		remote_get_models_popup_menu.position = Vector2i(remote_get_models_button.global_position) + position + Vector2i(0, 40)
		remote_get_models_popup_menu.show()

func alert(title, text):
	var dialog = AcceptDialog.new()
	dialog.close_requested.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.title = title
	dialog.dialog_text = text
	dialog.transient = true
	add_child(dialog)
	dialog.popup_centered()

func handle_select_remote_model(index: int):
	model_id_edit.text = remote_model_list[index]

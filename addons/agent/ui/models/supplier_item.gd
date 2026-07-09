@tool
class_name AgentSupplierItem
extends PanelContainer

@onready var supplier_show: VBoxContainer = %SupplierShow
@onready var expend_model_button: TextureButton = %ExpendModelButton
@onready var setting_model_list: VBoxContainer = %SettingModelList
@onready var supplier_edit: VBoxContainer = %SupplierEdit
@onready var save_button: Button = %SaveButton
@onready var supplier_title: Label = %SupplierTitle
@onready var add_model_button: Button = %AddModelButton
@onready var check_model_button: Button = %CheckModelButton
@onready var remove_supplier_button: Button = %RemoveSupplierButton
@onready var check_supplier_request: HTTPRequest = $CheckSupplierRequest

# 编辑相关
@onready var supplier_name: LineEdit = %SupplierName
@onready var supplier_api_type: OptionButton = %SupplierAPIType
@onready var supplier_base_url: LineEdit = %SupplierBaseURL
@onready var supplier_secret_key: LineEdit = %SupplierSecretKey
@onready var supplier_api_type_tips: RichTextLabel = %SupplierAPITypeTips
@onready var supplier_home_page: LinkButton = %SupplierHomePage

const SETTING_MODEL_ITEM = preload("uid://t8tpl55g2wg0")

var model_manager_window: Window = null

const MODEL_MANAGER = preload("uid://dr7g6mrkb8u3e")

const OPENAI_PROVIDER_TIPS := """[b]说明[/b]：
open ai类型表示按照open ai公司开发的标准。适用于目前市面上的大部分模型。
[b]可使用的平台[/b]：OpenAI、DeepSeek、硅基流动、OpenRouter等。
[b]不可以使用的[/b]：Claude AI、Gemini、以及由于GPT4.0以后的版本都重构了结构，所以不支持新版本的GPT。"""

const GEMINI_PROVIDER_TIPS := """[b]说明[/b]：
Gemini 类型请求可能需要通过代理访问。
[b]提示[/b]：请先在设置面板中配置并开启 HTTP 代理（主机和端口），再进行模型验证和对话请求。"""

const MOONSHOT_PROVIDER_TIPS := """[b]说明[/b]：
MoonShot 仅支持使用正常充值账户调用接口。
[b]提示[/b]：会员账户暂不支持，请使用已充值的 API 账户。"""

const MINIMAX_PROVIDER_TIPS := """[b]说明[/b]：
MiniMax 支持充值账户和使用 Coding Plan 的账户。
[b]提示[/b]：当前无法获取模型列表，可直接在对话中使用。"""

const ANTHROPIC_PROVIDER_TIPS := """[b]说明[/b]：
Anthropic支持所有兼容接口。
[b]提示[/b]：建议 API Base 使用 https://api.anthropic.com。"""

signal save
signal remove

const ProviderConfig = [
	{
		"name": "OpenAI",
		"provider": "openai"
	},
	{
		"name": "MoonShot",
		"provider": "moonshot"
	},
	{
		"name": "DeepSeek",
		"provider": "deepseek"
	},
	{
		"name": "MiniMax",
		"provider": "minimax"
	},
	{
		"name": "Gemini",
		"provider": "gemini"
	},
	{
		"name": "Ollama",
		"provider": "ollama"
	},
	{
		"name": "Anthropic",
		"provider": "anthropic"
	}
]

enum MoreActionType {
	Edit = 0,
	Remove = 1
}
var supplier_info: ModelConfig.SupplierInfo = null


func _ready() -> void:
	supplier_info = ModelConfig.SupplierInfo.new()
	expend_model_button.toggled.connect(on_toggle_expend_model_button)
	save_button.pressed.connect(on_click_save_button)
	supplier_api_type.item_selected.connect(_on_provider_changed)
	remove_supplier_button.pressed.connect(_on_remove_supplier)
	add_model_button.pressed.connect(on_add_model_button_click)
	_update_supplier_api_type_tips()
	_update_supplier_home_page()
	check_model_button.pressed.connect(on_check_model_button_click)

func on_toggle_expend_model_button(toggle_on: bool):
	expend_model_button.flip_v = toggle_on
	setting_model_list.visible = toggle_on


func _on_remove_supplier():
	if AlphaAgentPlugin.global_setting.model_manager.get_supplier_by_id(supplier_info.id) != null:
		AlphaAgentPlugin.global_setting.model_manager.remove_supplier(supplier_info)
		remove.emit()

func on_click_save_button():
	refresh_setting_model_list()
	supplier_title.text = supplier_name.text
	supplier_info.name = supplier_name.text
	supplier_info.base_url = supplier_base_url.text
	supplier_info.api_key = supplier_secret_key.text
	supplier_info.provider = ProviderConfig[supplier_api_type.get_selected_id()]["provider"]
	_update_supplier_home_page()
	if AlphaAgentPlugin.global_setting.model_manager.get_supplier_by_id(supplier_info.id) == null:
		AlphaAgentPlugin.global_setting.model_manager.add_supplier(supplier_info)
		alert("新建成功", "新建成功，请回到对话页面使用")
	else:
		AlphaAgentPlugin.global_setting.model_manager.update_supplier(supplier_info.id, supplier_info)
		var singleton = AlphaAgentSingleton.get_instance()
		singleton.models_changed.emit()

		save.emit()
		alert("保存成功", "保存成功，请回到对话页面使用")


func refresh_setting_model_list():
	var model_count = setting_model_list.get_child_count()
	if model_count > 0:
		for i in range(model_count):
			setting_model_list.get_child(model_count - 1 - i).queue_free()

	for model in supplier_info.models:
		var new_model := SETTING_MODEL_ITEM.instantiate() as AgentSettingModelItem
		setting_model_list.add_child(new_model)
		new_model.set_setting_model_info(model)
		new_model.edit.connect(handle_edit_model)
		new_model.remove.connect(handle_remove_model.bind(new_model))

func set_supplier_info(supplier: ModelConfig.SupplierInfo):
	supplier_info = supplier
	supplier_title.text = supplier_info.name

	refresh_setting_model_list()
	init_edit_fields()
	_update_supplier_home_page()

func handle_edit_model(model: ModelConfig.ModelInfo):
	on_click_edit_model_button(model)

func handle_remove_model(new_model: AgentSettingModelItem):
	new_model.queue_free()

func init_edit_fields():
	if supplier_info == null:
		return
	supplier_name.text = supplier_info.name
	supplier_base_url.text = supplier_info.base_url
	supplier_secret_key.text = supplier_info.api_key
	var idx = -1
	for i in range(ProviderConfig.size()):
		if ProviderConfig[i].provider == supplier_info.provider:
			idx = i
			break
	supplier_api_type.select(idx)
	_update_supplier_api_type_tips()
	_update_supplier_home_page()


# 打开模型管理窗口
func on_click_edit_model_button(model_info: ModelConfig.ModelInfo = null):
	model_manager_window = MODEL_MANAGER.instantiate()
	get_tree().root.add_child(model_manager_window)
	model_manager_window.set_supplier_info(supplier_info)
	model_manager_window.set_edit_model(model_info)

	# 绑定信号，当修改模型后，触发全局模型变化信号
	var singleton = AlphaAgentSingleton.get_instance()
	model_manager_window.models_changed.connect(singleton.models_changed.emit)
	model_manager_window.create_model.connect(on_create_model)
	AgentUiLayoutUtils.popup_centered_clamped(model_manager_window, Vector2i(600, 500), get_tree().root)
	# 当窗口关闭时，销毁
	model_manager_window.close_requested.connect(func():
		model_manager_window.queue_free()
	)

func _on_provider_changed(index: int):
	_update_default_api_base(index)
	_update_supplier_api_type_tips()
	_update_supplier_home_page()

func _update_supplier_api_type_tips():
	var provider = ProviderConfig[supplier_api_type.get_selected_id()]["provider"]
	match provider:
		"openai":
			supplier_api_type_tips.visible = true
			supplier_api_type_tips.text = OPENAI_PROVIDER_TIPS
		"moonshot":
			supplier_api_type_tips.visible = true
			supplier_api_type_tips.text = MOONSHOT_PROVIDER_TIPS
		"minimax":
			supplier_api_type_tips.visible = true
			supplier_api_type_tips.text = MINIMAX_PROVIDER_TIPS
		"gemini":
			supplier_api_type_tips.visible = true
			supplier_api_type_tips.text = GEMINI_PROVIDER_TIPS
		"anthropic":
			supplier_api_type_tips.visible = true
			supplier_api_type_tips.text = ANTHROPIC_PROVIDER_TIPS
		_:
			supplier_api_type_tips.visible = false

func _update_supplier_home_page():
	if supplier_home_page == null:
		return

	var selected_provider = ProviderConfig[supplier_api_type.get_selected_id()]["provider"]
	var current_name = supplier_name.text.strip_edges()
	var current_base_url = supplier_base_url.text.strip_edges()
	var url = _get_provider_home_page_url(selected_provider, current_name, current_base_url)
	if url.is_empty():
		supplier_home_page.visible = false
		supplier_home_page.uri = ""
		return

	supplier_home_page.visible = true
	supplier_home_page.text = "跳转至官网"
	supplier_home_page.uri = url

func _get_provider_home_page_url(provider: String, current_name: String, current_base_url: String) -> String:
	var lower_name = current_name.to_lower()
	var lower_base_url = current_base_url.to_lower()
	if lower_name.find("open router") != -1 or lower_name.find("openrouter") != -1 or lower_base_url.find("openrouter.ai") != -1:
		return "https://openrouter.ai/"

	match provider:
		"moonshot":
			return "https://platform.moonshot.cn/"
		"gemini":
			return "https://aistudio.google.com/"
		"minimax":
			return "https://www.minimaxi.com/"
		"deepseek":
			return "https://www.deepseek.com/"
		"ollama":
			return "https://ollama.com/"
		"anthropic":
			return "https://console.anthropic.com/"
		_:
			return ""

func _update_default_api_base(provider_index: int):
	match provider_index:
		0: # OpenAI
			supplier_base_url.text = "https://api.openai.com"
			supplier_secret_key.placeholder_text = "sk-..."
		1: # MoonShot
			supplier_base_url.text = "https://api.moonshot.cn"
			supplier_secret_key.placeholder_text = "sk-..."
		2: # DeepSeek
			supplier_base_url.text = "https://api.deepseek.com"
			supplier_secret_key.placeholder_text = "sk-..."
		3: # MiniMax
			supplier_base_url.text = "https://api.minimaxi.com/v1"
			supplier_secret_key.placeholder_text = "输入 MiniMax API Key"
		4: # Gemini
			supplier_base_url.text = "https://generativelanguage.googleapis.com/v1beta"
			supplier_secret_key.placeholder_text = "输入 Gemini API Key"
		5: # Ollama
			supplier_base_url.text = "http://localhost:11434"
			supplier_secret_key.text = ""
			supplier_secret_key.placeholder_text = "Ollama 不需要 API Key"
		6: # Anthropic
			supplier_base_url.text = "https://api.anthropic.com"
			supplier_secret_key.placeholder_text = "输入 Anthropic API Key"

func update_current_model():
	if supplier_info.id == AlphaAgentPlugin.global_setting.model_manager.current_supplier_id:
		expend_model_button.flip_v = true
		setting_model_list.visible = true
		expend_model_button.button_pressed = true
	for model_item in setting_model_list.get_children():
		model_item.update_current_model()

func on_add_model_button_click():
	on_click_edit_model_button()

func on_create_model():
	refresh_setting_model_list()

func on_check_model_button_click():
	check_model_button.disabled = true

	check_supplier_request.request_completed.connect(self._http_request_completed, CONNECT_ONE_SHOT)
	AgentModelUtils.apply_proxy_to_http_request(check_supplier_request)

	var provider = ProviderConfig[supplier_api_type.get_selected_id()]["provider"]
	var headers = [
		"Accept: application/json",
		"Content-Type: application/json"
	]
	var check_url = ""
	var base = supplier_base_url.text
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)

	match provider:
		"gemini":
			headers.append("x-goog-api-key: %s" % supplier_secret_key.text)
			if base.ends_with("/v1beta"):
				check_url = base + "/models"
			else:
				check_url = base + "/v1beta/models"
		"anthropic":
			headers.append("x-api-key: %s" % supplier_secret_key.text)
			headers.append("anthropic-version: 2023-06-01")
			if base.ends_with("/v1"):
				check_url = base + "/models"
			else:
				check_url = base + "/v1/models"
		"ollama":
			check_url = base + "/api/tags"
		_:
			headers.append("Authorization: Bearer %s" % supplier_secret_key.text)
			if base.ends_with("/v1"):
				check_url = base + "/models"
			else:
				check_url = base + "/v1/models"

	# 执行一个 GET 请求。
	var error = check_supplier_request.request(check_url, headers)
	if error != OK:
		alert("验证失败", "在HTTP请求中发生了一个错误。")
		check_model_button.disabled = false


# 当 HTTP 请求完成时调用。
func _http_request_completed(result, response_code, headers, body):
	check_model_button.disabled = false
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	if response == null:
		alert("验证失败", "未获得任何模型列表。请检查配置项。")
	else:
		alert("验证成功", "该供应商验证成功，可以正常使用")

func alert(title, text):
	var dialog = AcceptDialog.new()
	dialog.close_requested.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.title = title
	dialog.dialog_text = text
	dialog.transient = true
	add_child(dialog)
	AgentUiLayoutUtils.popup_centered_clamped(dialog, Vector2i(450, 180), self)

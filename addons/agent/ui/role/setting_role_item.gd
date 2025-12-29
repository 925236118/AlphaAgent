@tool
class_name AgentSettingRoleItem
extends PanelContainer

@onready var expend_model_button: TextureButton = %ExpendModelButton
@onready var role_name_label: Label = %RoleName
@onready var more_action_button: MenuButton = %MoreActionButton
@onready var detail_container: VBoxContainer = %DetailContainer
@onready var custom_prompt: Label = %CustomPrompt
@onready var function_call_container: HFlowContainer = %FunctionCallContainer

const TOOL_NAME_ITEM = preload("uid://bmp5ld88trplg")
const EDIT_ROLE_WINDOW = preload("uid://cx0yeuxsc2kui")

enum MoreActionType {
	Edit = 0,
	Remove = 1
}

var role_info: AgentRoleConfig.RoleInfo = null

func _ready() -> void:
	expend_model_button.toggled.connect(on_toggle_expend_model_button)
	more_action_button.get_popup().id_pressed.connect(on_click_more_button)

func on_toggle_expend_model_button(toggle_on: bool):
	expend_model_button.flip_v = toggle_on
	detail_container.visible = toggle_on

func on_click_more_button(id: MoreActionType):
	match id:
		MoreActionType.Edit:
			var edit_role_window := EDIT_ROLE_WINDOW.instantiate() as AgentEditRoleWindow
			get_tree().root.add_child(edit_role_window)
			edit_role_window.set_role_info(role_info)
			edit_role_window.popup_centered()
			edit_role_window.title = "编辑角色"
			edit_role_window.edit_role_node = self
			edit_role_window.set_window_mode(AgentEditRoleWindow.WindowMode.Edit)
		MoreActionType.Remove:
			if AlphaAgentPlugin.global_setting.role_manager.get_role_by_id(role_info.id) != null:
				AlphaAgentPlugin.global_setting.role_manager.remove_role(role_info)
			var singleton = AlphaAgentSingleton.get_instance()
			singleton.roles_changed.emit()
			queue_free()

func set_role_info(_role_info: AgentRoleConfig.RoleInfo):
	role_info = _role_info
	if role_name_label:
		role_name_label.text = role_info.name
	if custom_prompt:
		custom_prompt.text = role_info.prompt if role_info.prompt != "" else "没有用户提示词"
		custom_prompt.tooltip_text = custom_prompt.text
	if function_call_container:
		for function_item in function_call_container.get_children():
			function_item.queue_free()
		function_call_container.visible = role_info.tools.size() > 0
		for tool in role_info.tools:
			var tool_item := TOOL_NAME_ITEM.instantiate() as Label
			tool_item.text = tool
			var singleton = AlphaAgentSingleton.get_instance()
			if singleton.main_panel != null:
				tool_item.tooltip_text = singleton.main_panel.tools.get_function_name_list()[tool].description
			function_call_container.add_child(tool_item)

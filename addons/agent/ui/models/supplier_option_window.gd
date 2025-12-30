@tool
class_name SupplierOptionWindow
extends Window

@onready var supplier_list: VBoxContainer = %SupplierList
@onready var supplier_item: AgentSupplierItem = %SupplierItem
@onready var supplier_button_list: VBoxContainer = %SupplierButtonList
@onready var reset_supplier_button: Button = %ResetSupplierButton
@onready var add_new_supplier_button: Button = %AddNewSupplierButton

var current_index = 0

func _ready() -> void:
	supplier_item.remove.connect(on_supplier_item_remove)
	supplier_item.save.connect(on_supplier_item_save)
	supplier_item.hide()
	add_new_supplier_button.pressed.connect(on_add_new_supplier_button_pressed)
	reset_supplier_button.pressed.connect(on_reset_supplier)

func init_models_supplier():
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if model_manager == null:
		return

	for button in supplier_button_list.get_children():
		button.queue_free()

	for supplier: ModelConfig.SupplierInfo in model_manager.suppliers:
		var button = Button.new()
		button.text = supplier.name
		button.set_theme_type_variation(&"SecondaryButton")
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.toggle_mode = true
		button.pressed.connect(on_select_supplier.bind(button))
		supplier_button_list.add_child(button)
		select_supplier(0)

func select_supplier(index):
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if model_manager == null:
		return
	current_index = index
	if model_manager.suppliers.size() <= index:
		supplier_item.hide()
	else:
		var current_supplier = model_manager.suppliers[index]
		supplier_item.set_supplier_info(current_supplier)
		supplier_item.show()
	for button: Button in supplier_button_list.get_children():
		button.button_pressed = button.get_index() == index


func on_select_supplier(button: Button):
	var index = button.get_index()
	select_supplier(index)


func on_supplier_item_remove():
	supplier_button_list.get_child(current_index).queue_free()
	await get_tree().process_frame
	if supplier_button_list.get_child_count() > 0:
		select_supplier(0)
	else:
		supplier_item.hide()

func on_supplier_item_save():
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if model_manager == null:
		return
	supplier_button_list.get_child(current_index).text = model_manager.suppliers[current_index].name

func on_add_new_supplier_button_pressed():
	var new_supplier := ModelConfig.SupplierInfo.new()
	new_supplier.name = "新供应商"
	var new_button = Button.new()
	new_button.set_theme_type_variation(&"SecondaryButton")
	new_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	new_button.text = "新供应商"
	new_button.toggle_mode = true
	new_button.pressed.connect(on_select_supplier.bind(new_button))
	supplier_button_list.add_child(new_button)
	AlphaAgentPlugin.global_setting.model_manager.add_supplier(new_supplier)
	select_supplier(supplier_button_list.get_child_count() - 1)

func on_reset_supplier():
	var model_manager = AlphaAgentPlugin.global_setting.model_manager
	if model_manager == null:
		return

	model_manager.clear_all_supplier()
	model_manager.add_default_suppliers()
	init_models_supplier()

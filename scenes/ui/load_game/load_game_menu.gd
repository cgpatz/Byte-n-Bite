extends Control
## Save-slot picker. Emits slot_chosen when the player loads a slot.

signal slot_chosen(slot: int)
signal closed

const PixelArt := preload("res://scenes/art/pixel_art.gd")

## Optional note shown above the slots (e.g. "All slots are full").
var message := ""

@onready var message_label: Label = %Message
@onready var slots_box: VBoxContainer = %Slots
@onready var back_button: Button = %BackButton


func _ready() -> void:
	message_label.text = message
	message_label.visible = message != ""
	back_button.pressed.connect(close)
	_build_slots()


func _build_slots() -> void:
	for child in slots_box.get_children():
		child.queue_free()

	var first_focus: Control = null
	for i in SaveManager.SLOT_COUNT:
		var meta: Dictionary = SaveManager.read_meta(i)
		var row := _make_slot_row(i, meta)
		slots_box.add_child(row)
		if first_focus == null:
			var load_btn: Button = row.get_node("HBox/LoadButton")
			if not load_btn.disabled:
				first_focus = load_btn
	(first_focus if first_focus else back_button).grab_focus.call_deferred()


func _make_slot_row(slot: int, meta: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.theme_type_variation = &"WoodPlank"

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 26)
	if meta.is_empty():
		info.text = "Slot %d  —  Empty" % (slot + 1)
		info.modulate = Color(1, 1, 1, 0.6)
	else:
		var saved := Time.get_datetime_string_from_unix_time(int(meta.get("saved_at", 0)), true)
		var title := str(meta.get("game_name", ""))
		if title == "":
			title = "Slot %d" % (slot + 1)
		info.text = "%s  —  Manager %s\nRestaurant Lv %d  ·  Manager Lv %d  ·  %d coins  ·  %s" % [
			title,
			str(meta.get("manager_name", "")),
			int(meta.get("restaurant_level", 1)),
			int(meta.get("player_level", 1)),
			int(meta.get("money", 0)),
			saved,
		]
	hbox.add_child(info)

	var load_btn := Button.new()
	load_btn.name = "LoadButton"
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(190, 80)
	PixelArt.button_icon(load_btn, ["start_light", "start"])
	load_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	load_btn.add_theme_font_size_override("font_size", 26)
	load_btn.disabled = meta.is_empty()
	load_btn.pressed.connect(_on_load_pressed.bind(slot))
	hbox.add_child(load_btn)

	var delete_btn := Button.new()
	delete_btn.name = "DeleteButton"
	delete_btn.text = "Delete"
	delete_btn.custom_minimum_size = Vector2(170, 80)
	delete_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	delete_btn.add_theme_font_size_override("font_size", 26)
	delete_btn.disabled = meta.is_empty()
	delete_btn.pressed.connect(_on_delete_pressed.bind(slot, delete_btn))
	hbox.add_child(delete_btn)

	return row


func _on_load_pressed(slot: int) -> void:
	slot_chosen.emit(slot)


## Two-step delete: first press asks, second press deletes.
func _on_delete_pressed(slot: int, button: Button) -> void:
	if button.text != "Sure?":
		button.text = "Sure?"
		return
	SaveManager.delete_slot(slot)
	message = ""
	message_label.visible = false
	_build_slots()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()

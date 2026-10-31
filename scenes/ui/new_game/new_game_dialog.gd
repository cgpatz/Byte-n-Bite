extends Control
## New Game: asks for the game name (used for the save slot / Load Game list)
## and the player's name (the manager's name in the restaurant).

signal confirmed(game_name: String, manager_name: String, new_to_c: bool)
signal closed

const MAX_LEN := 20

@onready var game_name_edit: LineEdit = %GameNameEdit
@onready var manager_name_edit: LineEdit = %ManagerNameEdit
@onready var error_label: Label = %ErrorLabel
@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	for e: LineEdit in [game_name_edit, manager_name_edit]:
		e.max_length = MAX_LEN
		e.text_changed.connect(func(_t): error_label.text = "")
	game_name_edit.text_submitted.connect(func(_t): manager_name_edit.grab_focus())
	manager_name_edit.text_submitted.connect(func(_t): _on_start_pressed())
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(close)
	error_label.text = ""
	_build_experience_choice()
	game_name_edit.grab_focus.call_deferred()


## "Are you new to C?" Beginners get Chef Miso's full step-by-step tour; players
## who know some C get a short tour (the C quests stay in the Quest Log).
var _new_to_c: CheckBox


func _build_experience_choice() -> void:
	_new_to_c = CheckBox.new()
	_new_to_c.text = "I'm new to C programming (full step-by-step tour)"
	_new_to_c.button_pressed = true
	_new_to_c.add_theme_font_size_override("font_size", 20)
	_new_to_c.tooltip_text = "Untick if you already know some C: Chef Miso gives a short tour instead."
	var box: Control = error_label.get_parent()
	box.add_child(_new_to_c)
	box.move_child(_new_to_c, error_label.get_index())


func _on_start_pressed() -> void:
	var game_name := game_name_edit.text.strip_edges()
	var manager := manager_name_edit.text.strip_edges()
	if game_name == "":
		error_label.text = "Please enter a name for your game."
		game_name_edit.grab_focus()
		return
	if manager == "":
		error_label.text = "Please enter your name."
		manager_name_edit.grab_focus()
		return
	confirmed.emit(game_name, manager, _new_to_c.button_pressed)
	queue_free()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

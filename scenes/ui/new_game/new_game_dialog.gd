extends Control
## New Game: asks for the game name (used for the save slot / Load Game list)
## and the player's name (the manager's name in the restaurant).

signal confirmed(game_name: String, manager_name: String)
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
	game_name_edit.grab_focus.call_deferred()


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
	confirmed.emit(game_name, manager)
	queue_free()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

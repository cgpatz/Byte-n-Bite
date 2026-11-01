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


## "Have you coded in C before?" Two big choices instead of a small checkbox,
## so nobody misses it. Beginners get Chef Miso's full step-by-step tour;
## players who know some C get a short tour (the C quests stay in the Quest Log).
var _new_to_c := true
var _exp_buttons: Array[Button] = []
var _exp_hint: Label

const EXP_CHOICES := [
	["I'm new to C", "Chef Miso teaches you step by step: a guided tour, then small coding quests.", true],
	["I know some C", "A quick tour only. Chef Miso's C quests wait in your Quest Log (G).", false],
]


func _build_experience_choice() -> void:
	var box: Control = error_label.get_parent()
	var title := Label.new()
	title.text = "Have you coded in C before?"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	box.move_child(title, error_label.get_index())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	box.move_child(row, error_label.get_index())
	var group := ButtonGroup.new()
	for c in EXP_CHOICES:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24)
		b.set_meta("label", c[0])
		b.button_pressed = c[2] == _new_to_c
		b.toggled.connect(func(on: bool):
			if on:
				_new_to_c = c[2]
				_refresh_experience())
		row.add_child(b)
		_exp_buttons.append(b)
	_exp_hint = Label.new()
	_exp_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_exp_hint.custom_minimum_size = Vector2(520, 0)
	_exp_hint.add_theme_font_size_override("font_size", 20)
	_exp_hint.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	box.add_child(_exp_hint)
	box.move_child(_exp_hint, error_label.get_index())
	_refresh_experience()


func _refresh_experience() -> void:
	for i in _exp_buttons.size():
		var b := _exp_buttons[i]
		var on: bool = EXP_CHOICES[i][2] == _new_to_c
		b.text = ("✔ " if on else "") + String(b.get_meta("label"))
		b.theme_type_variation = &"StartButton" if on else &""
		if on:
			_exp_hint.text = EXP_CHOICES[i][1]


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
	confirmed.emit(game_name, manager, _new_to_c)
	queue_free()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

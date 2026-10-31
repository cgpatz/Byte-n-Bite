extends Control
## Pause overlay. Pauses the game tree while open.

signal closed

const SETTINGS_SCENE := preload("res://scenes/ui/settings/Settings.tscn")
const MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const PixelArt := preload("res://scenes/art/pixel_art.gd")

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var main_menu_button: Button = %MainMenuButton

var _settings_open := false


func _ready() -> void:
	get_tree().paused = true
	PixelArt.button_icon(resume_button, ["start_dark", "start"])
	PixelArt.button_icon(settings_button, ["settings"])
	PixelArt.button_icon(main_menu_button, ["exit"])
	resume_button.pressed.connect(close)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	resume_button.grab_focus()
	_add_replay_button()


## "Replay tutorial": closes the menu and plays Chef Miso's tour of this level.
func _add_replay_button() -> void:
	var game := get_tree().get_first_node_in_group("game_root")
	if game == null or not game.has_method("replay_tutorial"):
		return
	var b := Button.new()
	b.text = "Replay tutorial"
	b.custom_minimum_size = settings_button.custom_minimum_size
	b.theme_type_variation = settings_button.theme_type_variation
	settings_button.add_sibling(b)
	PixelArt.button_icon(b, ["start_dark", "start"])
	b.pressed.connect(func():
		close()
		game.replay_tutorial())


func _on_settings_pressed() -> void:
	var s := SETTINGS_SCENE.instantiate()
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(s)
	_settings_open = true
	s.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	_settings_open = false
	resume_button.grab_focus()


func _on_main_menu_pressed() -> void:
	GameState.save_now()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if not _settings_open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

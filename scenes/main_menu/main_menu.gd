extends Control
## Main menu for Byte n' Bite.
## Art is optional: drop files at the paths below and they're picked up
## automatically, or assign textures directly in the Inspector.

const BACKGROUND_PATH := "res://assets/backgrounds/main_menu_bg_v8.png"
## "Code Corner" background: 8 frames (4 × 2 sheet, 480×270 each), looped.
const BG_SHEET_PATH := "res://assets/backgrounds/main_menu_bg_v8_sheet.png"
const BG_SHEET_GRID := Vector2i(4, 2)
const BG_FRAME_TIME := 0.22
const PixelArt := preload("res://scenes/art/pixel_art.gd")
const LOGO_PATH := "res://assets/ui/logo/logo.png"  # logo + "Cook. Code. Create." in one image
const ICON_DIR := "res://assets/ui/icons/"

const SETTINGS_SCENE := preload("res://scenes/ui/settings/Settings.tscn")
const LOAD_GAME_SCENE := preload("res://scenes/ui/load_game/LoadGame.tscn")
const NEW_GAME_SCENE := preload("res://scenes/ui/new_game/NewGame.tscn")

## Gameplay scene (it loads the restaurant layout inside it).
@export_file("*.tscn") var game_scene := "res://scenes/game/Game.tscn"

@onready var background: TextureRect = $Background
@onready var logo: TextureRect = $MenuColumn/Logo
@onready var logo_placeholder: Label = get_node_or_null("MenuColumn/Logo/LogoPlaceholder")
## Optional: delete the VersionLabel node if you don't want it on screen.
@onready var version_label: Label = get_node_or_null("VersionLabel")
@onready var start_button: Button = $MenuColumn/Buttons/StartButton
@onready var new_game_button: Button = $MenuColumn/Buttons/NewGameButton
@onready var load_game_button: Button = $MenuColumn/Buttons/LoadGameButton
@onready var settings_button: Button = $MenuColumn/Buttons/SettingsButton
@onready var exit_button: Button = $MenuColumn/Buttons/ExitButton
@onready var admin_run_button: Button = $AdminRunButton


func _ready() -> void:
	_load_optional_art()

	var version := str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	if version_label:
		version_label.text = "v%s\nA Gamified Learning Experience" % version

	start_button.pressed.connect(_on_start_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	exit_button.visible = not OS.has_feature("web")  # a browser tab is closed by the player

	# Admin Run only exists when playing from the Godot editor (debug builds).
	admin_run_button.visible = OS.is_debug_build()
	admin_run_button.pressed.connect(_on_admin_run_pressed)

	for button: Button in [start_button, new_game_button, load_game_button, settings_button, exit_button]:
		_add_hover_bounce(button)

	_refresh_buttons()


func _refresh_buttons() -> void:
	load_game_button.disabled = not SaveManager.has_any_save()
	start_button.grab_focus()  # keyboard / controller navigation


func _load_optional_art() -> void:
	if background.texture == null and ResourceLoader.exists(BACKGROUND_PATH):
		background.texture = load(BACKGROUND_PATH)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel art
	_start_background_animation()
	if logo.texture == null and ResourceLoader.exists(LOGO_PATH):
		logo.texture = load(LOGO_PATH)
	if logo_placeholder:
		logo_placeholder.visible = logo.texture == null

	# Icons: start.png, new_game.png, load_game.png, settings.png, exit.png
	var icons := {
		start_button: "start", new_game_button: "new_game",
		load_game_button: "load_game", settings_button: "settings", exit_button: "exit",
	}
	# Burger on the right end of the Start plank.
	var burger_path := ICON_DIR + "burger.png"
	if ResourceLoader.exists(burger_path) and start_button.get_node_or_null("Burger") == null:
		var burger := TextureRect.new()
		burger.name = "Burger"
		burger.texture = load(burger_path)
		burger.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz: Vector2 = burger.texture.get_size()
		burger.anchor_left = 1.0
		burger.anchor_right = 1.0
		burger.anchor_top = 0.5
		burger.anchor_bottom = 0.5
		burger.offset_left = -sz.x - 28.0
		burger.offset_right = -28.0
		burger.offset_top = -sz.y / 2.0 - 4.0
		burger.offset_bottom = sz.y / 2.0 - 4.0
		start_button.add_child(burger)
	for button: Button in icons:
		if button.icon == null:
			# The gold Start plank uses the dark play icon.
			var keys: Array = ["start_dark", "start"] if button == start_button else [icons[button]]
			PixelArt.button_icon(button, keys)


# --- Animated background (sprite sheet) --------------------------------------

var _bg_atlas: AtlasTexture
var _bg_frame := 0
var _bg_time := 0.0


func _start_background_animation() -> void:
	if not ResourceLoader.exists(BG_SHEET_PATH):
		return
	var sheet: Texture2D = load(BG_SHEET_PATH)
	_bg_atlas = AtlasTexture.new()
	_bg_atlas.atlas = sheet
	_bg_atlas.region = Rect2(Vector2.ZERO, sheet.get_size() / Vector2(BG_SHEET_GRID))
	background.texture = _bg_atlas


func _process(delta: float) -> void:
	if _bg_atlas == null:
		return
	_bg_time += delta
	if _bg_time < BG_FRAME_TIME:
		return
	_bg_time -= BG_FRAME_TIME
	_bg_frame = (_bg_frame + 1) % (BG_SHEET_GRID.x * BG_SHEET_GRID.y)
	var fs: Vector2 = _bg_atlas.region.size
	_bg_atlas.region.position = Vector2(_bg_frame % BG_SHEET_GRID.x, _bg_frame / BG_SHEET_GRID.x) * fs


func _add_hover_bounce(button: Button) -> void:
	button.resized.connect(func(): button.pivot_offset = button.size / 2.0)
	button.mouse_entered.connect(_tween_scale.bind(button, 1.05))
	button.mouse_exited.connect(_tween_scale.bind(button, 1.0))
	button.focus_entered.connect(_tween_scale.bind(button, 1.05))
	button.focus_exited.connect(_tween_scale.bind(button, 1.0))


func _tween_scale(button: Button, target: float) -> void:
	if button.disabled and target > 1.0:
		return
	create_tween().tween_property(button, "scale", Vector2.ONE * target, 0.08)


# --- Overlays ---------------------------------------------------------------

func _open_overlay(overlay: Control) -> void:
	add_child(overlay)
	overlay.closed.connect(_refresh_buttons)


func _open_load_game(message := "") -> void:
	var menu := LOAD_GAME_SCENE.instantiate()
	menu.message = message
	menu.slot_chosen.connect(_enter_game)
	_open_overlay(menu)


# --- Buttons ----------------------------------------------------------------

## Start = continue the most recent save, or begin a new game if there is none.
func _on_start_pressed() -> void:
	var slot: int = SaveManager.most_recent_slot()
	if slot == -1:
		_on_new_game_pressed()
	else:
		_enter_game(slot)


func _on_new_game_pressed() -> void:
	var slot: int = SaveManager.first_empty_slot()
	if slot == -1:
		# Never overwrite a valid save silently (NFR-03).
		_open_load_game("All save slots are full. Delete one to start a new game.")
		return
	# Ask for the game name and the player's (manager's) name first.
	var dialog := NEW_GAME_SCENE.instantiate()
	dialog.confirmed.connect(_start_new_game.bind(slot))
	_open_overlay(dialog)


func _start_new_game(game_name: String, manager_name: String, new_to_c: bool, slot: int) -> void:
	GameState.reset()
	GameState.admin_mode = false
	GameState.short_tour = not new_to_c
	GameState.game_name = game_name
	GameState.manager_name = manager_name
	SaveManager.current_slot = slot
	GameState.save_now()  # the slot now shows this game on the Load Game screen
	_enter_game(slot)


## Test run: no save slot, admin panel enabled (F10 in game).
func _on_admin_run_pressed() -> void:
	GameState.reset()
	GameState.game_name = "Admin Test"
	GameState.manager_name = "Manager"
	GameState.admin_mode = true
	SaveManager.current_slot = -1
	get_tree().change_scene_to_file(game_scene)


func _on_load_game_pressed() -> void:
	_open_load_game()


func _on_settings_pressed() -> void:
	_open_overlay(SETTINGS_SCENE.instantiate())


func _on_exit_pressed() -> void:
	get_tree().quit()


func _enter_game(slot: int, is_new := false) -> void:
	SaveManager.current_slot = slot
	if not ResourceLoader.exists(game_scene):
		push_warning("Restaurant scene not made yet (%s). Slot %d, new game: %s" % [game_scene, slot + 1, is_new])
		return
	GameState.admin_mode = false
	if is_new:
		GameState.reset()
	elif SaveManager.has_save(slot):
		GameState.from_save(SaveManager.load_state(slot))
	get_tree().change_scene_to_file(game_scene)

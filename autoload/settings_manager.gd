extends Node
## Stores player settings in user://settings.cfg and applies them on startup.

signal changed

const PATH := "user://settings.cfg"

var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := false
var code_font_size := 16  # code editor font size (Settings)
## Where the floating code window was left (position + size). Empty = default.
var code_window := Rect2()
## Floating windows (Lessons, Recipe Book, Library, Stats): name -> [x, y, scale].
var windows := {}
## Goals & Challenges list on the HUD: open or closed.
var goals_open := true


const MUSIC_PLAYER := preload("res://autoload/music_player.gd")


func _ready() -> void:
	load_settings()
	apply()
	# Background music lives here so it plays in every scene.
	var music := MUSIC_PLAYER.new()
	music.name = "Music"
	add_child(music)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	code_font_size = cfg.get_value("editor", "code_font_size", code_font_size)
	code_window = cfg.get_value("editor", "code_window", code_window)
	windows = cfg.get_value("editor", "windows", windows)
	goals_open = cfg.get_value("editor", "goals_open", goals_open)
	# Compact UI (v2): smaller code editor and windows. Old saved sizes and the
	# old default code font size are reset once.
	if not cfg.get_value("editor", "compact_ui", false):
		if code_font_size == 20:
			code_font_size = 16
		code_window = Rect2()
		windows = {}


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("editor", "code_font_size", code_font_size)
	cfg.set_value("editor", "code_window", code_window)
	cfg.set_value("editor", "windows", windows)
	cfg.set_value("editor", "goals_open", goals_open)
	cfg.set_value("editor", "compact_ui", true)
	cfg.save(PATH)


func apply() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	changed.emit()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)

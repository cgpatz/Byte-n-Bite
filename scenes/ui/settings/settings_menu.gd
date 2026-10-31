extends Control
## Settings overlay. Opened from the main menu (and later the pause menu).
## Changes apply live and are saved when the panel closes.

signal closed

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var code_size_slider: HSlider = %CodeSizeSlider
@onready var code_size_value: Label = %CodeSizeValue
@onready var code_preview: Label = %CodePreview
@onready var back_button: Button = %BackButton


func _ready() -> void:
	var s = SettingsManager
	master_slider.value = s.master_volume
	music_slider.value = s.music_volume
	sfx_slider.value = s.sfx_volume
	fullscreen_check.button_pressed = s.fullscreen
	code_size_slider.value = s.code_font_size
	_update_code_preview()

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	code_size_slider.value_changed.connect(_on_code_size_changed)
	back_button.pressed.connect(close)

	master_slider.grab_focus()


func _on_master_changed(v: float) -> void:
	SettingsManager.master_volume = v
	SettingsManager.apply()


func _on_music_changed(v: float) -> void:
	SettingsManager.music_volume = v
	SettingsManager.apply()


func _on_sfx_changed(v: float) -> void:
	SettingsManager.sfx_volume = v
	SettingsManager.apply()


func _on_fullscreen_toggled(on: bool) -> void:
	SettingsManager.fullscreen = on
	SettingsManager.apply()


func _on_code_size_changed(v: float) -> void:
	SettingsManager.code_font_size = int(v)
	_update_code_preview()


func _update_code_preview() -> void:
	code_size_value.text = str(SettingsManager.code_font_size)
	code_preview.add_theme_font_size_override("font_size", SettingsManager.code_font_size)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	SettingsManager.save_settings()
	closed.emit()
	queue_free()


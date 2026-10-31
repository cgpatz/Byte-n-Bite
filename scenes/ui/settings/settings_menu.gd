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
	_build_opacity_row()
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


## Code Editor Opacity: how see-through the code editor window is (30%-100%).
var _opacity_value: Label


func _build_opacity_row() -> void:
	var grid: GridContainer = code_size_slider.get_parent().get_parent()
	var label := Label.new()
	label.text = "Code Editor Opacity"
	grid.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	grid.add_child(row)
	var slider := HSlider.new()
	slider.name = "CodeOpacitySlider"
	slider.custom_minimum_size = Vector2(300, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0.3
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = SettingsManager.code_opacity
	row.add_child(slider)
	_opacity_value = Label.new()
	_opacity_value.custom_minimum_size = Vector2(56, 0)
	_opacity_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_opacity_value)
	_opacity_value.text = "%d%%" % roundi(SettingsManager.code_opacity * 100)
	slider.value_changed.connect(func(v: float):
		SettingsManager.code_opacity = v
		_opacity_value.text = "%d%%" % roundi(v * 100)
		SettingsManager.changed.emit())
	# Room for the extra row.
	var panel: Control = $Panel
	panel.offset_top -= 30
	panel.offset_bottom += 30

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
		SettingsManager.changed.emit()
		_show_preview())
	# Show the preview while the slider is hovered, dragged or changed.
	slider.mouse_entered.connect(_show_preview)
	slider.focus_entered.connect(_show_preview)
	slider.drag_started.connect(_show_preview)
	_op_slider = slider
	_build_preview()
	# Room for the extra row.
	var panel: Control = $Panel
	panel.offset_top -= 30
	panel.offset_bottom += 30


# --- Code editor preview (for the opacity slider) ---------------------------------

const Art := preload("res://scenes/ui/common/ui_art.gd")
const PANEL_SCRIPT := preload("res://scenes/ui/programming_panel/programming_panel.gd")
const PREVIEW_CODE := "void main() {\n    int dish = EGGSILOG;\n    float price = 30.00;\n    go_to(FRIDGE);\n    pick_up(EGG);\n    printf(\"Here's your %s for %.2f\\n\", dish, price);\n}"

var _preview: PanelContainer
var _preview_boxes: Array[StyleBoxFlat] = []
var _preview_hide_at := 0.0
var _op_slider: HSlider


## A small copy of the code editor beside the Settings panel, drawn at the
## chosen opacity, so players can see how see-through it will be.
func _build_preview() -> void:
	_preview = PanelContainer.new()
	_preview.theme_type_variation = &"WoodPanel"
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.custom_minimum_size = Vector2(480, 0)
	add_child(_preview)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_preview.add_child(v)
	var t := Label.new()
	t.text = "Preview: code editor"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
	v.add_child(t)
	var ce := CodeEdit.new()
	ce.text = PREVIEW_CODE
	ce.editable = false
	ce.custom_minimum_size = Vector2(0, 190)
	ce.gutters_draw_line_numbers = true
	ce.add_theme_font_override("font", Art.mono())
	ce.add_theme_font_size_override("font_size", 15)
	ce.add_theme_color_override("font_readonly_color", Color(0.92, 0.9, 0.85))
	ce.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	ce.add_theme_color_override("current_line_color", Color(0, 0, 0, 0))
	ce.syntax_highlighter = Art.c_highlighter(PANEL_SCRIPT.C_KEYWORDS, PANEL_SCRIPT.C_UNSUPPORTED)
	ce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _code_box()
	ce.add_theme_stylebox_override("normal", sb)
	ce.add_theme_stylebox_override("read_only", sb)
	v.add_child(ce)
	var out_l := Label.new()
	out_l.text = "Output"
	out_l.add_theme_font_size_override("font_size", 15)
	v.add_child(out_l)
	var out := Label.new()
	out.text = "Here's your EGGSILOG for 30.00"
	out.add_theme_font_size_override("font_size", 14)
	out.add_theme_color_override("font_color", Color(0.75, 0.9, 0.65))
	out.add_theme_stylebox_override("normal", _code_box())
	v.add_child(out)
	_preview.modulate.a = 0.0
	_preview.hide()


func _code_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.07)
	sb.border_color = Color(0.4, 0.25, 0.14)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_preview_boxes.append(sb)
	return sb


func _show_preview() -> void:
	if _preview == null:
		return
	var o := clampf(SettingsManager.code_opacity, 0.3, 1.0)
	_preview.self_modulate.a = o
	for sb in _preview_boxes:
		sb.bg_color.a = o
	var panel: Control = $Panel
	_preview.reset_size()
	var vs := get_viewport_rect().size
	var x := panel.global_position.x + panel.size.x + 24.0
	if x + _preview.size.x > vs.x - 12.0:
		x = maxf(12.0, panel.global_position.x - _preview.size.x - 24.0)
	_preview.global_position = Vector2(x, panel.global_position.y + panel.size.y - _preview.size.y - 40.0)
	_preview.show()
	_preview.modulate.a = 1.0
	$Dim.modulate.a = 0.35  # lighten the dim so the scene behind shows through
	_preview_hide_at = Time.get_ticks_msec() + 2500


func _process(_delta: float) -> void:
	if _op_slider and _preview and _preview.visible and (_op_slider.has_focus() or _op_slider.get_global_rect().has_point(get_global_mouse_position())):
		_preview_hide_at = Time.get_ticks_msec() + 1500
	if _preview and _preview.visible and Time.get_ticks_msec() > _preview_hide_at:
		_preview.modulate.a = maxf(0.0, _preview.modulate.a - 0.08)
		if _preview.modulate.a <= 0.0:
			_preview.hide()
			$Dim.modulate.a = 1.0

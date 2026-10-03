extends Control
## Shared base for in-game windows (Stats, Recipe Book, Library): a dimmed
## background, a centred wood panel with a title and a Close button.
## Subclasses fill `content` in _build() and refresh it in _refresh().

signal closed

@export var title := "Window"
@export var window_size := Vector2(1100, 820)

var content: VBoxContainer
var close_button: Button


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WoodPanel"
	panel.custom_minimum_size = window_size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -window_size.x / 2.0
	panel.offset_right = window_size.x / 2.0
	panel.offset_top = -window_size.y / 2.0
	panel.offset_bottom = window_size.y / 2.0
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"HeaderLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(200, 64)
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	box.add_child(content)
	_build()


func open() -> void:
	_refresh()
	show()
	close_button.grab_focus()


func close() -> void:
	_on_close()
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Override: create the window's controls inside `content`.
func _build() -> void:
	pass


## Override: update the controls each time the window opens.
func _refresh() -> void:
	pass


## Override: runs just before the window closes.
func _on_close() -> void:
	pass


# --- Small helpers for subclasses ----------------------------------------------------

func make_label(text: String, size := 22, color := Color(1, 0.93, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func make_rich(min_height := 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = true
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(0, min_height)
	r.add_theme_font_size_override("normal_font_size", 22)
	r.add_theme_font_size_override("bold_font_size", 22)
	r.add_theme_font_size_override("mono_font_size", 20)
	r.add_theme_color_override("default_color", Color(1, 0.93, 0.8))
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
	r.add_theme_font_override("mono_font", mono)
	return r

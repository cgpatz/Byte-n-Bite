extends "res://scenes/ui/common/art_window.gd"
## Library (L): the player's own C functions, kept in named slots (separate
## sets of code). Every slot that is switched on can be called from every staff
## member's program, like your own #include. Saved with the game
## (GameState.library_slots).
## Art: assets/ui/windows/library/ (board, title_paper, note_paper, editor_frame,
## chalk_tray, error_strip, pins) + assets/ui/buttons/button_small(_gold).png.

const CInterpreter := preload("res://systems/c_interpreter/c_interpreter.gd")
const PANEL_SCRIPT := preload("res://scenes/ui/programming_panel/programming_panel.gd")
const ERROR_COLOR := Color(0.55, 0.12, 0.1, 0.75)
## Editor frame: border + line-number strip, in screen px (art px × 4).
const GUTTER_PX := 76

var _slot_buttons: Array[Button] = []
var _name_edit: LineEdit
var _enabled: CheckBox
var _code: CodeEdit
var _status: RichTextLabel
var _strip: NinePatchRect
var _clear_button: Button
var _spacer_gutter := -1
var _error_line := -1
var _slot := 0
var _loading := false


func _build() -> void:
	window_rect = Rect2(184, 36, 1552, 1008)
	Art.panel(frame, "library/board.png", Rect2(184, 36, 1552, 1008), [6, 6, 6, 6], true)
	add_title_card("library/title_paper.png", "My Library", Vector2(224, 72))
	add_close_button(Vector2(1532, 76))

	# Note with the instructions.
	Art.panel(frame, "library/note_paper.png", Rect2(224, 180, 1472, 96), [2, 2, 4, 4])
	Art.image(frame, "library/pin_red.png", Vector2(950, 170))
	Art.label(frame, "Write a function once, then call it from every staff member's program.", Vector2(248, 192), 22, Art.INK)
	Art.label(frame, "Keep different sets of code in the 6 slots below. Only slots with \"Use in staff programs\" ticked are shared with your staff.",
		Vector2(248, 228), 18, Art.INK_SOFT)

	# Slot tabs.
	var w := (1472.0 - 5 * 16) / 6.0
	for i in GameState.LIBRARY_SLOTS:
		var b := Art.button(frame, "", Rect2(224 + i * (w + 16), 292, w, 60), false, 21)
		b.pressed.connect(_select_slot.bind(i))
		_slot_buttons.append(b)

	# Code editor on the chalkboard frame.
	Art.panel(frame, "library/editor_frame.png", Rect2(224, 364, 1472, 376), [20, 4, 4, 4])
	_code = CodeEdit.new()
	_code.position = Vector2(224 + 16, 364 + 16)
	_code.size = Vector2(1472 - 32, 376 - 32)
	_code.clip_contents = true
	_style_editor(_code)
	_code.text_changed.connect(_on_code_changed)
	frame.add_child(_code)
	Art.image(frame, "library/chalk_tray.png", Vector2(240, 740))

	# Slot name, on/off switch, clear.
	Art.label(frame, "Slot name", Vector2(228, 788), 22, Art.CREAM, true)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 24
	_name_edit.position = Vector2(370, 780)
	_name_edit.size = Vector2(420, 56)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.add_theme_color_override("font_color", Art.INK)
	_name_edit.add_theme_color_override("caret_color", Art.INK)
	var paper := Art.style("library/note_paper.png", [2, 2, 4, 4], Vector4(14, 6, 18, 10))
	_name_edit.add_theme_stylebox_override("normal", paper)
	_name_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_name_edit.text_changed.connect(_on_name_changed)
	frame.add_child(_name_edit)
	_enabled = CheckBox.new()
	_enabled.text = "Use in staff programs"
	_enabled.position = Vector2(820, 784)
	_enabled.add_theme_font_size_override("font_size", 22)
	_enabled.add_theme_color_override("font_color", Art.CREAM)
	_enabled.toggled.connect(_on_enabled_toggled)
	frame.add_child(_enabled)
	_clear_button = Art.button(frame, "Clear slot", Rect2(1496, 776, 200, 64), false, 22)
	_clear_button.pressed.connect(_clear_slot.bind(_clear_button))

	# Message strip (red for errors).
	_strip = Art.panel(frame, "library/error_strip.png", Rect2(224, 852, 1472, 52), [16, 3, 3, 3])
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.scroll_active = false
	_status.position = Vector2(288, 860)
	_status.size = Vector2(1400, 40)
	_status.add_theme_font_size_override("normal_font_size", 21)
	_status.add_theme_font_size_override("bold_font_size", 21)
	_status.add_theme_font_override("bold_font", Art.bold_font())
	_status.add_theme_color_override("default_color", Art.CREAM)
	frame.add_child(_status)

	var check := Art.button(frame, "Check", Rect2(700, 924, 232, 68), false, 30)
	check.pressed.connect(_check)
	var save := Art.button(frame, "Save", Rect2(988, 924, 232, 68), true, 30)
	save.pressed.connect(_save)


## Pushes the code past the line-number strip drawn on the editor frame.
func _process(_delta: float) -> void:
	if not visible or _code == null:
		return
	if _spacer_gutter < 0:
		_code.add_gutter()
		_spacer_gutter = _code.get_gutter_count() - 1
		_code.set_gutter_type(_spacer_gutter, TextEdit.GUTTER_TYPE_STRING)
	var used := 0
	for g in _code.get_gutter_count():
		if g != _spacer_gutter and _code.is_gutter_drawn(g):
			used += _code.get_gutter_width(g)
	var want := maxi(4, GUTTER_PX - 16 - 6 - used + 14)
	if _code.get_gutter_width(_spacer_gutter) != want:
		_code.set_gutter_width(_spacer_gutter, want)


## Shows a message under the editor; errors get the red strip.
func _set_status(bbcode: String, is_error: bool) -> void:
	_status.text = bbcode
	_strip.visible = is_error
	_status.position.x = 288 if is_error else 232


func _refresh() -> void:
	_select_slot(clampi(_slot, 0, GameState.library_slots.size() - 1))


func open() -> void:
	super.open()
	_code.grab_focus()


func _on_close() -> void:
	_store_current()


# --- Slots ----------------------------------------------------------------------------

func _fill_slot_list() -> void:
	for i in GameState.library_slots.size():
		if i >= _slot_buttons.size():
			break
		var s: Dictionary = GameState.library_slots[i]
		var empty := str(s.code).strip_edges() == ""
		var b := _slot_buttons[i]
		if empty:
			b.text = "%d · empty" % (i + 1)
		else:
			b.text = "%d · %s%s" % [i + 1, s.name, " (off)" if not s.enabled else ""]
		b.tooltip_text = "%s: %s" % [s.name, "empty" if empty else ", ".join(_function_names(s.code))]
		Art.set_button_look(b, i == _slot, 21)
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var st: StyleBox = b.get_theme_stylebox(k)
			st.content_margin_left = 30
			st.content_margin_right = 30
		if i != _slot and (empty or not s.enabled):
			b.add_theme_color_override("font_color", Color(0.72, 0.62, 0.5))


func _select_slot(index: int) -> void:
	if index != _slot:
		_store_current()
	_slot = index
	var s: Dictionary = GameState.library_slots[index]
	_loading = true
	_name_edit.text = s.name
	_enabled.button_pressed = s.enabled
	_code.text = s.code
	_loading = false
	_fill_slot_list()
	_check()


## Copies the editor into the selected slot.
func _store_current() -> void:
	if _slot < GameState.library_slots.size():
		var s: Dictionary = GameState.library_slots[_slot]
		s.code = _code.text
		s.name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Slot %d" % (_slot + 1)
		s.enabled = _enabled.button_pressed


func _update_list_row() -> void:
	_store_current()
	_fill_slot_list()


func _on_name_changed(_t: String) -> void:
	if not _loading:
		_update_list_row()


func _on_enabled_toggled(_on: bool) -> void:
	if not _loading:
		_update_list_row()
		_check()


func _on_code_changed() -> void:
	_clear_error()


## Two-step clear: first press asks, second press empties the slot.
func _clear_slot(button: Button) -> void:
	if button.text != "Sure?":
		button.text = "Sure?"
		get_tree().create_timer(2.0).timeout.connect(func(): button.text = "Clear slot")
		return
	button.text = "Clear slot"
	_loading = true
	_code.text = ""
	_name_edit.text = "Slot %d" % (_slot + 1)
	_loading = false
	_update_list_row()
	_check()


func _save() -> void:
	_store_current()
	_fill_slot_list()
	if _check():
		_set_status("[color=#9fd67a][b]Saved.[/b][/color] Staff use the new Library the next time you press Run.", false)
	GameState.save_now()


## Checks the selected slot, and that switched-on slots don't clash. True when fine.
func _check() -> bool:
	_clear_error()
	var interp := CInterpreter.new()
	var err := interp.check_library(_code.text)
	if err.is_empty():
		_store_current()
		var probe := CInterpreter.new()
		if not probe.compile("void main() { }", GameState.library_slots):
			var info := CInterpreter.library_line_info(int(probe.error.line))
			_set_status("[b]%s[/b]" % String(probe.error.msg).replace("[", "[lb]"), true)
			if info.slot == _slot:
				_mark_line(info.line)
			return false
	if not err.is_empty():
		_set_status("[b]Line %d: %s[/b]" % [err.line, String(err.msg).replace("[", "[lb]")], true)
		_mark_line(err.line)
		return false
	var names := _function_names(_code.text)
	if names.is_empty():
		_set_status("[color=#d9c4a3]This slot is empty. Write a function like:  void my_step() { ... }[/color]", false)
	elif not _enabled.button_pressed:
		_set_status("[color=#d9c4a3]OK, but this slot is switched off, so staff can't use: %s[/color]" % ", ".join(names), false)
	else:
		_set_status("[color=#9fd67a][b]Slot OK.[/b][/color] Functions your staff can call: [b]%s[/b]" % ", ".join(names), false)
	return true


func _mark_line(line: int) -> void:
	if line - 1 >= 0 and line - 1 < _code.get_line_count():
		_code.set_line_background_color(line - 1, ERROR_COLOR)
		_error_line = line - 1


func _function_names(code: String) -> Array:
	var interp := CInterpreter.new()
	var lib := interp._parse(code, 0)
	var out: Array = []
	for f in lib.functions:
		out.append(f + "()")
	return out


func _clear_error() -> void:
	if _error_line >= 0 and _error_line < _code.get_line_count():
		_code.set_line_background_color(_error_line, Color(0, 0, 0, 0))
	_error_line = -1


func _style_editor(ce: CodeEdit) -> void:
	ce.add_theme_font_override("font", Art.mono())
	ce.add_theme_font_size_override("font_size", SettingsManager.code_font_size)
	ce.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	ce.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	ce.add_theme_color_override("current_line_color", Color(1, 1, 1, 0.05))
	ce.add_theme_color_override("line_number_color", Color(0.45, 0.43, 0.5))
	ce.add_theme_constant_override("line_spacing", 8)
	var box := StyleBoxEmpty.new()
	box.content_margin_left = 6
	box.content_margin_top = 6
	ce.add_theme_stylebox_override("normal", box)
	ce.add_theme_stylebox_override("focus", box)
	ce.gutters_draw_line_numbers = true
	ce.highlight_current_line = true
	ce.indent_automatic = true
	ce.auto_brace_completion_enabled = true
	ce.indent_size = 4
	ce.indent_use_spaces = true
	ce.syntax_highlighter = Art.c_highlighter(PANEL_SCRIPT.C_KEYWORDS, PANEL_SCRIPT.C_UNSUPPORTED)

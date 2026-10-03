extends "res://scenes/ui/common/art_window.gd"
## Admin Runs only: every ready-to-copy code set for the game (best program per
## level, lesson practice solutions, Library functions, one program per dish).
## Copy puts the code on the clipboard; "Give to staff" loads it into every
## staff member's editor (or one chosen staff member); "Put in Library" stores a Library function in the last
## Library slot. Content: data/help/code_sets.gd.

const CodeSets := preload("res://data/help/code_sets.gd")
const PANEL_SCRIPT := preload("res://scenes/ui/programming_panel/programming_panel.gd")

## Set by Game so "Give to staff" can reach the staff.
var game: Node
var _sets: Array = []
var _index := 0
var _list: VBoxContainer
var _buttons: Array[Button] = []
var _title: Label
var _note: Label
var _code: CodeEdit
var _status: Label
var _copy: Button
var _give: Button
var _lib: Button
## Who "Give to" loads the program into: all staff, or one by name.
var _who: OptionButton


func _build() -> void:
	_sets = CodeSets.all_sets()
	Art.panel(frame, "library/board.png", Rect2(152, 40, 1616, 1000), [6, 6, 6, 6], true)
	add_title_card("library/title_paper.png", "Code Sets", Vector2(184, 64))
	Art.label(frame, "Admin · ready to copy", Vector2(700, 96), 24, Color(1, 0.86, 0.52))
	add_close_button(Vector2(1572, 66))

	# Left: grouped list.
	Art.panel(frame, "stats/profile_card.png", Rect2(184, 184, 470, 832), [2, 2, 4, 4])
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(200, 204)
	scroll.size = Vector2(440, 796)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size.x = 400
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	var group := ""
	for i in _sets.size():
		var s: Dictionary = _sets[i]
		if s.group != group:
			group = s.group
			var g := Label.new()
			g.text = group
			g.add_theme_font_override("font", Art.serif())
			g.add_theme_font_size_override("font_size", 24)
			g.add_theme_color_override("font_color", Art.INK)
			_list.add_child(g)
		var b := Button.new()
		b.text = "  %s   (Lv %d)" % [s.title, s.level]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_constant_override("outline_size", 0)
		b.pressed.connect(_select.bind(i))
		_list.add_child(b)
		_buttons.append(b)

	# Right: the selected set.
	Art.panel(frame, "library/note_paper.png", Rect2(690, 184, 1050, 832), [2, 2, 8, 8])
	_title = Art.label(frame, "", Vector2(730, 204), 36, Art.INK, false, 980, HORIZONTAL_ALIGNMENT_LEFT, Art.serif())
	_note = Art.label(frame, "", Vector2(730, 256), 20, Art.INK_SOFT, false, 980)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Art.style("recipe_book/code_card.png", [4, 4, 4, 4], Vector4(22, 16, 18, 22)))
	card.position = Vector2(724, 316)
	card.size = Vector2(984, 580)
	card.clip_contents = true
	frame.add_child(card)
	_code = CodeEdit.new()
	_code.editable = false
	_code.context_menu_enabled = false
	_code.gutters_draw_line_numbers = true
	_code.add_theme_font_override("font", Art.mono())
	_code.add_theme_font_size_override("font_size", 18)
	_code.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	_code.add_theme_color_override("font_readonly_color", Color(0.92, 0.9, 0.85))
	_code.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	_code.add_theme_color_override("current_line_color", Color(0, 0, 0, 0))
	_code.add_theme_color_override("line_number_color", Color(0.6, 0.55, 0.45))
	var empty := StyleBoxEmpty.new()
	for k in ["normal", "read_only", "focus"]:
		_code.add_theme_stylebox_override(k, empty)
	_code.syntax_highlighter = Art.c_highlighter(PANEL_SCRIPT.C_KEYWORDS, PANEL_SCRIPT.C_UNSUPPORTED)
	card.add_child(_code)

	_copy = Art.button(frame, "Copy", Rect2(724, 916, 200, 68), true, 26)
	_copy.pressed.connect(_on_copy)
	_give = Art.button(frame, "Give to", Rect2(940, 916, 260, 68), false, 24)
	_give.pressed.connect(_on_give)
	_lib = Art.button(frame, "Put in Library", Rect2(1216, 916, 260, 68), false, 24)
	_lib.pressed.connect(_on_library)
	_who = OptionButton.new()
	_who.position = Vector2(1216, 922)
	_who.size = Vector2(250, 56)
	_who.add_theme_font_size_override("font_size", 22)
	_who.focus_mode = Control.FOCUS_NONE
	frame.add_child(_who)
	_status = Art.label(frame, "", Vector2(1490, 922), 18, Art.INK_SOFT, false, 230)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _refresh() -> void:
	_who.clear()
	_who.add_item("All staff")
	if game:
		for staff in game._staff_list():
			_who.add_item(staff.staff_name)
	_select(_index)


func _select(i: int) -> void:
	_index = clampi(i, 0, _sets.size() - 1)
	for j in _buttons.size():
		_buttons[j].set_pressed_no_signal(j == _index)
		_buttons[j].modulate = Color(1.35, 1.15, 0.7) if j == _index else Color.WHITE
	var s: Dictionary = _sets[_index]
	_title.text = s.title
	_note.text = s.note
	_code.text = s.code
	_code.scroll_vertical = 0
	_status.text = ""
	_lib.visible = s.group == "Library"
	_give.visible = s.group != "Library"
	_who.visible = _give.visible


func current_code() -> String:
	return _sets[_index].code


func _on_copy() -> void:
	DisplayServer.clipboard_set(current_code())
	_status.text = "Copied! Paste with Ctrl+V."


## Loads the program into the chosen staff member, or everyone (they keep it
## until changed). Waiter + cook sets go to different staff.
func _on_give() -> void:
	var n := 0
	var only := "" if _who.selected <= 0 else _who.get_item_text(_who.selected)
	if game:
		for staff in game._staff_list():
			if only != "" and staff.staff_name != only:
				continue
			staff.program_source = current_code()
			GameState.staff_programs[staff.staff_name] = staff.program_source
			n += 1
	_status.text = "Given to %d staff. Press Run on each." % n if n > 0 else "No staff found."


## Stores the function in the last Library slot.
func _on_library() -> void:
	var slots: Array = GameState.library_slots
	var s: Dictionary = slots[slots.size() - 1]
	s.name = _sets[_index].title.get_slice("(", 0).strip_edges()
	s.code = current_code()
	s.enabled = true
	_status.text = "Saved in Library slot %d." % slots.size()

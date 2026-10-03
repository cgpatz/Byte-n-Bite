extends "res://scenes/ui/common/art_window.gd"
## Lessons (T): Chef Miso's C lessons, one per restaurant level. Opens by itself
## when a new C concept unlocks (new game, restaurant upgrades) and can be
## replayed any time. Content: data/help/lessons.gd (follows the W3Schools C
## Tutorial). Art: library board/papers, stats profile card, recipe-book code
## card, tutorial/mentor.png.

const Lessons := preload("res://data/help/lessons.gd")
const PANEL_SCRIPT := preload("res://scenes/ui/programming_panel/programming_panel.gd")

var _lesson_buttons: Array[Button] = []
var _lesson := 0          # index in Lessons.LESSONS
var _page := 0            # page index; == pages.size() means the practice page
var _title: Label
var _page_label: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _prev: Button
var _next: Button
var _w3: Button
var _copy: Button
var _w3_url := ""


func _build() -> void:
	Art.panel(frame, "library/board.png", Rect2(152, 40, 1616, 1000), [6, 6, 6, 6], true)
	add_title_card("library/title_paper.png", "C Lessons", Vector2(184, 64))
	add_close_button(Vector2(1572, 66))

	# Left: lesson list + Chef Miso.
	Art.panel(frame, "stats/profile_card.png", Rect2(184, 184, 440, 832), [2, 2, 4, 4])
	Art.image(frame, "library/pin_red.png", Vector2(396, 174))
	Art.label(frame, "One lesson per level", Vector2(208, 204), 20, Art.INK_SOFT)
	for i in Lessons.LESSONS.size():
		var b := Button.new()
		b.position = Vector2(204, 244 + i * 88)
		b.size = Vector2(400, 80)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_constant_override("outline_size", 0)
		b.pressed.connect(_show_lesson.bind(i, 0))
		frame.add_child(b)
		_lesson_buttons.append(b)
	var mentor := Art.image(frame, "tutorial/mentor.png", Vector2(306, 708), Vector2(197, 268))
	mentor.texture = load("res://assets/ui/windows/tutorial/mentor.png") if ResourceLoader.exists("res://assets/ui/windows/tutorial/mentor.png") else null

	# Right: the page.
	Art.panel(frame, "library/note_paper.png", Rect2(660, 184, 1080, 832), [2, 2, 8, 8])
	Art.image(frame, "library/pin_blue.png", Vector2(690, 176))
	Art.image(frame, "library/pin_blue.png", Vector2(1700, 176))
	_title = Art.label(frame, "", Vector2(700, 206), 44, Art.INK, false, 860, HORIZONTAL_ALIGNMENT_LEFT, Art.serif())
	_page_label = Art.label(frame, "", Vector2(1480, 222), 20, Art.INK_SOFT, false, 220, HORIZONTAL_ALIGNMENT_RIGHT)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(700, 274)
	_scroll.size = Vector2(1010, 626)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	_scroll.add_child(_body)

	_w3 = Art.button(frame, "Read more on W3Schools", Rect2(700, 924, 330, 64), false, 20)
	_w3.pressed.connect(func(): OS.shell_open(_w3_url))
	_copy = Art.button(frame, "Copy practice code", Rect2(1040, 924, 300, 64), false, 20)
	_copy.pressed.connect(_copy_practice)
	_prev = Art.button(frame, "Back", Rect2(1350, 924, 170, 64), false, 24)
	_prev.pressed.connect(func(): _show_lesson(_lesson, _page - 1))
	_next = Art.button(frame, "Next", Rect2(1530, 924, 190, 64), true, 24)
	_next.pressed.connect(_on_next)


## Opens the lesson for a restaurant level, from its first page.
func open_lesson(level: int) -> void:
	for i in Lessons.LESSONS.size():
		if Lessons.LESSONS[i].level == level:
			_lesson = i
	_page = 0
	open()


func _refresh() -> void:
	if _lesson_unlocked(_lesson) == false:
		_lesson = 0
	_show_lesson(_lesson, _page)


func _lesson_unlocked(i: int) -> bool:
	return Lessons.LESSONS[i].level <= GameState.restaurant_level


func _show_lesson(i: int, page: int) -> void:
	_lesson = i
	var l: Dictionary = Lessons.LESSONS[i]
	var pages: Array = l.pages
	_page = clampi(page, 0, pages.size())
	for j in _lesson_buttons.size():
		var lj: Dictionary = Lessons.LESSONS[j]
		var b := _lesson_buttons[j]
		var open := _lesson_unlocked(j)
		b.text = "Level %d · %s\n%s" % [lj.level, lj.title, lj.concept if open else "Unlocks at Restaurant Level %d" % lj.level]
		b.disabled = not open
		var on := j == i
		var st := Art.style("recipe_book/row_selected.png", [2, 2, 2, 2], Vector4(16, 6, 10, 6)) if on else StyleBoxEmpty.new()
		if not on:
			(st as StyleBoxEmpty).content_margin_left = 16
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(k, st)
		var col := Art.INK if open else Art.INK_LOCKED
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
			b.add_theme_color_override(k, col)
		b.icon = null if open else Art.tex("recipe_book/lock.png")
	for c in _body.get_children():
		c.queue_free()
	var practice := _page >= pages.size()
	if practice:
		_title.text = "Practice: " + l.title
		_page_label.text = "Practice"
		_add_text("[b]Your task[/b]\n" + l.practice.task)
		_add_text("Here is a starting point. Press [b]Copy practice code[/b], open a staff member's program (walk up and press E) and paste it with Ctrl+V. Fill in the missing steps, then press Run.")
		_body.add_child(_code_card(l.practice.code))
		_add_text("[color=#735442]Stuck? The Recipe Book (R) lists every dish's ingredients and explains each kitchen function.[/color]")
		_w3_url = ""
	else:
		var p: Dictionary = pages[_page]
		_title.text = p.title
		_page_label.text = "Page %d of %d" % [_page + 1, pages.size() + 1]
		_add_text(p.text)
		if p.code != "":
			_body.add_child(_code_card(p.code))
		_w3_url = Lessons.W3 + p.w3 if p.get("w3", "") != "" else ""
		_add_text("[color=#8a7a66][font_size=16]Lesson based on the W3Schools C Tutorial (w3schools.com/c).[/font_size][/color]")
	_w3.visible = _w3_url != ""
	_copy.visible = practice
	_prev.disabled = _page == 0
	var last_lesson := i == Lessons.LESSONS.size() - 1 or not _lesson_unlocked(i + 1)
	_next.text = "Got it!" if practice else ("Practice" if _page == pages.size() - 1 else "Next")
	if practice and not last_lesson:
		_next.text = "Next lesson"
	_scroll.scroll_vertical = 0
	if practice and not GameState.tutorials_seen.has(l.level):
		GameState.tutorials_seen.append(l.level)


func _on_next() -> void:
	var pages: Array = Lessons.LESSONS[_lesson].pages
	if _page < pages.size():
		_show_lesson(_lesson, _page + 1)
	elif _lesson + 1 < Lessons.LESSONS.size() and _lesson_unlocked(_lesson + 1):
		_show_lesson(_lesson + 1, 0)
	else:
		close()


func _on_close() -> void:
	var lv: int = Lessons.LESSONS[_lesson].level
	if not GameState.tutorials_seen.has(lv):
		GameState.tutorials_seen.append(lv)


func _copy_practice() -> void:
	DisplayServer.clipboard_set(Lessons.LESSONS[_lesson].practice.code)
	_copy.text = "Copied!"
	get_tree().create_timer(1.5).timeout.connect(func(): _copy.text = "Copy practice code")


func _add_text(bbcode: String) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 22)
	r.add_theme_font_size_override("bold_font_size", 22)
	r.add_theme_font_size_override("mono_font_size", 20)
	r.add_theme_font_override("bold_font", Art.bold_font())
	r.add_theme_font_override("mono_font", Art.mono())
	r.add_theme_color_override("default_color", Art.INK)
	r.add_theme_constant_override("line_separation", 6)
	r.text = bbcode
	_body.add_child(r)


func _code_card(code: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Art.style("recipe_book/code_card.png", [4, 4, 4, 4], Vector4(22, 16, 18, 22)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ce := CodeEdit.new()
	ce.text = code
	ce.editable = false
	ce.context_menu_enabled = false
	ce.scroll_fit_content_height = true
	ce.add_theme_font_override("font", Art.mono())
	ce.add_theme_font_size_override("font_size", 20)
	ce.add_theme_constant_override("line_spacing", 6)
	ce.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	ce.add_theme_color_override("font_readonly_color", Color(0.92, 0.9, 0.85))
	ce.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	ce.add_theme_color_override("current_line_color", Color(0, 0, 0, 0))
	var empty := StyleBoxEmpty.new()
	for k in ["normal", "read_only", "focus"]:
		ce.add_theme_stylebox_override(k, empty)
	ce.syntax_highlighter = Art.c_highlighter(PANEL_SCRIPT.C_KEYWORDS, PANEL_SCRIPT.C_UNSUPPORTED)
	ce.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(ce)
	return card

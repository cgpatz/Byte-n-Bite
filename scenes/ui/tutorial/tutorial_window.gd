extends "res://scenes/ui/common/art_window.gd"
## Lessons (T). Two tabs:
##  Lessons: Chef Miso's C lessons, one per restaurant level. Each page is
##   short and hands-on: Chef Miso explains the idea in a speech bubble, the key
##   points sit on a card, the example can be run right here ("Try it"), and a
##   quick-check question earns a star. Opens by itself when a new C concept
##   unlocks (new game, restaurant upgrades) and can be replayed any time.
##  Kitchen Functions: every C topic and kitchen function with its syntax,
##   explanation, steps and an example (moved here from the Recipe Book).
## Content: data/help/lessons.gd, data/help/quizzes.gd, data/help/c_reference.gd.
## Art: library board/papers, stats profile card, recipe-book code card,
## tutorial/mentor.png.

const Lessons := preload("res://data/help/lessons.gd")
const Quizzes := preload("res://data/help/quizzes.gd")
const Reference := preload("res://data/help/c_reference.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const CInterpreter := preload("res://systems/c_interpreter/c_interpreter.gd")
const PANEL_SCRIPT := preload("res://scenes/ui/programming_panel/programming_panel.gd")
const MENTOR := "res://assets/ui/windows/tutorial/mentor.png"

## Cheerful lines Chef Miso uses to open each page (picked by page number).
const CHEERS := ["Let's go!", "You're doing great!", "This one is fun.", "Almost a pro already!",
	"Ready? Here we go.", "Keep it up, chef!", "Nice pace!", "One more idea for your toolbox."]

enum Mode { LESSONS, FUNCTIONS }

var _mode := Mode.LESSONS
var _mode_tabs: Array[Button] = []
var _lessons_root: Control
var _functions_root: Control

var _lesson_buttons: Array[Button] = []
var _lesson := 0          # index in Lessons.LESSONS
var _page := 0            # page index; == pages.size() means the practice page
var _title: Label
var _page_label: Label
var _progress: Control
var _body: VBoxContainer
var _scroll: ScrollContainer
var _prev: Button
var _next: Button
var _w3: Button
var _copy: Button
var _w3_url := ""
var _run_id := 0          # cancels an older "Try it" run when the page changes
## A lesson page must be finished before Next unlocks: its example run with
## Try it and its quick check answered correctly (when the page has them).
var _need_try := false
var _need_quiz := false
var _gate: Label

# Kitchen Functions
var _entries: Array = []
var _entry_buttons: Array[Button] = []
var _entry_selected := 0
var _help: VBoxContainer
var _help_scroll: ScrollContainer


## Stand-in for a staff member while a lesson example runs inside the window:
## kitchen commands are only described, never performed.
class SandboxHost:
	extends RefCounted
	var staff_name := "Jane"
	var tree: SceneTree
	var held := 0
	var actions := 0
	var said: Callable

	func get_tree() -> SceneTree:
		return tree

	func restaurant_level() -> int:
		return 5

	func run_builtin(name: String, args: Array, _line: int) -> Dictionary:
		actions += 1
		var shown: Array = []
		for a in args:
			var n := str(a)
			if a is int and (Kitchen.is_item(a) or Kitchen.is_dish(a) or (name in ["go_to", "move_to"] and Kitchen.is_station(a))):
				n = Kitchen.name_of(a)
			shown.append(n)
		said.call("[color=#7a9a5a]→ %s: %s(%s)[/color]\n" % [staff_name, name, ", ".join(shown)])
		await tree.create_timer(0.12).timeout
		match name:
			"pick_up":
				held = args[0]
			"holding":
				return {"value": held}
			"trash", "serve":
				held = 0
		return {"value": 0}



func _build() -> void:
	Art.panel(frame, "library/board.png", Rect2(152, 40, 1616, 1000), [6, 6, 6, 6], true)
	add_title_card("library/title_paper.png", "C Lessons", Vector2(184, 64))
	add_close_button(Vector2(1572, 66))
	var tx := 184 + maxf(Art.size_of("library/title_paper.png").x, 300) + 40
	_mode_tabs.append(Art.button(frame, "Lessons", Rect2(tx, 80, 220, 68), true, 26))
	_mode_tabs.append(Art.button(frame, "Kitchen Functions", Rect2(tx + 236, 80, 330, 68), false, 26))
	for i in _mode_tabs.size():
		_mode_tabs[i].pressed.connect(_show_mode.bind(i))
	_lessons_root = _layer()
	_functions_root = _layer()
	_build_lessons()
	_build_functions()
	_show_mode(Mode.LESSONS)


func _layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = DESIGN
	frame.add_child(c)
	return c


func _show_mode(m: int) -> void:
	_mode = m
	_lessons_root.visible = m == Mode.LESSONS
	_functions_root.visible = m == Mode.FUNCTIONS
	for i in _mode_tabs.size():
		Art.set_button_look(_mode_tabs[i], i == m, 26)
	if m == Mode.FUNCTIONS:
		_entries = Reference.entries()
		_fill_entries()
	else:
		_run_id += 1


# --- Lessons ----------------------------------------------------------------------------

func _build_lessons() -> void:
	var root := _lessons_root
	# Left: lesson list + Chef Miso.
	Art.panel(root, "stats/profile_card.png", Rect2(184, 184, 440, 832), [2, 2, 4, 4])
	Art.image(root, "library/pin_red.png", Vector2(396, 174))
	Art.label(root, "One lesson per level", Vector2(208, 204), 20, Art.INK_SOFT)
	for i in Lessons.LESSONS.size():
		var b := Button.new()
		b.position = Vector2(204, 244 + i * 88)
		b.size = Vector2(400, 80)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_constant_override("outline_size", 0)
		b.pressed.connect(_show_lesson.bind(i, 0))
		root.add_child(b)
		_lesson_buttons.append(b)
	var mentor := TextureRect.new()
	mentor.texture = load(MENTOR) if ResourceLoader.exists(MENTOR) else null
	mentor.position = Vector2(306, 708)
	mentor.size = Vector2(197, 268)
	mentor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mentor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(mentor)

	# Right: the page.
	Art.panel(root, "library/note_paper.png", Rect2(660, 184, 1080, 832), [2, 2, 8, 8])
	Art.image(root, "library/pin_blue.png", Vector2(690, 176))
	Art.image(root, "library/pin_blue.png", Vector2(1700, 176))
	_title = Art.label(root, "", Vector2(700, 206), 40, Art.INK, false, 780, HORIZONTAL_ALIGNMENT_LEFT, Art.serif())
	_page_label = Art.label(root, "", Vector2(1480, 210), 20, Art.INK_SOFT, false, 220, HORIZONTAL_ALIGNMENT_RIGHT)
	_progress = Control.new()
	_progress.position = Vector2(1300, 244)
	_progress.size = Vector2(400, 20)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.draw.connect(_draw_progress)
	root.add_child(_progress)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(700, 276)
	_scroll.size = Vector2(1010, 600)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	_scroll.add_child(_body)

	_w3 = Art.button(root, "Read more on W3Schools", Rect2(700, 924, 330, 64), false, 20)
	_w3.pressed.connect(func(): OS.shell_open(_w3_url))
	_copy = Art.button(root, "Copy practice code", Rect2(1040, 924, 300, 64), false, 20)
	_copy.pressed.connect(_copy_practice)
	_prev = Art.button(root, "Back", Rect2(1350, 924, 170, 64), false, 24)
	_prev.pressed.connect(func(): _show_lesson(_lesson, _page - 1))
	_next = Art.button(root, "Next", Rect2(1530, 924, 190, 64), true, 24)
	_next.pressed.connect(_on_next)
	_gate = Art.label(root, "", Vector2(1040, 880), 18, Color(0.6, 0.22, 0.1), false, 680, HORIZONTAL_ALIGNMENT_RIGHT)


## Opens the lesson for a restaurant level, from its first page.
func open_lesson(level: int) -> void:
	for i in Lessons.LESSONS.size():
		if Lessons.LESSONS[i].level == level:
			_lesson = i
	_page = 0
	open()
	_show_mode(Mode.LESSONS)


## Opens the Kitchen Functions tab (on a topic or function id when given).
func open_functions(id := "") -> void:
	open()
	_show_mode(Mode.FUNCTIONS)
	for i in _entries.size():
		if _entries[i].id == id:
			_show_entry(i)


func _refresh() -> void:
	if _lesson_unlocked(_lesson) == false:
		_lesson = 0
	_show_lesson(_lesson, _page)


func _lesson_unlocked(i: int) -> bool:
	return Lessons.LESSONS[i].level <= GameState.restaurant_level


func _stars(i: int) -> Array:
	var have := 0
	var total := 0
	for p in Lessons.LESSONS[i].pages:
		if Quizzes.for_page(p.title).is_empty():
			continue
		total += 1
		if GameState.lesson_stars.has(p.title):
			have += 1
	return [have, total]


func _show_lesson(i: int, page: int) -> void:
	_run_id += 1
	_lesson = i
	var l: Dictionary = Lessons.LESSONS[i]
	var pages: Array = l.pages
	_page = clampi(page, 0, pages.size())
	_style_lesson_buttons()
	for c in _body.get_children():
		c.queue_free()
	var practice := _page >= pages.size()
	if practice:
		_title.text = "Practice: " + l.title
		_page_label.text = "Practice time!"
		var st: Array = _stars(i)
		_body.add_child(_miso_says("You made it to the practice round! You earned [b]%d of %d ★[/b] in this lesson. Now try it for real in the kitchen." % [st[0], st[1]], true))
		_body.add_child(_card("Your mission", l.practice.task, Color(0.95, 0.83, 0.55)))
		_body.add_child(_card("How", "1. Press [b]Copy practice code[/b].\n2. Walk up to a staff member and press [b]E[/b].\n3. Paste with [b]Ctrl+V[/b], fill in the missing steps and press [b]Run[/b].", Color(0.86, 0.92, 0.78)))
		_body.add_child(_code_card(l.practice.code))
		_w3_url = ""
		_need_try = false
		_need_quiz = false
	else:
		var p: Dictionary = pages[_page]
		_title.text = p.title
		_page_label.text = "Page %d of %d" % [_page + 1, pages.size() + 1]
		var parts := _split_text(p.text)
		_body.add_child(_miso_says(parts[0], false))
		if parts[1] != "":
			_body.add_child(_card("Key points", parts[1], Color(0.98, 0.93, 0.8)))
		var quiz: Dictionary = Quizzes.for_page(p.title)
		var done: bool = GameState.lesson_pages_done.has(p.title)
		_need_try = p.code != "" and not done
		_need_quiz = not quiz.is_empty() and not done
		if p.code != "":
			_body.add_child(_example(p.code))
		if not quiz.is_empty():
			_body.add_child(_quiz_card(p.title, quiz))
		_w3_url = Lessons.W3 + p.w3 if p.get("w3", "") != "" else ""
	_w3.visible = _w3_url != ""
	_copy.visible = practice
	_prev.disabled = _page == 0
	var last_lesson := i == Lessons.LESSONS.size() - 1 or not _lesson_unlocked(i + 1)
	_next.text = "Got it!" if practice else ("Practice" if _page == pages.size() - 1 else "Next")
	if practice and not last_lesson:
		_next.text = "Next lesson"
	_scroll.scroll_vertical = 0
	_progress.queue_redraw()
	_update_gate()
	if practice and not GameState.tutorials_seen.has(l.level):
		GameState.tutorials_seen.append(l.level)


## Locks Next until this page's Try it and quick check are done.
func _update_gate() -> void:
	var left: Array = []
	if _need_try:
		left.append("press ▶ Try it")
	if _need_quiz:
		left.append("answer the quick check")
	var pages: Array = Lessons.LESSONS[_lesson].pages
	if left.is_empty():
		_gate.text = ""
		_next.disabled = false
		if _page < pages.size() and not GameState.lesson_pages_done.has(pages[_page].title):
			GameState.lesson_pages_done.append(pages[_page].title)
	else:
		_gate.text = "To continue: " + " and ".join(left) + "."
		_next.disabled = true
	_next.tooltip_text = _gate.text


func _style_lesson_buttons() -> void:
	for j in _lesson_buttons.size():
		var lj: Dictionary = Lessons.LESSONS[j]
		var b := _lesson_buttons[j]
		var open := _lesson_unlocked(j)
		var st: Array = _stars(j)
		var stars := "   ★ %d/%d" % [st[0], st[1]] if open and st[1] > 0 else ""
		b.text = "Level %d · %s%s\n%s" % [lj.level, lj.title, stars, lj.concept if open else "Unlocks at Restaurant Level %d" % lj.level]
		b.disabled = not open
		var on := j == _lesson
		var sty := Art.style("recipe_book/row_selected.png", [2, 2, 2, 2], Vector4(16, 6, 10, 6)) if on else StyleBoxEmpty.new()
		if not on:
			(sty as StyleBoxEmpty).content_margin_left = 16
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(k, sty)
		var col := Art.INK if open else Art.INK_LOCKED
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
			b.add_theme_color_override(k, col)
		b.icon = null if open else Art.tex("recipe_book/lock.png")


## Page progress: one dot per page plus the practice page; done pages filled.
func _draw_progress() -> void:
	var n: int = Lessons.LESSONS[_lesson].pages.size() + 1
	var gap := minf(28.0, 400.0 / n)
	var x0 := 400.0 - gap * n
	for k in n:
		var c := Vector2(x0 + gap * k + gap * 0.5, 10)
		var col := Color(0.85, 0.55, 0.2) if k < _page else (Color(0.95, 0.7, 0.25) if k == _page else Color(0.75, 0.66, 0.55))
		_progress.draw_circle(c, 8.0 if k == _page else 6.0, col)


## First paragraph (Chef Miso's explanation) and the rest (key points).
func _split_text(text: String) -> Array:
	var cut := text.find("\n\n")
	var lines := text.split("\n")
	if cut == -1:
		# A page that is only a list: Chef Miso introduces it.
		if text.begins_with("•"):
			return [CHEERS[_page % CHEERS.size()] + " Here's what you need to know:", text]
		return [text, ""]
	var first := text.substr(0, cut)
	var rest := text.substr(cut + 2).strip_edges()
	if first.begins_with("•"):
		return [CHEERS[_page % CHEERS.size()] + " Here's what you need to know:", text]
	return [first, rest]


func _on_next() -> void:
	if _next.disabled:
		return
	var pages: Array = Lessons.LESSONS[_lesson].pages
	if _page < pages.size():
		_show_lesson(_lesson, _page + 1)
	elif _lesson + 1 < Lessons.LESSONS.size() and _lesson_unlocked(_lesson + 1):
		_show_lesson(_lesson + 1, 0)
	else:
		close()


func _on_close() -> void:
	_run_id += 1
	var lv: int = Lessons.LESSONS[_lesson].level
	if not GameState.tutorials_seen.has(lv):
		GameState.tutorials_seen.append(lv)


func _copy_practice() -> void:
	DisplayServer.clipboard_set(Lessons.LESSONS[_lesson].practice.code)
	_copy.text = "Copied!"
	get_tree().create_timer(1.5).timeout.connect(func(): _copy.text = "Copy practice code")


# --- Page pieces ----------------------------------------------------------------------

## Chef Miso's face and a speech bubble that types itself out.
func _miso_says(bbcode: String, big: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var face := TextureRect.new()
	face.texture = load(MENTOR) if ResourceLoader.exists(MENTOR) else null
	face.custom_minimum_size = Vector2(92, 125)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.98, 0.92)
	sb.border_color = Color(0.45, 0.3, 0.18)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	bubble.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	bubble.add_child(v)
	var who := Label.new()
	who.text = "Chef Miso"
	who.add_theme_font_override("font", Art.bold_font())
	who.add_theme_font_size_override("font_size", 18)
	who.add_theme_color_override("font_color", Art.RED_HEAD)
	v.add_child(who)
	var r := _rich(bbcode, 24 if big else 23)
	v.add_child(r)
	row.add_child(bubble)
	# Typewriter: reveal the words quickly; click the bubble to show it all.
	r.visible_ratio = 0.0
	var chars := maxi(1, r.get_total_character_count())
	var tw := create_tween()
	tw.tween_property(r, "visible_ratio", 1.0, clampf(chars / 140.0, 0.3, 2.2))
	bubble.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			tw.kill()
			r.visible_ratio = 1.0)
	return row


## A coloured note card with a small heading.
func _card(heading: String, bbcode: String, bg: Color) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = bg.darkened(0.35)
	sb.border_width_left = 8
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 22
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var h := Label.new()
	h.text = heading
	h.add_theme_font_override("font", Art.bold_font())
	h.add_theme_font_size_override("font_size", 22)
	h.add_theme_color_override("font_color", Art.RED_HEAD)
	v.add_child(h)
	v.add_child(_rich(bbcode.replace("• ", "[color=#c0782a]●[/color] "), 22))
	return card


## The page's example code with a "Try it" button that runs it right here.
func _example(code: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	var h := Label.new()
	h.text = "Example"
	h.add_theme_font_override("font", Art.bold_font())
	h.add_theme_font_size_override("font_size", 22)
	h.add_theme_color_override("font_color", Art.RED_HEAD)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h)
	var tip := Label.new()
	tip.text = "Edit the code, then press Try it   "
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Art.INK_SOFT)
	head.add_child(tip)
	var try_it := Art.button(head, "▶ Try it", Rect2(0, 0, 170, 52), true, 22)
	try_it.custom_minimum_size = Vector2(170, 52)
	try_it.tooltip_text = "Run the code here. Kitchen commands are only shown, not done."
	var reset := Art.button(head, "↺ Reset", Rect2(0, 0, 150, 52), false, 22)
	reset.custom_minimum_size = Vector2(150, 52)
	reset.tooltip_text = "Put the original example back"
	head.move_child(reset, try_it.get_index())
	v.add_child(head)
	var card := _code_card(code, true)
	var ce: CodeEdit = card.get_child(0)
	v.add_child(card)
	var out := RichTextLabel.new()
	out.bbcode_enabled = true
	out.fit_content = true
	out.scroll_active = false
	out.visible = false
	out.add_theme_font_override("normal_font", Art.mono())
	out.add_theme_font_size_override("normal_font_size", 19)
	out.add_theme_color_override("default_color", Color(0.85, 0.95, 0.8))
	var outbox := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.1, 0.08)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	outbox.add_theme_stylebox_override("panel", sb)
	outbox.visible = false
	outbox.add_child(out)
	out.visible = true
	v.add_child(outbox)
	try_it.pressed.connect(func(): _try_code(ce.text, out, outbox, try_it))
	reset.disabled = true
	ce.text_changed.connect(func(): reset.disabled = ce.text == code)
	reset.pressed.connect(func():
		_run_id += 1
		ce.text = code
		reset.disabled = true
		outbox.visible = false
		try_it.disabled = false)
	return v


## Runs an example with a sandbox staff member and shows what it prints.
func _try_code(code: String, out: RichTextLabel, box: Control, btn: Button) -> void:
	_run_id += 1
	var my_id := _run_id
	box.visible = true
	out.text = "[color=#b9a58a]Output[/color]\n"
	btn.disabled = true
	var host := SandboxHost.new()
	host.tree = get_tree()
	host.said = func(t: String):
		if my_id == _run_id and is_instance_valid(out):
			out.append_text(t)
	var interp := CInterpreter.new()
	interp.host = host
	interp.output.connect(func(t: String):
		if my_id == _run_id and is_instance_valid(out):
			out.append_text(t.replace("[", "[lb]")))
	if not interp.compile(code, GameState.library_slots):
		out.append_text("[color=#ff8a6a]%s[/color]\n" % interp.error.get("msg", "Error"))
		btn.disabled = false
		return
	# Stop runaway examples (shift loops) after a short preview.
	var watchdog := func():
		while my_id == _run_id and interp.host != null and not interp.stopped:
			if host.actions >= 24:
				interp.stop()
				break
			await get_tree().process_frame
	watchdog.call()
	get_tree().create_timer(8.0).timeout.connect(func(): interp.stop())
	await interp.run()
	if not is_instance_valid(out):
		return
	if my_id != _run_id:
		interp.stop()
	elif host.actions >= 24:
		out.append_text("[color=#e8b04a]… preview stopped here: in the kitchen this keeps going all shift.[/color]\n")
	elif not interp.error.is_empty():
		out.append_text("[color=#ff8a6a]Line %d: %s[/color]\n" % [interp.error.get("line", 0), interp.error.get("msg", "")])
	else:
		out.append_text("[color=#9fd67a]✔ Done![/color]\n")
	btn.disabled = false
	if my_id == _run_id and _mode == Mode.LESSONS and _need_try:
		_need_try = false
		_update_gate()


## Multiple-choice quick check; a right answer earns this page's star.
func _quiz_card(title: String, quiz: Dictionary) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.94, 0.98)
	sb.border_color = Color(0.35, 0.5, 0.7)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var done: bool = GameState.lesson_stars.has(title)
	var h := Label.new()
	h.text = "Quick check  ★" if done else "Quick check  (earn a star)"
	h.add_theme_font_override("font", Art.bold_font())
	h.add_theme_font_size_override("font_size", 22)
	h.add_theme_color_override("font_color", Color(0.2, 0.32, 0.5))
	v.add_child(h)
	v.add_child(_rich(quiz.q, 22))
	var feedback := _rich("", 21)
	var buttons: Array[Button] = []
	for k in quiz.a.size():
		var b := Button.new()
		b.text = "  %s   %s" % [["A", "B", "C", "D"][k], quiz.a[k]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_constant_override("outline_size", 0)
		_answer_look(b, Color(1, 1, 1), Color(0.6, 0.68, 0.8))
		v.add_child(b)
		buttons.append(b)
	v.add_child(feedback)
	for k in buttons.size():
		buttons[k].pressed.connect(func():
			var right: bool = k == int(quiz.ok)
			if right:
				_answer_look(buttons[k], Color(0.82, 0.95, 0.76), Color(0.3, 0.6, 0.25))
				for b2 in buttons:
					b2.disabled = true
				feedback.text = "[color=#2f6a1f][b]Correct![/b][/color] " + quiz.why
				if _mode == Mode.LESSONS and _need_quiz:
					_need_quiz = false
					_update_gate()
				if not GameState.lesson_stars.has(title):
					GameState.lesson_stars.append(title)
					h.text = "Quick check  ★  +1 star!"
					_pop(h)
					_style_lesson_buttons()
			else:
				_answer_look(buttons[k], Color(1, 0.86, 0.82), Color(0.75, 0.3, 0.2))
				buttons[k].disabled = true
				feedback.text = "[color=#9a3a20][b]Not quite.[/b][/color] Try another answer!")
	if done:
		feedback.text = "[color=#2f6a1f]You already got this one. ★[/color]"
	return card


func _answer_look(b: Button, bg: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = bg.lerp(Color(1, 0.95, 0.75), 0.5)
	for k in ["normal", "disabled", "focus"]:
		b.add_theme_stylebox_override(k, sb)
	for k in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(k, hov)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
		b.add_theme_color_override(k, Art.INK)


func _pop(c: Control) -> void:
	c.pivot_offset = c.size * Vector2(0, 0.5)
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2(1.15, 1.15), 0.12)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18)


func _rich(bbcode: String, fs: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_font_size_override("bold_font_size", fs)
	r.add_theme_font_size_override("mono_font_size", fs - 2)
	r.add_theme_font_override("bold_font", Art.bold_font())
	r.add_theme_font_override("mono_font", Art.mono())
	r.add_theme_color_override("default_color", Art.INK)
	r.add_theme_constant_override("line_separation", 6)
	r.text = bbcode
	return r


## Code on the dark code card. editable: players can change it and run it with
## Try it (Reset puts the example back).
func _code_card(code: String, editable := false) -> Control:
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
	if editable:
		ce.editable = true
		ce.indent_automatic = true
		ce.auto_brace_completion_enabled = true
		ce.indent_use_spaces = true
		ce.indent_size = 4
		ce.caret_blink = true
		ce.add_theme_color_override("caret_color", Color(1, 0.85, 0.4))
		ce.add_theme_color_override("current_line_color", Color(1, 1, 1, 0.05))
		ce.add_theme_color_override("selection_color", Color(0.4, 0.5, 0.8, 0.5))
		ce.mouse_default_cursor_shape = Control.CURSOR_IBEAM
		ce.tooltip_text = "Click to edit this code"
		var focus_line := StyleBoxFlat.new()
		focus_line.draw_center = false
		focus_line.border_color = Color(1, 0.8, 0.35, 0.8)
		focus_line.set_border_width_all(2)
		focus_line.set_corner_radius_all(4)
		ce.add_theme_stylebox_override("focus", focus_line)
	card.add_child(ce)
	return card


# --- Kitchen Functions (moved from the Recipe Book) -----------------------------------

func _build_functions() -> void:
	var root := _functions_root
	Art.panel(root, "stats/profile_card.png", Rect2(184, 184, 520, 832), [2, 2, 4, 4])
	Art.image(root, "library/pin_red.png", Vector2(430, 174))
	Art.label(root, "Click a topic to learn it", Vector2(208, 204), 20, Art.INK_SOFT)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(200, 240)
	scroll.size = Vector2(492, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "TopicScroll"
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "Topics"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	Art.panel(root, "library/note_paper.png", Rect2(740, 184, 1000, 832), [2, 2, 8, 8])
	Art.image(root, "library/pin_blue.png", Vector2(770, 176))
	Art.image(root, "library/pin_blue.png", Vector2(1700, 176))
	_help_scroll = ScrollContainer.new()
	_help_scroll.position = Vector2(780, 210)
	_help_scroll.size = Vector2(930, 780)
	_help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_help_scroll)
	_help = VBoxContainer.new()
	_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help.add_theme_constant_override("separation", 8)
	_help_scroll.add_child(_help)


func _fill_entries() -> void:
	var list: VBoxContainer = _functions_root.get_node("TopicScroll/Topics")
	for c in list.get_children():
		c.queue_free()
	_entry_buttons.clear()
	var group := ""
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		if e.group != group:
			group = e.group
			if list.get_child_count() > 0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 8)
				list.add_child(gap)
			list.add_child(_heading(group, 24))
		var b := Button.new()
		b.text = e.title
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_constant_override("outline_size", 0)
		if e.group.begins_with("Kitchen"):
			b.add_theme_font_override("font", Art.mono())
		var locked: bool = e.level > GameState.restaurant_level
		if locked:
			b.icon = Art.tex("recipe_book/lock.png")
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 22)
		b.set_meta("locked", locked)
		b.pressed.connect(_show_entry.bind(i))
		list.add_child(b)
		_entry_buttons.append(b)
	_show_entry(clampi(_entry_selected, 0, _entries.size() - 1))


func _style_entry(b: Button, on: bool) -> void:
	var col := Art.INK_LOCKED if b.get_meta("locked") else Art.INK
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, Color(0.29, 0.15, 0.06) if on else col)
	var sel := Art.style("recipe_book/row_selected.png", [2, 2, 2, 2], Vector4(14, 2, 10, 2))
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.9, 0.8, 0.6, 0.5)
	hover.content_margin_left = 14
	var none := StyleBoxEmpty.new()
	none.content_margin_left = 14
	b.add_theme_stylebox_override("normal", sel if on else none)
	b.add_theme_stylebox_override("hover", sel if on else hover)
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("hover_pressed", sel)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _show_entry(i: int) -> void:
	_entry_selected = i
	for j in _entry_buttons.size():
		_style_entry(_entry_buttons[j], j == i)
	var e: Dictionary = _entries[i]
	for c in _help.get_children():
		c.queue_free()
	var t := _heading(e.title, 44)
	t.add_theme_color_override("font_color", Art.INK)
	_help.add_child(t)
	_help.add_child(_text(e.group, 18, Art.INK_SOFT))
	if e.level > GameState.restaurant_level:
		_help.add_child(_text("Unlocks at Restaurant Level %d. You can read about it now." % e.level, 19, Color(0.7, 0.2, 0.12), true))
	_help.add_child(_heading("Syntax", 26))
	_help.add_child(_code_card(e.syntax))
	if not e.get("points", []).is_empty():
		_help.add_child(_heading("Syntax explained", 26))
		for p in e.points:
			_help.add_child(_text("•  " + p, 19))
	_help.add_child(_heading("What it does", 26))
	_help.add_child(_text(e.about, 20))
	if not e.steps.is_empty():
		_help.add_child(_heading("How to use it", 26))
		for s in e.steps.size():
			_help.add_child(_text("%d.  %s" % [s + 1, e.steps[s]], 20))
	_help.add_child(_example(e.example))
	if not e.get("mistakes", []).is_empty():
		_help.add_child(_heading("Common mistakes", 26))
		for m in e.mistakes:
			_help.add_child(_text("•  " + m, 19, Color(0.55, 0.2, 0.12)))
	if not e.get("related", []).is_empty():
		var rel: Array = []
		for r in e.related:
			rel.append(r + "()")
		_help.add_child(_text("See also: " + ", ".join(rel), 19, Art.INK_SOFT, true))
	if e.get("w3", "") != "":
		var link := Art.button(_help, "Learn more on W3Schools", Rect2(0, 0, 340, 56), false, 20)
		link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		link.custom_minimum_size = Vector2(340, 56)
		link.tooltip_text = e.w3
		link.pressed.connect(func(): OS.shell_open(e.w3))
	_help_scroll.scroll_vertical = 0


func _heading(text: String, fs: int) -> Label:
	var h := Label.new()
	h.text = text
	h.add_theme_font_override("font", Art.serif() if fs >= 40 else Art.bold_font())
	h.add_theme_font_size_override("font_size", fs)
	h.add_theme_color_override("font_color", Art.RED_HEAD)
	h.add_theme_constant_override("outline_size", 0)
	return h


func _text(s: String, fs: int, color := Art.INK, bold := false) -> Label:
	var t := Label.new()
	t.text = s
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", fs)
	t.add_theme_color_override("font_color", color)
	t.add_theme_constant_override("outline_size", 0)
	if bold:
		t.add_theme_font_override("font", Art.bold_font())
	return t

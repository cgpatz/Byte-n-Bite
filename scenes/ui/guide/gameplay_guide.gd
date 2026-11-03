extends CanvasLayer
## RPG-style gameplay tutorial. Chef Miso talks in a dialogue box at the
## bottom of the screen (portrait, name plate, typewriter text) and hands out
## small quests ("Walk up to Jane and press E") that wait until the player has
## really done them. A bouncing arrow points at the thing to use.
##
## Runs on a new game (Level 1, the full walkthrough) and after every
## restaurant upgrade (a short tour of what is new). Finished guides are
## remembered in GameState.guides_done. There is no skipping: every quest must
## be done, and a level's guide only starts after the previous level's guide.
##
## Step: {"say": BBCode} waits for a click / Space / Enter.
##       {"do": quest text, "say": BBCode, "until": condition id, "point": target id}
##       waits until the condition is met.

signal finished

const MENTOR := "res://assets/ui/windows/tutorial/mentor.png"
const MisoQuests := preload("res://data/help/miso_quests.gd")
const BOX_W := 770.0
const Paper := preload("res://scenes/ui/common/paper.gd")
## Put in an empty editor for the "Press Run" quest (a program that surely runs).
const STARTER := "// Chef Miso's first program for you\nint main() {\n    printf(\"Hi, I'm %s! Off to the fridge.\\n\");\n    go_to(FRIDGE);\n    return 0;\n}\n"
const BOX_H := 196.0

var game: Node
var _steps: Array = []
var _i := -1
var _level := 0
var _waiting_click := false
var _ran := false
var _zoom_before := 0
var _win_before := Transform2D()
var _rect_before := Rect2()
var _runs_before := {}   # staff name -> run_count when a coding quest started
var _said_before := {}   # staff name -> what their thought bubble said at step start
var _start_pos := Vector2.ZERO
var _walked := 0.0   # distance walked during the "move around" quest, in any direction
var _time := 0.0

var _root: Control
var _box: PanelContainer
var _text: RichTextLabel
var _quest: PanelContainer
var _quest_text: RichTextLabel
var _more: Label
var _step_label: Label
var _arrow: Control
var _type_tween: Tween
var _target_rect := Rect2()
var _point := ""


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_arrow()
	_build_box()
	_build_quest()
	_root.hide()


func is_running() -> bool:
	return _i >= 0


## The step on screen right now ({} when the guide isn't running).
func current_step() -> Dictionary:
	return _steps[_i] if _i >= 0 and _i < _steps.size() else {}


## The coding quest the guide is on right now (-1 on tour steps).
func current_quest_index() -> int:
	if _i < 0 or _i >= _steps.size():
		return -1
	var st: Dictionary = _steps[_i]
	return int(st.get("quest_index", st.get("quest_index_do", -1)))


## True while Chef Miso's tutorial runs (tour AND coding quests): the
## restaurant holds new customers back until the whole tutorial is over, so
## beginners can learn without pressure. (serve() with nobody waiting puts the
## dish on the counter, which still counts for the quests.)
func is_touring() -> bool:
	return _i >= 0 and _i < _steps.size()


## Plays the guide for a restaurant level; returns when every step is done.
func run(level: int, replay := false) -> void:
	_steps = steps_for(level)
	if replay:
		# Pause menu > Replay tutorial: just the tour (the C quests stay in the Quest Log).
		_steps = _walkthrough(level)
	if _steps.is_empty():
		return
	_level = level
	_ran = false
	for s in game.staff_root.get_children():
		if s.has_signal("running_changed") and not s.running_changed.is_connected(_on_staff_running):
			s.running_changed.connect(_on_staff_running)
	_start_pos = game.manager.global_position
	_root.show()
	_i = -1
	# Coming back to a level whose coding quests were started: skip the tour
	# and continue with the next unfinished quest.
	var done_q := int(GameState.quest_progress.get(str(level), 0))
	if done_q > 0 and not replay:
		_i = _steps.size() - 2  # all quests done: just the closing line
		var last_q := -1
		for k in _steps.size():
			if _steps[k].has("quest_index"):
				last_q = k
			if _steps[k].get("quest_index", -1) == done_q:
				_i = k - 1
				last_q = -2
				break
		if last_q >= 0:
			_i = last_q  # all quests done: continue with the tour after them
	_next_step()
	await finished


func _on_staff_running(on: bool) -> void:
	if on:
		_ran = true


func _next_step() -> void:
	_i += 1
	if _i >= _steps.size():
		_end()
		return
	var st: Dictionary = _steps[_i]
	_step_label.text = "%d / %d" % [_i + 1, _steps.size()]
	_point = st.get("point", "")
	_waiting_click = not st.has("until")
	if st.has("until"):
		if st.get("until") == "moved":
			_start_pos = game.manager.global_position
			_walked = 0.0
		if st.get("until") in ["win_moved", "win_resized"]:
			var wf: Control = _step_window().frame
			_win_before = Transform2D(0.0, wf.scale, 0.0, wf.position)
		if st.get("until") == "zoomed":
			_zoom_before = SettingsManager.code_font_size
		if st.get("until") in ["resized", "editor_moved"]:
			_rect_before = game.programming_panel._current_rect()
		if st.get("until") == "talked":
			_said_before = _speech_texts()
		if st.get("until") == "ran":
			_ran = false
			var ce: CodeEdit = game.programming_panel.code_edit
			if ce.text.strip_edges() == "" or ce.text == game.programming_panel.MAIN_TEMPLATE:
				ce.text = STARTER % _first_staff()
		# "Fix the bug" quests: Chef Miso's broken program goes into the editor.
		if String(st.get("broken", "")) != "":
			_load_broken(String(st.broken))
		_quest.show()
		_quest_text.text = ("[b]C Quest:[/b] " if String(st.until).begins_with("miso:") else "[b]Quest:[/b] ") + st.do
		_pop(_quest)
	else:
		_quest.hide()
	_show_example(st.get("example", ""))
	_type(st.get("say", st.get("do", "")))
	_more.text = "Space = next" if _waiting_click else "Do the quest to continue"
	if _next_btn:
		_next_btn.visible = _waiting_click
		_skip_btn.visible = _level == 1 or not st.has("quest_index")


func _load_broken(code: String) -> void:
	var pp = game.programming_panel
	if pp.visible and pp.staff:
		pp.code_edit.text = code
		pp.staff.program_source = code
		return
	for s in game.staff_root.get_children():
		if s is Staff:
			s.program_source = code
			return


func _end() -> void:
	_show_example("")
	if not GameState.guides_done.has(_level):
		GameState.guides_done.append(_level)
	_i = -1
	_point = ""
	_root.hide()
	finished.emit()


# --- Each frame: quest checks, arrow, box placement ---------------------------------

func _process(delta: float) -> void:
	if _i < 0:
		return
	_time += delta
	var st: Dictionary = _steps[_i]
	if st.has("until") and _met(st.until):
		_next_step()
		return
	_place_box()
	_place_example()
	_target_rect = _target(_point)
	_arrow.visible = _target_rect.size != Vector2.ZERO or _target_rect.position != Vector2.ZERO
	_arrow.queue_redraw()


func _met(cond: String) -> bool:
	if cond.begins_with("miso:"):
		return GameState.miso_progress(_level) > int(cond.substr(5))
	match cond:
		"moved":
			# Any walking counts (WASD or arrows, any direction, even back and
			# forth): add up the distance walked, about one tile is enough.
			var p: Vector2 = game.manager.global_position
			_walked += p.distance_to(_start_pos)
			_start_pos = p
			return _walked > 48.0
		"panel_open":
			return game.programming_panel.visible
		"win_moved":
			return _step_window().frame.position.distance_to(_win_before.origin) > 30.0
		"win_resized":
			return absf(_step_window().frame.scale.x - _win_before.get_scale().x) > 0.04
		"zoomed":
			return SettingsManager.code_font_size != _zoom_before
		"editor_moved":
			return game.programming_panel._current_rect().position.distance_to(_rect_before.position) > 24.0
		"resized":
			var r: Rect2 = game.programming_panel._current_rect()
			return absf(r.size.x - _rect_before.size.x) > 24.0 or absf(r.size.y - _rect_before.size.y) > 24.0
		"talked":
			var now := _speech_texts()
			for k in now:
				if now[k] != "" and now[k] != _said_before.get(k, ""):
					return true
			return false
		"ran":
			return _ran
		"panel_closed":
			return not game.programming_panel.visible
		"market":
			return game.in_market
		"back":
			return not game.in_market
		"lessons_closed":
			return not game.tutorial_window.visible
		"lessons":
			return game.tutorial_window.visible
		"recipe_book":
			return game.recipe_book.visible
		"library":
			return game.library_panel.visible
		"stats":
			return game.stats_panel.visible
	return true


## Screen rect of what the arrow points at (empty = no arrow).
func _target(id: String) -> Rect2:
	if id == "":
		return Rect2()
	var hud = game.hud
	if id == "editor":
		id = "code" if game.programming_panel.visible else "staff"
	if id.begins_with("hud:"):
		var b: Control = hud.window_buttons.get(id.substr(4))
		return b.get_global_rect() if b and b.is_visible_in_tree() else Rect2()
	match id:
		"manager":
			return _world_rect(game.manager, Vector2(0, -24))
		"staff":
			# Still outside? Point at the front entrance first, then at the staff.
			if game.has_method("_level_has_outside") and game._level_has_outside() \
					and not Rect2(0, 0, 512, 512).has_point(game.manager.global_position):
				var ep: Vector2 = game.get_viewport().get_canvas_transform() * Vector2(256, 520)
				return Rect2(ep - Vector2(30, 30), Vector2(60, 60))
			for s in game.staff_root.get_children():
				if s is Node2D and s.visible:
					return _world_rect(s, Vector2(0, -60))
		"win_grip":
			var wg: Control = game.tutorial_window._grip
			return wg.get_global_rect() if wg and wg.is_visible_in_tree() else Rect2()
		"lib_grip":
			var lg: Control = game.library_panel._grip
			return lg.get_global_rect() if lg and lg.is_visible_in_tree() else Rect2()
		"lib_code":
			var lc: Control = game.library_panel._code
			return lc.get_global_rect() if lc and lc.is_visible_in_tree() else Rect2()
		"rb_grip":
			var rg: Control = game.recipe_book._grip
			return rg.get_global_rect() if rg and rg.is_visible_in_tree() else Rect2()
		"grip":
			var gp: Control = game.programming_panel._grip
			return gp.get_global_rect() if gp and gp.is_visible_in_tree() else Rect2()
		"editor_title":
			var tl: Control = game.programming_panel.title
			return tl.get_global_rect() if tl and tl.is_visible_in_tree() else Rect2()
		"code":
			var ce: Control = game.programming_panel.code_edit
			return ce.get_global_rect() if ce and ce.is_visible_in_tree() else Rect2()
		"run":
			var rb: Control = game.programming_panel.run_button
			return rb.get_global_rect() if rb.is_visible_in_tree() else Rect2()
		"board":
			var bd: Control = hud._board
			return bd.get_global_rect() if bd and bd.is_visible_in_tree() else Rect2()
		"special":
			var sp = hud.get("_special")
			return sp.get_global_rect() if sp is Control and sp.is_visible_in_tree() else Rect2()
		"goals":
			var qc = hud.get("_qcard")
			return qc.get_global_rect() if qc is Control and qc.is_visible_in_tree() else Rect2(40, 240, 300, 40)
		"buttons":
			var row: Control = hud.get_node_or_null("WindowButtons")
			return row.get_global_rect() if row else Rect2()
	if id.begins_with("station:"):
		var s: Node2D = game.get_station(id.substr(8))
		if s and s.is_visible_in_tree():
			return _world_rect(s, Vector2(0, -20))
	return Rect2()


func _world_rect(n: Node2D, off: Vector2) -> Rect2:
	var p: Vector2 = n.get_global_transform_with_canvas().origin + off * game.camera.zoom
	return Rect2(p - Vector2(30, 30), Vector2(60, 60))


## The box sits bottom-centre, or bottom-left while the code editor is open.
func _place_box() -> void:
	var vs := _root.get_viewport_rect().size
	var x := 16.0  # docked bottom-left, clear of the entrance
	_box.position = _box.position.lerp(Vector2(x, vs.y - BOX_H - 16), 0.25)
	_quest.position = Vector2(x + 130, vs.y - BOX_H - 16 - 62)


# --- Input ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _i < 0 or not _waiting_click:
		return
	var focus := _root.get_viewport().gui_get_focus_owner()
	if focus is TextEdit or focus is LineEdit:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_root.get_viewport().set_input_as_handled()
		_advance()


func _on_box_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _type_tween and _type_tween.is_running():
			_type_tween.kill()
			_text.visible_ratio = 1.0
		elif _waiting_click:
			_advance()


func _advance() -> void:
	if _type_tween and _type_tween.is_running():
		_type_tween.kill()
		_text.visible_ratio = 1.0
		return
	_next_step()


# --- Building the UI -----------------------------------------------------------------

## Chef Miso's box: paper card docked bottom-LEFT (so the restaurant entrance
## stays visible), portrait, gold name tab, step counter, Skip tour and Next.
var _next_btn: Button
var _skip_btn: Button


func _build_box() -> void:
	_box = PanelContainer.new()
	_box.size = Vector2(BOX_W, BOX_H)
	_box.custom_minimum_size = Vector2(BOX_W, BOX_H)
	_box.add_theme_stylebox_override("panel", Paper.panel(Vector4(22, 30, 26, 14)))
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.gui_input.connect(_on_box_input)
	_root.add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("e8d6a8")
	fsb.border_color = Paper.INK
	fsb.set_border_width_all(3)
	fsb.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var face := TextureRect.new()
	face.texture = load(MENTOR) if ResourceLoader.exists(MENTOR) else null
	face.custom_minimum_size = Vector2(100, 120)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(face)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	row.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var tab := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Paper.GOLD
	tsb.border_color = Paper.INK
	tsb.set_border_width_all(3)
	tsb.set_corner_radius_all(10)
	tsb.content_margin_left = 14
	tsb.content_margin_right = 14
	tsb.content_margin_top = 0
	tsb.content_margin_bottom = 2
	tab.add_theme_stylebox_override("panel", tsb)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(Paper.label("Chef Miso", 20, Paper.INK, true))
	head.add_child(tab)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sp)
	_step_label = Paper.label("", 17, Paper.INK_SOFT)
	head.add_child(_step_label)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.add_theme_font_size_override("bold_font_size", 21)
	_text.add_theme_color_override("default_color", Paper.INK)
	_text.add_theme_constant_override("line_separation", 2)
	v.add_child(_text)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	_more = Paper.label("", 15, Paper.INK_SOFT)
	_more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_more)
	_skip_btn = Paper.button("Skip tour", false, 17)
	_skip_btn.custom_minimum_size = Vector2(130, 46)
	_skip_btn.tooltip_text = "Skip the tour (Chef Miso's C quests stay in your Quest Log)"
	_skip_btn.pressed.connect(_skip_tour)
	foot.add_child(_skip_btn)
	_next_btn = Paper.button("Next ▸", true, 17)
	_next_btn.custom_minimum_size = Vector2(118, 46)
	_next_btn.pressed.connect(_advance)
	foot.add_child(_next_btn)
	var vs := Vector2(1920, 1080)
	_box.position = Vector2(16, vs.y - BOX_H - 16)


## Skip tour: jump to Chef Miso's first coding quest, or end the tour if the
## quests are already under way (they stay in the Quest Log).
func _skip_tour() -> void:
	if _i < 0:
		return
	for k in range(_i + 1, _steps.size()):
		if _steps[k].has("quest_index") and not _steps[_i].has("quest_index"):
			var done_q := GameState.miso_progress(_level)
			# Skip straight to the first unfinished quest.
			for j in range(k, _steps.size()):
				if int(_steps[j].get("quest_index", -1)) >= done_q:
					_i = j - 1
					_next_step()
					return
	_end()


func _build_quest() -> void:
	_quest = PanelContainer.new()
	_quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.9, 0.62)
	sb.border_color = Color(0.55, 0.36, 0.12)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_quest.add_theme_stylebox_override("panel", sb)
	_quest_text = RichTextLabel.new()
	_quest_text.bbcode_enabled = true
	_quest_text.fit_content = true
	_quest_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_quest_text.scroll_active = false
	_quest_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_text.add_theme_font_size_override("normal_font_size", 23)
	_quest_text.add_theme_font_size_override("bold_font_size", 23)
	_quest_text.add_theme_color_override("default_color", Color(0.25, 0.14, 0.06))
	_quest.add_child(_quest_text)
	_root.add_child(_quest)
	_quest.hide()


func _build_arrow() -> void:
	_arrow = Control.new()
	_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(_draw_arrow)
	_root.add_child(_arrow)


## A pulsing ring around the target and a bouncing arrow pointing at it
## (from below for things at the top of the screen, from above otherwise).
func _draw_arrow() -> void:
	var r := _target_rect
	if r.size == Vector2.ZERO:
		return
	var c := r.get_center()
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Color(1, 0.85, 0.3, 0.55 + 0.4 * pulse)
	ring.set_border_width_all(5)
	ring.set_corner_radius_all(16)
	_arrow.draw_style_box(ring, r.grow(8.0 + pulse * 5.0))
	var bob := sin(_time * 6.0) * 10.0
	var up := c.y < 300.0
	var tip := Vector2(c.x, (r.end.y + 18 + bob) if up else (r.position.y - 18 - bob))
	var d := -1.0 if up else 1.0   # arrow body extends away from the tip
	var body := PackedVector2Array([tip, tip + Vector2(-26, -34 * d), tip + Vector2(-11, -34 * d),
		tip + Vector2(-11, -70 * d), tip + Vector2(11, -70 * d), tip + Vector2(11, -34 * d), tip + Vector2(26, -34 * d)])
	var outline := body.duplicate()
	outline.append(tip)
	_arrow.draw_colored_polygon(body, Color(1, 0.78, 0.25))
	_arrow.draw_polyline(outline, Color(0.35, 0.18, 0.05), 4.0, true)


func _type(bbcode: String) -> void:
	_text.text = bbcode
	_text.visible_ratio = 0.0
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	var n := maxi(1, _text.get_total_character_count())
	_type_tween.tween_property(_text, "visible_ratio", 1.0, clampf(n / 55.0, 0.3, 3.0))


func _pop(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- The scripts ---------------------------------------------------------------------

## The window a move / resize quest is about (step "win": "library", default Lessons).
func _step_window() -> Control:
	var st: Dictionary = _steps[_i] if _i >= 0 and _i < _steps.size() else {}
	return game.library_panel if st.get("win", "") == "library" else game.tutorial_window


## What each staff member's printf thought bubble says right now.
func _speech_texts() -> Dictionary:
	var out := {}
	for s in game.staff_root.get_children():
		var b = s.get("_speech")
		if b != null and "staff_name" in s:
			out[s.staff_name] = b.text
	return out


func _first_staff() -> String:
	for s in game.staff_root.get_children():
		if "staff_name" in s:
			return s.staff_name
	return "your cook"


## The level's tour with Chef Miso's hands-on coding quest for each new C topic
## (at the "quests_here" marker, or after the tour's lesson step).
func steps_for(level: int) -> Array:
	if GameState.short_tour:
		return _short_tour(level)
	var tour := _walkthrough(level, true)
	var quests: Array = MisoQuests.for_level(level)
	var who := _first_staff()
	var qsteps: Array = []
	for k in quests.size():
		var q: Dictionary = quests[k]
		qsteps.append({"quest_index": k, "example": q.example, "point": "editor", "customer": q.get("customer", ""), "broken": q.get("broken", ""),
			"do": q.do.replace("{who}", who), "until": "miso:%d" % k,
			"say": "[b]C Quest %d of %d: %s[/b]\n%s Write it in [b]main()[/b] and press [b]Run[/b]." % [k + 1, quests.size(), q.topic, q.say]})
	var out: Array = []
	var placed := false
	for st in tour:
		if st.has("quests_here"):
			out.append_array(qsteps)
			placed = true
		else:
			out.append(st)
	if not placed and not qsteps.is_empty():
		out.append({"do": "Close the Lessons window when you're ready to code.", "say": "Now let's [b]practise[/b]! For each new C idea I'll give you a small coding quest. Close the Lessons window when you're ready ([b]T[/b] opens it again any time).", "until": "lessons_closed"})
		out.append_array(qsteps)
		out.append({"say": "Every C quest for this level is done. Great coding, chef! ★"})
	return out


## "I know some C": a quick tour; Chef Miso's C quests wait in the Quest Log.
func _short_tour(level: int) -> Array:
	var who := _first_staff()
	var log_step := {"say": "Your [b]Quest Log[/b] (left side, [b]G[/b]) lists Chef Miso's C quests one at a time, then the [b]Level Challenge[/b] and the restaurant goals. Press [b]Show example[/b] there if you need a hint.", "point": "goals"}
	if level == 1:
		return [
			{"do": "Move with [b]WASD[/b] or the [b]arrow keys[/b].", "say": "Welcome, chef! I'm [b]Chef Miso[/b]. You're the cat in the apron: walk with [b]WASD[/b] or the [b]arrow keys[/b].", "until": "moved", "point": "manager"},
			{"do": "Walk to %s and press [b]E[/b]." % who, "say": "Go in through the [b]front door[/b] and walk up to [b]%s[/b] (you can talk across the counter), then press [b]E[/b] to open the code editor." % who, "until": "panel_open", "point": "staff"},
			{"do": "Drag the editor's [b]title bar[/b] to move it.", "say": "Windows can go anywhere: hold the mouse on the editor's [b]title bar[/b] and drag it.", "until": "editor_moved", "point": "editor_title"},
			{"do": "Drag the [b]corner grip[/b] (bottom right) to resize the editor.", "say": "Drag the [b]corner grip[/b] at the bottom right to make it bigger or smaller. Every window (Lessons, Recipe Book...) works the same way.", "until": "resized", "point": "grip"},
			{"say": "Write C and press [b]Run[/b]; printf output shows in %s's thought bubble. Buy ingredients at the Night Market ([b]M[/b])." % who},
			{"say": "Your [b]Quest Log[/b] ([b]G[/b]) has Chef Miso's C quests, the Level Challenge and the goals. [b]Lessons[/b] ([b]T[/b]) explain every C idea. Have fun!", "point": "goals"},
		]
	var full := _walkthrough(level)
	var out: Array = []
	for st in full:
		if not st.has("until"):
			out.append(st)
		if out.size() >= 2:
			break
	out.append(log_step)
	return out


func _walkthrough(level: int, keep_marker := false) -> Array:
	var all := _walkthrough_steps(level)
	if keep_marker:
		return all
	return all.filter(func(st): return not st.has("quests_here"))


func _walkthrough_steps(level: int) -> Array:
	var who := _first_staff()
	match level:
		1:
			# As short as possible: only what a beginner can't guess. Coding
			# starts at step 4; windows, icons and zoom explain themselves.
			return [
				{"say": "Welcome to [b]Byte n' Bite[/b], chef! I'm [b]Chef Miso[/b]. Your staff cook whatever you [b]program[/b] them to do in C."},
				{"do": "Move with [b]WASD[/b] or the [b]arrow keys[/b].", "say": "You're the cat in the apron, the [b]Manager[/b]. Take a little walk with [b]WASD[/b] or the [b]arrow keys[/b].", "until": "moved", "point": "manager"},
				{"do": "Walk to %s and press [b]E[/b]." % who, "say": "Go in through the [b]front door[/b] and walk up to [b]%s[/b], your cook (you can talk across the counter). Press [b]E[/b] to open the code editor; the bubble over your head shows what E will do." % who, "until": "panel_open", "point": "staff"},
				{"do": "Drag the editor's [b]title bar[/b] to move it.", "say": "Windows can go anywhere: hold the mouse on the editor's [b]title bar[/b] and drag it.", "until": "editor_moved", "point": "editor_title"},
				{"do": "Drag the [b]corner grip[/b] (bottom right) to resize the editor.", "say": "Drag the [b]corner grip[/b] at the bottom right to make it bigger or smaller. Every window (Lessons, Recipe Book...) works the same way.", "until": "resized", "point": "grip"},
				{"say": "Write C here and press [b]Run[/b]. The [b]Output[/b] box shows messages and mistakes, and whatever [b]printf[/b] prints, %s says in a thought bubble." % who, "point": "code"},
				{"quests_here": true},
				{"say": "When we're done, customers come in! At this level they all order [b]Today's Special[/b] (top left). Run your Eggsilog program again for each one.", "point": "board"},
				{"say": "Out of ingredients? Buy more at the [b]Night Market[/b] ([b]M[/b]), then press [b]E[/b] on the crates the truck drops off.", "point": "hud:market"},
				{"say": "Your [b]Quest Log[/b] ([b]G[/b]) shows the Level Challenge and goals for the next upgrade, and the [b]Lessons[/b] ([b]T[/b]) explain every C idea. Have fun, chef!", "point": "goals"},
			]
		2:
			return [
				{"say": "Welcome to the [b]Small Diner[/b]! From now on customers choose from the [b]whole menu[/b], so there's no more Today's Special."},
				{"say": "New customers show a [b]?[/b] bubble. Someone has to ask first: [b]take_order()[/b] walks over and returns the dish they want. Then use [b]if / else[/b] to cook the right one."},
				{"say": "Food can [b]burn[/b] now: [b]is_burnt()[/b] tells you, and [b]trash()[/b] throws it away. New dishes are in the [b]Recipe Book[/b] ([b]R[/b])."},
				{"do": "Press [b]T[/b] for Lesson 2: Making Decisions.", "say": "Press [b]T[/b] for your next lesson.", "until": "lessons", "point": "hud:tutorial"},
			]
		3:
			return [
				{"say": "Welcome to the [b]Neighborhood Cafe[/b]! It's busier now, so your staff should work [b]all shift long[/b]. That's what [b]loops[/b] are for."},
				{"say": "Teamwork time: a waiter can [b]take_order()[/b] and [b]post_order()[/b] the ticket, and a cook loops on [b]check_counter()[/b] to make it. Tickets show on the Order board.", "point": "board"},
				{"say": "[b]stock(INGREDIENT)[/b] tells you how many are left, and [b]doneness()[/b] / [b]flip()[/b] help you cook just right."},
				{"do": "Press [b]T[/b] for Lesson 3: Loops.", "say": "Let's learn loops! Press [b]T[/b].", "until": "lessons", "point": "hud:tutorial"},
			]
		4:
			return [
				{"say": "Welcome to the [b]Busy Eatery[/b]! Big dishes need many ingredients, and [b]arrays[/b] keep a whole list of values in one variable."},
				{"say": "[b]recipe(DISH, items)[/b] fills an array with a dish's ingredients, [b]cook_station(ING)[/b] says where to cook each one, and [b]orders(list)[/b] copies the waiting tickets."},
				{"do": "Press [b]T[/b] for Lesson 4: Arrays.", "say": "Now for arrays. Press [b]T[/b].", "until": "lessons", "point": "hud:tutorial"},
			]
		5:
			return [
				{"say": "Welcome to the [b]Grand Restaurant[/b]! Programs get long here, so you'll write your [b]own functions[/b] and reuse them."},
				{"do": "Open your Library ([b]L[/b]).", "say": "Functions you save in the [b]Library[/b] can be used by every staff member. Open it with [b]L[/b].", "until": "library", "point": "hud:library"},
				{"do": "Press [b]T[/b] for Lesson 5: Functions.", "say": "Tick a slot's [b]Use[/b] box to share it. Now press [b]T[/b] for the last lesson!", "until": "lessons", "point": "hud:tutorial"},
			]
	return []


# --- Coding quests: example card and progress -------------------------------------

var _example_card: PanelContainer
var _example_text: RichTextLabel
var _example_code := ""


## The example code for the current coding quest, above the dialogue box,
## with a Copy button.
func _show_example(code: String) -> void:
	_example_code = code
	if _example_card == null:
		_example_card = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.08, 0.07, 0.97)
		sb.border_color = Color(0.93, 0.72, 0.38)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		_example_card.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		_example_card.add_child(v)
		var head := HBoxContainer.new()
		v.add_child(head)
		var t := Label.new()
		t.text = "Example"
		t.add_theme_font_size_override("font_size", 18)
		t.add_theme_color_override("font_color", Color(1, 0.8, 0.45))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		var copy := Button.new()
		copy.text = "Copy"
		copy.focus_mode = Control.FOCUS_NONE
		copy.add_theme_font_size_override("font_size", 16)
		copy.pressed.connect(func():
			DisplayServer.clipboard_set(_example_code)
			copy.text = "Copied!"
			get_tree().create_timer(1.2).timeout.connect(func(): copy.text = "Copy"))
		head.add_child(copy)
		_example_text = RichTextLabel.new()
		_example_text.bbcode_enabled = false
		_example_text.fit_content = true
		_example_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		_example_text.scroll_active = false
		_example_text.custom_minimum_size = Vector2(380, 0)
		_example_text.add_theme_font_override("normal_font", preload("res://scenes/ui/common/ui_art.gd").mono())
		_example_text.add_theme_font_size_override("normal_font_size", 17)
		_example_text.add_theme_color_override("default_color", Color(0.85, 0.95, 0.78))
		v.add_child(_example_text)
		_root.add_child(_example_card)
	_example_card.visible = code != ""
	if code != "":
		_example_text.text = code
		_example_card.reset_size()


func _place_example() -> void:
	if _example_card == null or not _example_card.visible:
		return
	_example_card.reset_size()
	var q_top := _quest.position.y if _quest.visible else _box.position.y
	_example_card.position = Vector2(_box.position.x + BOX_W - _example_card.size.x - 10, q_top - _example_card.size.y - 10)

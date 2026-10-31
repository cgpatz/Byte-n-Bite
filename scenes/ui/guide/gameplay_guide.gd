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
const BOX_W := 1040.0
## Put in an empty editor for the "Press Run" quest (a program that surely runs).
const STARTER := "// Chef Miso's first program for you\nvoid main() {\n    printf(\"Hi, I'm %s! Off to the fridge.\\n\");\n    go_to(FRIDGE);\n}\n"
const BOX_H := 236.0

var game: Node
var _steps: Array = []
var _i := -1
var _level := 0
var _waiting_click := false
var _ran := false
var _zoom_before := 0
var _win_before := Transform2D()
var _rect_before := Rect2()
var _said_before := {}   # staff name -> what their thought bubble said at step start
var _start_pos := Vector2.ZERO
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


## Plays the guide for a restaurant level; returns when every step is done.
func run(level: int) -> void:
	_steps = steps_for(level)
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
		if st.get("until") in ["win_moved", "win_resized"]:
			var wf: Control = _step_window().frame
			_win_before = Transform2D(0.0, wf.scale, 0.0, wf.position)
		if st.get("until") == "zoomed":
			_zoom_before = SettingsManager.code_font_size
		if st.get("until") == "resized":
			_rect_before = game.programming_panel._current_rect()
		if st.get("until") == "talked":
			_said_before = _speech_texts()
		if st.get("until") == "ran":
			_ran = false
			var ce: CodeEdit = game.programming_panel.code_edit
			if ce.text.strip_edges() == "":
				ce.text = STARTER % _first_staff()
		_quest.show()
		_quest_text.text = "[b]Quest:[/b] " + st.do
		_pop(_quest)
	else:
		_quest.hide()
	_type(st.get("say", st.get("do", "")))
	_more.text = "▼ Click or press Space" if _waiting_click else "Do the quest to continue"


func _end() -> void:
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
	_target_rect = _target(_point)
	_arrow.visible = _target_rect.size != Vector2.ZERO or _target_rect.position != Vector2.ZERO
	_arrow.queue_redraw()


func _met(cond: String) -> bool:
	match cond:
		"moved":
			return game.manager.global_position.distance_to(_start_pos) > 140.0
		"panel_open":
			return game.programming_panel.visible
		"win_moved":
			return _step_window().frame.position.distance_to(_win_before.origin) > 30.0
		"win_resized":
			return absf(_step_window().frame.scale.x - _win_before.get_scale().x) > 0.04
		"zoomed":
			return SettingsManager.code_font_size != _zoom_before
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
	if id.begins_with("hud:"):
		var b: Control = hud.window_buttons.get(id.substr(4))
		return b.get_global_rect() if b and b.is_visible_in_tree() else Rect2()
	match id:
		"manager":
			return _world_rect(game.manager, Vector2(0, -24))
		"staff":
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
			return Rect2(40, 240, 300, 40)
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
	var x := (vs.x - BOX_W) * 0.5
	if game.programming_panel.visible:
		x = 24.0
	_box.position = _box.position.lerp(Vector2(x, vs.y - BOX_H - 20), 0.25)
	_quest.position = Vector2(x + 200, vs.y - BOX_H - 20 - 66)


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

func _build_box() -> void:
	_box = PanelContainer.new()
	_box.size = Vector2(BOX_W, BOX_H)
	_box.custom_minimum_size = Vector2(BOX_W, BOX_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.11, 0.08, 0.97)
	sb.border_color = Color(0.93, 0.72, 0.38)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.content_margin_left = 16
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	_box.add_theme_stylebox_override("panel", sb)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.gui_input.connect(_on_box_input)
	_root.add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	var face := TextureRect.new()
	face.texture = load(MENTOR) if ResourceLoader.exists(MENTOR) else null
	face.custom_minimum_size = Vector2(134, 182)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	row.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var name_plate := Label.new()
	name_plate.text = "Chef Miso"
	name_plate.add_theme_font_size_override("font_size", 26)
	name_plate.add_theme_color_override("font_color", Color(1, 0.8, 0.45))
	name_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_plate)
	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 18)
	_step_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.55))
	head.add_child(_step_label)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 23)
	_text.add_theme_font_size_override("bold_font_size", 23)
	_text.add_theme_color_override("default_color", Color(1, 0.95, 0.86))
	_text.add_theme_constant_override("line_separation", 4)
	v.add_child(_text)
	_more = Label.new()
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_font_size_override("font_size", 18)
	_more.add_theme_color_override("font_color", Color(1, 0.8, 0.45))
	v.add_child(_more)
	var vs := Vector2(1920, 1080)
	_box.position = Vector2((vs.x - BOX_W) * 0.5, vs.y - BOX_H - 20)


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


func steps_for(level: int) -> Array:
	var who := _first_staff()
	match level:
		1:
			return [
				{"say": "Welcome to [b]Byte n' Bite[/b], chef! I'm [b]Chef Miso[/b]. You run this little stall, and your staff cook whatever you [b]program[/b] them to do in C. Let me show you around!"},
				{"do": "Move around with [b]WASD[/b] or the [b]arrow keys[/b].", "say": "That cat in the apron is you, the [b]Manager[/b]. Take a little walk: use [b]WASD[/b] or the [b]arrow keys[/b].", "until": "moved", "point": "manager"},
				{"say": "See the [b]thought bubble[/b] over your head when you stand next to something? It tells you what pressing [b]E[/b] will do."},
				{"do": "Walk up to %s and press [b]E[/b]." % who, "say": "This is [b]%s[/b], your cook. Walk up to %s and press [b]E[/b] to open %s program." % [who, who, "her" if who == "Jane" else "their"], "until": "panel_open", "point": "staff"},
				{"say": "This is the [b]code editor[/b]. You write C here. Under it, the [b]Output[/b] box shows printf messages and mistakes (with the line number)."},
				{"say": "Three buttons control the code: [b]Run[/b] starts it from the top, [b]Stop[/b] freezes %s on the current line, and [b]Continue[/b] goes on from where it stopped." % who},
				{"do": "Press [b]Run[/b].", "say": "Let's see it work. If the editor was empty, I wrote a tiny program for you. Press [b]Run[/b]!", "until": "ran", "point": "run"},
				{"say": "See the [b]thought bubble[/b] over %s's head? Whatever [b]printf[/b] prints, %s [b]says out loud[/b]. That's how your staff talk to customers!" % [who, who], "point": "staff"},
				{"do": "Change the words inside printf(\"...\") and press [b]Run[/b].", "say": "Your turn: change the words inside [b]printf(\"...\")[/b], for example [b]printf(\"Welcome to Byte n' Bite!\\n\");[/b], then press [b]Run[/b] to hear %s say it." % who, "until": "talked", "point": "run"},
				{"say": "You can set the editor up the way you like. Drag its [b]title bar[/b] to move it anywhere on the screen.", "point": "editor_title"},
				{"do": "Drag the [b]corner grip[/b] (bottom right) to resize the editor.", "say": "Too big or too small? Drag the [b]corner grip[/b] at the bottom right of the editor to make the whole window bigger or smaller.", "until": "resized", "point": "grip"},
				{"do": "Hold [b]Ctrl[/b] and scroll the [b]mouse wheel[/b] over the code.", "say": "You can zoom the code too: hold [b]Ctrl[/b] and scroll the [b]mouse wheel[/b] over the code ([b]Ctrl+0[/b] puts it back). The Lessons, Recipe Book, Library and Stats windows resize with their corner grip as well.", "until": "zoomed", "point": "code"},
				{"do": "Close the editor ([b]Close[/b] or [b]Esc[/b]).", "say": "Nice! %s keeps working even after you close the editor. Close it now." % who, "until": "panel_closed"},
				{"say": "Customers order [b]Today's Special[/b] (the gold button at the top left). Orders appear on the [b]Order board[/b] at the bottom right.", "point": "board"},
				{"say": "Cooking uses ingredients. When they run out, a notice pops up and you buy more at the [b]Night Market[/b]. Every new game starts with [b]20 coins[/b], so spend wisely!"},
				{"do": "Open the Night Market ([b]M[/b], the market icon, or the back door).", "say": "Let's visit the market. Press [b]M[/b], click the market icon, or walk out the back door.", "until": "market", "point": "hud:market"},
				{"say": "Walk to a stall and press [b]E[/b] to shop. Use [b]+ / -[/b] or click the number and type how many you want."},
				{"say": "A [b]delivery truck[/b] brings what you buy to the delivery area by the back door. Walk to the crates and press [b]E[/b] to put them away."},
				{"do": "Go back to the restaurant (the glowing pad or [b]M[/b]).", "say": "Step on the glowing pad, or press [b]M[/b], to go back to the restaurant.", "until": "back", "point": "hud:market"},
				{"say": "The icons at the top right open everything: Market [b]M[/b], Lessons [b]T[/b], Recipe Book [b]R[/b], Library [b]L[/b], Stats [b]Tab[/b] and Pause [b]Esc[/b]. Hover one to see its name.", "point": "buttons"},
				{"say": "Your [b]goals[/b] are at the top left. Finish them, then upgrade the restaurant at the [b]chalkboard[/b]. Every new level teaches new C, and I'll show you what's new.", "point": "goals"},
				{"say": "One challenge is [b]Talk to the customer[/b]: after serve(), use printf so %s says the dish with [b]%%s[/b] and its price with [b]%%.2f[/b], like [b]printf(\"Here's your %%s, for a price of %%.2f\\n\", dish, price);[/b]" % who, "point": "goals"},
				{"do": "Press [b]T[/b] to open your first C lesson.", "say": "Last thing: your first C lesson! Press [b]T[/b] or click the cap icon.", "until": "lessons", "point": "hud:tutorial"},
				{"say": "This is a [b]window[/b]. Every window (Lessons, Recipe Book, Library, Stats and the code editor) can be moved and resized, so you can set up your screen your way."},
				{"do": "Drag the Lessons window (hold on its wooden frame) to move it.", "say": "Hold the mouse on the window's [b]wooden frame[/b] (not on a button) and [b]drag[/b] it somewhere else.", "until": "win_moved"},
				{"do": "Drag the [b]corner grip[/b] (bottom right) to resize the Lessons window.", "say": "Now drag the [b]corner grip[/b] at the bottom right of the window to make it [b]bigger or smaller[/b].", "until": "win_resized", "point": "win_grip"},
				{"say": "The [b]Recipe Book (R)[/b], [b]Library (L)[/b], [b]Stats (Tab)[/b] and the [b]code editor[/b] work the same way, and the game remembers where you put them."},
				{"say": "Read a page, press [b]Try it[/b] to run the example, and answer the quick check to earn a [b]star[/b]. Have fun, chef!"},
			]
		2:
			return [
				{"say": "Welcome to the [b]Small Diner[/b]! From now on customers choose from the [b]whole menu[/b], so there's no more Today's Special."},
				{"say": "New customers show a [b]?[/b] bubble. Someone has to ask first: [b]take_order()[/b] walks over and returns the dish they want. Then use [b]if / else[/b] to cook the right one."},
				{"say": "Food can [b]burn[/b] now. [b]is_burnt()[/b] tells you, and [b]trash()[/b] throws it away at the TRASH."},
				{"do": "Open the Recipe Book ([b]R[/b]) to see the new dishes.", "say": "There are new dishes to learn. Open the [b]Recipe Book[/b] with [b]R[/b].", "until": "recipe_book", "point": "hud:recipe_book"},
				{"say": "Tip: like every window, the Recipe Book moves when you drag its frame and resizes with the [b]corner grip[/b].", "point": "rb_grip"},
				{"do": "Press [b]T[/b] for Lesson 2: Making Decisions.", "say": "Every dish lists its ingredients and where to cook them. Now press [b]T[/b] for your next lesson.", "until": "lessons", "point": "hud:tutorial"},
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
				{"do": "Open your Stats ([b]Tab[/b]) to check your staff.", "say": "More customers means more work. Check how your staff are doing in [b]Stats[/b] ([b]Tab[/b]). You can upgrade them there.", "until": "stats", "point": "hud:stats"},
				{"do": "Press [b]T[/b] for Lesson 4: Arrays.", "say": "Now for arrays. Press [b]T[/b].", "until": "lessons", "point": "hud:tutorial"},
			]
		5:
			return [
				{"say": "Welcome to the [b]Grand Restaurant[/b]! Programs get long here, so you'll write your [b]own functions[/b] and reuse them."},
				{"do": "Open your Library ([b]L[/b]).", "say": "Functions you save in the [b]Library[/b] can be used by every staff member. Open it with [b]L[/b].", "until": "library", "point": "hud:library"},
				{"do": "Drag the Library's [b]corner grip[/b] to resize it.", "say": "The Library is a window too: drag its [b]corner grip[/b] (bottom right) to make it bigger or smaller, and drag its frame to move it.", "until": "win_resized", "win": "library", "point": "lib_grip"},
				{"do": "Hold [b]Ctrl[/b] and scroll the [b]mouse wheel[/b] over the Library code.", "say": "Its code board zooms just like the staff code editor: hold [b]Ctrl[/b] and scroll the [b]mouse wheel[/b] over the code ([b]Ctrl+0[/b] resets).", "until": "zoomed", "point": "lib_code"},
				{"do": "Press [b]T[/b] for Lesson 5: Functions.", "say": "Tick a slot's [b]Use[/b] box to share it. Now press [b]T[/b] for the last lesson!", "until": "lessons", "point": "hud:tutorial"},
			]
	return []

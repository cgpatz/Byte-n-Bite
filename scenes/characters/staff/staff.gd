@tool
extends CharacterBody2D
class_name Staff
## Independently programmable staff member (FR-03). Runs the C program the
## player writes: the C interpreter calls run_builtin() for kitchen functions
## like go_to(GRILL), and this script walks, picks up, cooks and serves.
## Placeholder look: a circle. Art is loaded automatically from
## assets/character/staff/<name>_sheet.png (walk sheet) or <name>.png, e.g.
## jane_sheet.png — see assets/ART_GUIDE.md.

signal program_requested(staff: Staff)
## New console text (BBCode) for the programming panel.
signal log_added(text: String)
signal running_changed(running: bool)
## The line of C code being run right now (1-based).
signal line_changed(line: int)
signal error_at(line: int, msg: String)
signal _arrived

const CInterpreter := preload("res://systems/c_interpreter/c_interpreter.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const PixelArt := preload("res://scenes/art/pixel_art.gd")
const Progression := preload("res://data/progression/progression.gd")

@export var staff_name := "Jane":
	set(v):
		staff_name = v
		_refresh_art()
		queue_redraw()
@export var color := Color(0.45, 0.75, 0.95):
	set(v):
		color = v
		queue_redraw()
## Character image for just this staff member (optional). Normally found
## automatically by name in assets/character/staff/.
@export var art: Texture2D:
	set(v):
		art = v
		_refresh_art()
@export var show_name := true:
	set(v):
		show_name = v
		queue_redraw()
## Staff level (1–10, bought with coins) and the Lv 10 specialization.
## Kept in GameState; synced in _ready() and on GameState.staff_upgraded.
@export var level := 1
var specialization := ""
@export var move_speed := 180.0

const RADIUS := 22.0
## How close (px) to a station's edge counts as "at" it.
const REACH := 40.0
## Used when a station can't be reached that closely (e.g. a door set in a wall).
const FAR_REACH := 80.0
## Seconds for quick actions.
const PICK_TIME := 0.4
const COMBINE_TIME := 0.8
const SERVE_TIME := 0.5
const MAX_LOG_CHARS := 12000

## The player's C code for this staff member.
## The staff member's C program. New games start with an empty editor.
var program_source := ""

## Set by Game: find_path(), get_station(), on_dish_served(), level_display_name().
var world: Node
## What's in the hands: {} or {"id": int, "cooked": bool}
var held := {}:
	set(v):
		held = v
		queue_redraw()
## This staff member's plate at the ASSEMBLY table: {"RICE": 1, "EGG": 1}
var plate_items := {}
## Console history (BBCode), so reopening the panel shows past output.
var log_text := ""
var busy_text := "":
	set(v):
		busy_text = v
		queue_redraw()

var _interp: CInterpreter
var _path := PackedVector2Array()
var _at_station := ""
## Station this staff member is walking to or working at (for sharing work spots).
var _going_to := ""
var _stop_requested := false
var _sprite: Sprite2D
var _anim_time := 0.0
var _last_pos := Vector2.ZERO
## Work animation: "" (none), "pick", "cook", "plate", "assemble", "serve", "trash".
var _action := ""
var _action_t := 0.0
## Where the work happens (world position), for facing it and drawing effects.
var _action_at := Vector2.ZERO


## printf() also shows above the staff member's head as a thought bubble.
const SpeechBubble := preload("res://scenes/characters/staff/speech_bubble.gd")
var _speech: Node2D


func _say(t: String) -> void:
	if _speech == null:
		_speech = SpeechBubble.new()
		_speech.name = "Speech"
		add_child(_speech)
	_speech.position = Vector2(0, _art_top() - 40)
	_speech.add_output(t)


func _ready() -> void:
	if not Engine.is_editor_hint() and GameState.staff_programs.has(staff_name):
		program_source = GameState.staff_programs[staff_name]  # from the save file
	if not Engine.is_editor_hint():
		collision_mask = 0  # staff follow paths; they don't get pushed around
		_sync_level()
		GameState.staff_upgraded.connect(func(n: String, _l: int, _s: String):
			if n == staff_name:
				_sync_level())
	_refresh_art()
	queue_redraw()


func _sync_level() -> void:
	level = GameState.staff_level(staff_name)
	specialization = GameState.staff_spec(staff_name)
	queue_redraw()


## Coin multiplier for dishes this staff member serves (upgrades, Cashier).
func profit_mult() -> float:
	return Progression.staff_profit_mult(level, specialization)


## Finds this staff member's art and sets up the sprite (drawn behind the
## name and held-item labels).
func _refresh_art() -> void:
	if not is_inside_tree():
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.show_behind_parent = true
		add_child(_sprite)
	var tex: Texture2D = art if art else PixelArt.character("character/staff", staff_name)
	PixelArt.setup_character(_sprite, tex, RADIUS)
	queue_redraw()


## Top of the character on screen (for the name tag).
func _art_top() -> float:
	if _sprite and _sprite.texture:
		var frame_h := float(_sprite.texture.get_height()) / _sprite.vframes
		var blank := PixelArt.blank_rows_top(_sprite.texture, int(frame_h))
		return RADIUS - (frame_h - blank) * PixelArt.SCALE
	return -RADIUS


func _draw() -> void:
	var has_art := _sprite != null and _sprite.texture != null
	if not has_art:
		draw_circle(Vector2.ZERO, RADIUS, color)
		draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 32, color.darkened(0.6), 4.0)
	if _action != "":
		_draw_action()
	var font := ThemeDB.fallback_font
	var top := _art_top()
	var bottom := RADIUS
	if show_name:
		var tag := staff_name if level <= 1 else "%s · Lv %d" % [staff_name, level]
		_draw_centered(font, tag, Vector2(0, top - 12), 18, Color.WHITE if level < Progression.MAX_STAFF_LEVEL else Color(1, 0.85, 0.4))
	if not held.is_empty():
		_draw_held(font)
	if busy_text != "":
		_draw_centered(font, busy_text, Vector2(0, bottom + 22), 15, Color(1.0, 0.85, 0.45))
	elif not plate_items.is_empty() and _at_station == "ASSEMBLY":
		_draw_centered(font, "plate: " + Kitchen.describe_plate(plate_items), Vector2(0, bottom + 22), 15, Color(0.85, 0.95, 1.0))


## What's in the hands: the food icon if there is one (assets/food/), else a text tag.
func _draw_held(font: Font) -> void:
	var name_id := Kitchen.name_of(held.id)
	var icon := PixelArt.food_icon(name_id, held.get("cooked", false), Kitchen.is_dish(held.id))
	if icon:
		var sc := float(PixelArt.SCALE)
		var at := Vector2(RADIUS - 6, -icon.get_height() * sc / 2.0)
		draw_set_transform(at, 0.0, Vector2(sc, sc))
		draw_texture(icon, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
		return
	var label := Kitchen.describe(held)
	var fs := 15
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12
	var box := Rect2(Vector2(RADIUS - 4, -10), Vector2(w, 22))
	draw_rect(box, Color(1.0, 0.93, 0.75))
	draw_rect(box, Color(0.35, 0.22, 0.12), false, 2.0)
	draw_string(font, box.position + Vector2(6, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.25, 0.15, 0.08))


func _draw_centered(font: Font, text: String, at: Vector2, fs: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := at - Vector2(w / 2.0, 0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_animate(delta)
	if paused or _path.is_empty():
		return
	var step := move_speed * Progression.staff_walk_mult(level, specialization) * delta
	while step > 0.0 and not _path.is_empty():
		var d := global_position.distance_to(_path[0])
		if d <= step:
			global_position = _path[0]
			_path.remove_at(0)
			step -= d
		else:
			global_position = global_position.move_toward(_path[0], step)
			step = 0.0
	if _path.is_empty():
		_arrived.emit()


func _animate(delta: float) -> void:
	if _action != "":
		_action_t += delta
		queue_redraw()
	if _sprite == null or _sprite.texture == null:
		return
	_anim_time += delta
	var v := (global_position - _last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	PixelArt.animate_character(_sprite, v, _anim_time)
	# Working: a little bounce while busy at a station.
	_sprite.position.y = -absf(sin(_action_t * 11.0)) * 6.0 if _action != "" else 0.0


## Turns to look at a point (uses the walk sheet's rows).
func _face(point: Vector2) -> void:
	if _sprite == null or _sprite.texture == null or _sprite.vframes != 4:
		return
	var d := point - global_position
	var row: int
	if absf(d.x) > absf(d.y):
		row = PixelArt.Facing.RIGHT if d.x > 0 else PixelArt.Facing.LEFT
	else:
		row = PixelArt.Facing.DOWN if d.y > 0 else PixelArt.Facing.UP
	_sprite.frame_coords = Vector2i(0, row)


## Plays a work animation for `seconds` (ends early if the program stops).
func _act(kind: String, seconds: float, text := "", at = null) -> void:
	if at != null:
		_action_at = at
	else:
		var st: Station = world.get_station(_at_station) if world and _at_station != "" else null
		_action_at = st.global_position if st else global_position + Vector2(0, -30)
	_face(_action_at)
	_action = kind
	_action_t = 0.0
	busy_text = text
	var work := "take" if text.begins_with("taking the order") else kind
	if kind == "cook" and _at_station in Progression.CAFE_STATIONS:
		work = "brew"
	await _sleep(seconds * Progression.staff_work_mult(level, specialization, work))
	_action = ""
	busy_text = ""
	queue_redraw()


## Effects for the work animation: steam when cooking, sparkles otherwise.
func _draw_action() -> void:
	var at := _action_at - global_position
	var t := _action_t
	if _action == "cook":
		for i in 3:
			var k := fmod(t * 0.9 + i / 3.0, 1.0)
			var p := at + Vector2((i - 1) * 14 + sin(t * 3.0 + i) * 4, -20 - k * 46)
			draw_circle(p, 6 + k * 6, Color(1, 1, 1, 0.55 * (1.0 - k)))
		draw_circle(at + Vector2(0, -8), 5 + absf(sin(t * 9.0)) * 3, Color(1.0, 0.55, 0.15, 0.7))
		return
	var col: Color = {"pick": Color(0.6, 0.9, 1.0), "plate": Color(1, 0.95, 0.6), "assemble": Color(1, 0.85, 0.3),
		"serve": Color(1, 0.6, 0.7), "trash": Color(0.7, 0.7, 0.7)}.get(_action, Color.WHITE)
	var mid := at.lerp(Vector2.ZERO, 0.5)
	for i in 4:
		var ang := t * 4.0 + i * TAU / 4.0
		var p := mid + Vector2(cos(ang), sin(ang)) * (14 + sin(t * 8.0) * 4)
		draw_line(p - Vector2(4, 0), p + Vector2(4, 0), col, 2.0)
		draw_line(p - Vector2(0, 4), p + Vector2(0, 4), col, 2.0)


# --- Interaction ---------------------------------------------------------------

func can_interact() -> bool:
	return true


func get_prompt() -> String:
	return "Program %s" % staff_name


func interact(_by: Node) -> String:
	program_requested.emit(self)
	return ""


# --- Running programs ------------------------------------------------------------

func is_running() -> bool:
	return _interp != null


## Compiles and runs program_source. Await it or fire-and-forget.
func run_program() -> void:
	if is_running() or Engine.is_editor_hint():
		return
	_stop_requested = false
	var interp := CInterpreter.new()
	interp.host = self
	interp.output.connect(func(t: String):
		_log(t.replace("[", "[lb]"), false)
		_say(t))
	if _speech:
		_speech.clear()
	run_trace = {"served": 0, "printfs": [], "stats": interp.stats, "dishes": {}, "tickets": 0}
	interp.line_changed.connect(func(l: int):
		_current_line = l
		line_changed.emit(l))
	if not Engine.is_editor_hint():
		GameState.staff_programs[staff_name] = program_source
	if not interp.compile(program_source, GameState.library_slots):
		_log("[color=#b9a58a]▶ %s reads the program...[/color]" % staff_name)
		_report_error(interp.error)
		return
	_log("[color=#b9a58a]▶ %s starts working (hands and plate cleared).[/color]" % staff_name)
	held = {}
	plate_items = {}
	_interp = interp
	running_changed.emit(true)
	if world and world.has_method("reserve_special_order"):
		world.reserve_special_order(self)
	await interp.run()
	if world and world.has_method("release_claims"):
		world.release_claims(self)
	_path.clear()
	busy_text = ""
	if _stop_requested:
		_log("[color=#b9a58a]■ Stopped.[/color]")
	elif not interp.error.is_empty():
		_report_error(interp.error)
	else:
		_log("[color=#9fd67a]✔ Program finished.[/color]")
	_interp = null
	running_changed.emit(false)


func stop_program() -> void:
	if paused:
		paused = false
		paused_changed.emit(false)
	if _interp:
		_stop_requested = true
		_interp.stop()
		_path.clear()
		_arrived.emit()


## Code editor "Stop": freezes the program (and the staff member) at the
## current line. "Continue" resumes from there.
var paused := false
var _current_line := 0
signal paused_changed(paused: bool)


func pause_program() -> void:
	if _interp == null or paused:
		return
	paused = true
	_interp.paused = true
	_log("[color=#e8b04a]⏸ %s stopped at line %d. Press Continue to go on from here.[/color]" % [staff_name, _current_line])
	paused_changed.emit(true)
	queue_redraw()


func resume_program() -> void:
	if not paused:
		return
	paused = false
	if _interp:
		_interp.paused = false
	_log("[color=#9fd36a]▶ %s continues.[/color]" % staff_name)
	paused_changed.emit(false)
	queue_redraw()


## Run while a program is already running: stop it, then start again from the top.
func restart_program() -> void:
	if is_running():
		stop_program()
		while is_running():
			await get_tree().process_frame
	run_program()


## Called on level change: forget position-based state and empty the hands.
func reset_work() -> void:
	stop_program()
	held = {}
	plate_items = {}
	_at_station = ""
	_going_to = ""
	busy_text = ""


func clear_log() -> void:
	log_text = ""


func _report_error(err: Dictionary) -> void:
	var line: int = err.get("line", 0)
	var msg := String(err.get("msg", "")).replace("[", "[lb]")
	if line >= CInterpreter.LIBRARY_LINE_OFFSET:
		var info := CInterpreter.library_line_info(line)
		var slot_name := "Slot %d" % (info.slot + 1)
		if info.slot < GameState.library_slots.size():
			slot_name = GameState.library_slots[info.slot].name
		_log("[color=#ff7a6a]Library \"%s\", line %d: %s[/color]" % [slot_name, info.line, msg])
		error_at.emit(-1, err.get("msg", ""))
		return
	_log("[color=#ff7a6a]Line %d: %s[/color]" % [line, msg])
	error_at.emit(line, err.get("msg", ""))


func _log(text: String, newline := true) -> void:
	if newline and log_text != "" and not log_text.ends_with("\n"):
		text = "\n" + text
	if newline:
		text += "\n"
	log_text += text
	if log_text.length() > MAX_LOG_CHARS:
		log_text = log_text.substr(log_text.length() - MAX_LOG_CHARS)
		var cut := log_text.find("\n")
		if cut >= 0:
			log_text = log_text.substr(cut + 1)
	log_added.emit(text)


# --- Host API for the C interpreter -------------------------------------------------

## For cook_station(): a station in this restaurant that cooks the ingredient.
## What this Run has done so far, for level challenges (systems/challenges/level_challenges.gd).
var run_trace := {"served": 0, "printfs": [], "stats": {}, "dishes": {}, "tickets": 0}


## Called by the interpreter after each printf.
func note_printf(items: Array, _text: String) -> void:
	run_trace.printfs.append({"items": items, "served_before": run_trace.served})
	if world and world.has_method("check_challenges"):
		world.check_challenges(self)


## orders(list): the dishes on the counter's tickets, oldest first.
func counter_tickets() -> Array:
	return world.counter_tickets() if world and world.has_method("counter_tickets") else []


## take_order(): walk to the customer who has waited longest, hear the order and
## return the dish. Test orders without a customer are taken on the spot.
func _do_take_order() -> Dictionary:
	if world == null or not world.has_method("reserve_order_to_take"):
		var menu := Kitchen.menu(restaurant_level(), GameState.cafe_step)
		return {"value": Kitchen.id_of(menu[randi() % menu.size()])}
	var order: Dictionary = world.reserve_order_to_take(self)
	if order.is_empty():
		return {"value": Kitchen.NOTHING}
	var customer = order.customer
	if customer != null and is_instance_valid(customer):
		var res: Dictionary = world.path_to_point(global_position, customer.seat.pos)
		if res.ok:
			_at_station = ""
			busy_text = "→ " + customer.customer_name
			_path = res.points
			if not _path.is_empty():
				await _arrived
			busy_text = ""
		if _stop_requested:
			world.cancel_taking(order)
			return {"value": Kitchen.NOTHING}
		if not is_instance_valid(customer) or not order in world.orders:
			_log("[color=#b9a58a]The customer left before ordering.[/color]")
			return {"value": Kitchen.NOTHING}
		await _act("pick", PICK_TIME, "taking the order...", customer.global_position)
	var id: int = world.finish_taking(order, self)
	_log("[color=#b9a58a]Order: %s[/color]" % Kitchen.title_of(order.dish))
	return {"value": id}


func cook_station_for(ing: String) -> int:
	for st in Kitchen.cook_stations(ing):
		if world and world.get_station(st) != null:
			return Kitchen.id_of(st)
	return Kitchen.NOTHING


func restaurant_level() -> int:
	return GameState.restaurant_level


## Waits `seconds`, ending early if the program is stopped.
func _sleep(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _stop_requested:
		var chunk := minf(left, 0.1)
		await get_tree().create_timer(chunk, false).timeout
		if not paused:
			left -= chunk


func _here_name() -> String:
	return world.level_display_name() if world else "restaurant"


func _need_station(want: String, fn: String) -> String:
	if _at_station == want:
		return ""
	var where := "not at any station" if _at_station == "" else "at the %s" % _at_station
	return "%s() only works at the %s, but %s is %s. Use go_to(%s); first." % [fn, want, staff_name, where, want]


func run_builtin(fname: String, args: Array, _line: int) -> Dictionary:
	match fname:
		"go_to", "move_to":
			return await _do_move_to(int(args[0]))
		"pick_up":
			return await _do_pick_up(int(args[0]))
		"cook":
			return await _do_cook()
		"plate":
			return await _do_plate()
		"assemble":
			return await _do_assemble(int(args[0]))
		"serve":
			return await _do_serve()
		"wait":
			var s := float(args[0])
			if s < 0 or s > 60:
				return {"error": "wait() takes 0 to 60 seconds."}
			busy_text = "waiting..."
			await _sleep(s)
			busy_text = ""
			return {"value": 0}
		"holding":
			return {"value": held.get("id", Kitchen.NOTHING)}
		"trash":
			var e := _need_station("TRASH", "trash")
			if e != "":
				return {"error": e}
			if held.is_empty():
				return {"error": "%s's hands are empty, so there's nothing to trash." % staff_name}
			await _act("trash", PICK_TIME, "throwing away...")
			held = {}
			return {"value": 0}
		"take_order", "next_order":
			return await _do_take_order()
		"has_order":
			if world and world.has_method("has_order"):
				return {"value": 1 if world.has_order(self) else 0}
			return {"value": 1}
		"post_order":
			var dish_id := int(args[0])
			if not Kitchen.is_dish(dish_id):
				var nm := Kitchen.name_of(dish_id)
				return {"error": "post_order() needs a dish like EGGSILOG, but got %s." % (nm if nm != "" else str(dish_id))}
			var e := _need_station("SERVING_COUNTER", "post_order")
			if e != "":
				return {"error": e}
			if world == null:
				return {"value": 0}
			var dname := Kitchen.name_of(dish_id)
			await _act("plate", PICK_TIME, "ticket posted")
			var ticket: int = world.post_order(self, dname)
			if ticket == 0:
				return {"error": "%s hasn't taken an order for %s. Call take_order() first and post the dish it gives you." % [staff_name, Kitchen.title_of(dname)]}
			_log("[color=#b9a58a]Ticket #%d: %s[/color]" % [ticket, Kitchen.title_of(dname)])
			return {"value": ticket}
		"check_counter":
			if world == null:
				return {"value": Kitchen.NOTHING}
			if _at_station != "SERVING_COUNTER":
				var r: Dictionary = await _do_move_to(Kitchen.id_of("SERVING_COUNTER"))
				if r.has("error") or _stop_requested:
					return r if r.has("error") else {"value": Kitchen.NOTHING}
			var got: int = world.check_counter(self)
			if got != Kitchen.NOTHING:
				run_trace.tickets += 1
				await _act("pick", PICK_TIME, "reading the ticket")
			return {"value": got}
		"stock":
			var nm := Kitchen.name_of(int(args[0]))
			if not Kitchen.is_item(int(args[0])):
				return {"error": "stock() needs an ingredient like EGG, but got %s." % (nm if nm != "" else str(args[0]))}
			return {"value": GameState.stock_of(nm)}
		"is_burnt":
			return {"value": 1 if held.get("burnt", false) else 0}
		"doneness":
			return {"value": 100 if held.get("cooked", false) else 0}
		"flip":
			var e := _need_station("GRILL", "flip")
			if e != "":
				return {"error": e}
			await _act("cook", PICK_TIME, "flipping...")
			return {"value": 0}
	return {"error": "%s() isn't ready yet." % fname}


func _do_move_to(id: int) -> Dictionary:
	if not Kitchen.is_station(id):
		var nm := Kitchen.name_of(id)
		if nm != "" and nm != "NOTHING":
			return {"error": "%s isn't a station. go_to() needs a place like FRIDGE or GRILL." % nm}
		return {"error": "go_to() needs a station name like GRILL, but got %d." % id}
	var sname := Kitchen.name_of(id)
	if world == null:
		return {"error": "%s isn't in a restaurant." % staff_name}
	var station: Station = world.get_station(sname)
	if station == null:
		return {"error": "There is no %s in the %s." % [sname, _here_name()]}
	# Stand exactly in front of (below) the station; fall back to "near it"
	# for places like a door set in a wall.
	_going_to = ""
	var spot: Dictionary = world.work_spot(station, self) if world.has_method("work_spot") else {"ok": false}
	_going_to = sname
	var points := PackedVector2Array()
	if spot.ok:
		points = spot.path
	else:
		var res: Dictionary = world.find_path(global_position, station, REACH)
		if not res.ok:
			res = world.find_path(global_position, station, FAR_REACH)
		if not res.ok:
			return {"error": "%s can't find a way to the %s." % [staff_name, sname]}
		points = res.points
	_at_station = ""
	busy_text = "→ " + sname
	_path = points
	if not _path.is_empty():
		await _arrived
	busy_text = ""
	if _stop_requested:
		return {"value": 0}
	_at_station = sname
	_face(station.global_position)
	queue_redraw()
	return {"value": 0}


func _do_pick_up(id: int) -> Dictionary:
	if not Kitchen.is_item(id):
		var nm := Kitchen.name_of(id)
		if Kitchen.is_dish(id):
			return {"error": "%s is a dish. Make it with plate() and assemble(%s)." % [nm, nm]}
		return {"error": "pick_up() needs an ingredient like EGG, but got %s." % (nm if nm != "" else str(id))}
	var iname := Kitchen.name_of(id)
	var why := Kitchen.available(iname, restaurant_level(), GameState.cafe_step)
	if why != "":
		return {"error": why}
	if _at_station == "":
		return {"error": "%s is not at a station. Use go_to(FRIDGE); first." % staff_name}
	if not held.is_empty():
		return {"error": "%s's hands are full (holding %s). plate() it first." % [staff_name, Kitchen.describe(held)]}
	var storage: Array = Kitchen.STORAGE.get(_at_station, [])
	if not iname in storage:
		var where: Array = []
		for st in Kitchen.STORAGE:
			if iname in Kitchen.STORAGE[st] and world and world.get_station(st) != null:
				where.append(st)
		return {"error": "There's no %s at the %s. Try the %s." % [iname, _at_station, " or ".join(where) if not where.is_empty() else "FRIDGE"]}
	if not GameState.take_ingredient(iname):
		if world and world.has_method("note_out_of_stock"):
			world.note_out_of_stock(iname, staff_name)
		return {"error": "Out of %s! The manager has to buy more at the Market (back door or M) and claim the crates in the delivery area. Tip: check stock(%s) first." % [iname.capitalize(), iname]}
	await _act("pick", PICK_TIME, "picking up...")
	if not _stop_requested:
		held = {"id": id, "cooked": false}
	return {"value": 0}


func _do_cook() -> Dictionary:
	if not Kitchen.COOKING.has(_at_station):
		var where := "not at a station" if _at_station == "" else "at the %s" % _at_station
		return {"error": "cook() needs a cooking station like the GRILL, but %s is %s." % [staff_name, where]}
	if held.is_empty():
		return {"error": "%s isn't holding anything to cook. pick_up() an ingredient first." % staff_name}
	if not Kitchen.is_item(held.id):
		return {"error": "The %s is already a finished dish." % Kitchen.name_of(held.id)}
	var iname := Kitchen.name_of(held.id)
	if held.get("cooked", false):
		return {"error": "The %s is already cooked." % iname}
	if not iname in Kitchen.NEEDS_COOKING:
		return {"error": "%s is served fresh. No need to cook it: just plate() it." % iname}
	if not iname in Kitchen.COOKING[_at_station]:
		var where := ""
		for st in Kitchen.COOKING:
			if iname in Kitchen.COOKING[st] and world.get_station(st) != null:
				where = " Cook it at the %s." % st
				break
		return {"error": "The %s can't cook %s.%s" % [_at_station, iname, where]}
	await _act("cook", Kitchen.COOK_TIME.get(_at_station, 2.0),
		{"brew": "brewing...", "bake": "baking...", "fry": "frying..."}.get(Kitchen.COOK_VERB.get(_at_station, "cook"), "cooking..."))
	if not _stop_requested:
		held = {"id": held.id, "cooked": true}
	return {"value": 0}


func _do_plate() -> Dictionary:
	var e := _need_station("ASSEMBLY", "plate")
	if e != "":
		return {"error": e}
	if held.is_empty():
		return {"error": "%s isn't holding anything to put on the plate." % staff_name}
	var iname := Kitchen.name_of(held.id)
	if not Kitchen.is_item(held.id):
		return {"error": "%s is already a dish. Take it to the SERVING_COUNTER and serve()." % iname}
	if iname in Kitchen.NEEDS_COOKING and not held.get("cooked", false):
		return {"error": "The %s is raw! cook() it before plating." % iname}
	await _act("plate", PICK_TIME, "plating...")
	if _stop_requested:
		return {"value": 0}
	plate_items[iname] = plate_items.get(iname, 0) + 1
	held = {}
	queue_redraw()
	return {"value": 0}


func _do_assemble(id: int) -> Dictionary:
	var e := _need_station("ASSEMBLY", "assemble")
	if e != "":
		return {"error": e}
	var dish := Kitchen.name_of(id)
	if not Kitchen.is_dish(id):
		return {"error": "assemble() needs a dish like EGGSILOG, but got %s." % (dish if dish != "" else str(id))}
	var why := Kitchen.available(dish, restaurant_level(), GameState.cafe_step)
	if why != "":
		return {"error": why}
	if not held.is_empty():
		return {"error": "%s's hands are full (holding %s). plate() it first." % [staff_name, Kitchen.describe(held)]}
	var recipe: Dictionary = Kitchen.DISHES[dish].recipe
	var problems: Array = []
	for ing in recipe:
		var have: int = plate_items.get(ing, 0)
		if have < recipe[ing]:
			problems.append("needs %d more %s" % [recipe[ing] - have, ing])
	for ing in plate_items:
		var extra: int = plate_items[ing] - recipe.get(ing, 0)
		if extra > 0:
			problems.append("has %d extra %s" % [extra, ing])
	if not problems.is_empty():
		return {"error": "The plate can't become %s yet: it %s. (Plate: %s)" % [dish, " and ".join(problems), Kitchen.describe_plate(plate_items)]}
	await _act("assemble", COMBINE_TIME, "assembling...")
	if not _stop_requested:
		plate_items = {}
		held = {"id": id, "cooked": true}
	return {"value": 0}


## serve(): carries the held dish to the customer who ordered it and hands it
## over. If nobody has ordered it yet, it is left on the SERVING_COUNTER.
func _served_one(dish := "") -> void:
	run_trace.served += 1
	if dish != "":
		run_trace.dishes[dish] = true
	if world and world.has_method("check_challenges"):
		world.check_challenges(self)


func _do_serve() -> Dictionary:
	if held.is_empty():
		return {"error": "%s has nothing to serve." % staff_name}
	if not Kitchen.is_dish(held.id):
		return {"error": "Only finished dishes can be served. %s is holding %s. Use assemble() first." % [staff_name, Kitchen.describe(held)]}
	if world == null:
		return {"error": "%s isn't in a restaurant." % staff_name}
	var dish := Kitchen.name_of(held.id)
	var order: Dictionary = world.claim_serving(self, dish)
	var customer = order.get("customer", null) if not order.is_empty() else null
	if customer != null and is_instance_valid(customer):
		var res: Dictionary = world.path_to_point(global_position, customer.seat.pos)
		if res.ok:
			_at_station = ""
			busy_text = "→ " + customer.customer_name
			_path = res.points
			if not _path.is_empty():
				await _arrived
			busy_text = ""
			if _stop_requested:
				world.unclaim_serving(order)
				return {"value": 0}
		await _act("serve", SERVE_TIME, "here you go!", customer.global_position)
		if _stop_requested:
			world.unclaim_serving(order)
			return {"value": 0}
		var earned: int = world.deliver_order(order, self)
		held = {}
		_served_one(dish)
		return {"value": earned}
	if not order.is_empty():  # an order without a customer (tests)
		var earned2: int = world.deliver_order(order, self)
		held = {}
		_served_one(dish)
		return {"value": earned2}
	# Nobody ordered it yet: leave it on the serving counter.
	if world.counter_full():
		return {"error": "Nobody ordered %s, and the serving counter is full. Use take_order() (or check_counter()) to cook what customers want." % dish}
	if _at_station != "SERVING_COUNTER":
		var r: Dictionary = await _do_move_to(Kitchen.id_of("SERVING_COUNTER"))
		if r.has("error") or _stop_requested:
			return r
	await _act("plate", SERVE_TIME, "on the counter")
	if _stop_requested:
		return {"value": 0}
	world.put_on_counter(dish)
	held = {}
	return {"value": 0}

extends Node2D
class_name Customer
## A customer: walks in, sits on a free chair or stool, orders a dish, waits,
## shows a "?" until a staff member takes the order (take_order()), then the
## dish; reacts with a face when served (FR-10, based on how long they waited),
## eats, then walks out.
## Art: assets/character/customers/<name>_sheet.png (walk sheet) and optional
## <name>_sit.png (3 frames: facing down, left, right). Any sheet added to that
## folder becomes a new customer automatically.

signal left_restaurant(customer: Customer)

const PixelArt := preload("res://scenes/art/pixel_art.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const ART_DIR := "res://assets/character/customers/"

enum State { WALK_IN, WAITING, EATING, WALK_OUT }
enum Mood { HAPPY, OKAY, ANNOYED }

const SPEED := 150.0
const FEET_Y := 20.0
const RADIUS := 20.0
## Waiting longer than these (seconds) changes the mood shown in the bubble.
const OKAY_AFTER := 25.0
const ANNOYED_AFTER := 50.0
## After waiting this long (seconds) without food, the customer gives up and
## leaves. Set per restaurant level by Game (CUSTOMER_PATIENCE).
const PATIENCE := 90.0
var patience := PATIENCE
const REACTION_TIME := 2.5
const EAT_TIME := 6.0

var customer_name := "Guest"
var state := State.WALK_IN
var seat: Dictionary = {}          # {pos, facing ("down"/"left"/"right"/"up"), cafe, key}
var dish := ""                     # what they ordered
var waited := 0.0
var mood := Mood.HAPPY
var reaction := -1                 # Mood shown after being served
## A staff member is carrying the food over: stop losing patience.
var food_coming := false
## Someone took the order (take_order()): the bubble shows the dish and
## patience drains at half speed (being seen calms customers down).
var order_taken := false
const TAKEN_PATIENCE_RATE := 0.5
var game: Node

var _path := PackedVector2Array()
var _sprite: Sprite2D
var _walk_tex: Texture2D
var _sit_tex: Texture2D
var _anim := 0.0
var _timer := 0.0
var _exit_pos := Vector2.ZERO
var _color := Color(0.7, 0.6, 0.9)


## All customer looks found in the customers folder (file stems, e.g. "bao").
static func available_looks() -> Array:
	var out: Array = []
	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		f = f.trim_suffix(".import").trim_suffix(".remap")
		if f.ends_with("_sheet.png"):
			var key := f.trim_suffix("_sheet.png")
			if not key in out:
				out.append(key)
	out.sort()
	return out


func setup(look: String, path: PackedVector2Array, target_seat: Dictionary, exit_pos: Vector2) -> void:
	customer_name = look.capitalize()
	seat = target_seat
	_path = path
	_path.append(seat.pos)
	_exit_pos = exit_pos
	_walk_tex = PixelArt.find([ART_DIR + look + "_sheet.png"])
	_sit_tex = PixelArt.find([ART_DIR + look + "_sit.png"])
	_color = Color.from_hsv(randf(), 0.45, 0.9)


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.show_behind_parent = true
	add_child(_sprite)
	_use_walk_art()


func _use_walk_art() -> void:
	PixelArt.setup_character(_sprite, _walk_tex, FEET_Y)


func _process(delta: float) -> void:
	match state:
		State.WALK_IN, State.WALK_OUT:
			_walk(delta)
		State.WAITING:
			if not food_coming:
				waited += delta * (TAKEN_PATIENCE_RATE if order_taken else 1.0)
			var m := Mood.HAPPY if waited < patience * 0.28 else (Mood.OKAY if waited < patience * 0.56 else Mood.ANNOYED)
			if m != mood:
				mood = m
			queue_redraw()
			if waited >= patience:
				_give_up()
		State.EATING:
			_timer -= delta
			if reaction >= 0 and _timer < EAT_TIME - REACTION_TIME:
				reaction = -1
				queue_redraw()
			if _timer <= 0.0:
				_leave()


func _walk(delta: float) -> void:
	var v := Vector2.ZERO
	if not _path.is_empty():
		var to := _path[0] - position
		var step := SPEED * delta
		if to.length() <= step:
			position = _path[0]
			_path.remove_at(0)
		else:
			v = to.normalized() * SPEED
			position += v * delta
	_anim += delta
	PixelArt.animate_character(_sprite, v, _anim)
	if _path.is_empty():
		if state == State.WALK_IN:
			_sit_down()
		else:
			left_restaurant.emit(self)
			queue_free()


func _sit_down() -> void:
	state = State.WAITING
	waited = 0.0
	position = seat.pos
	var frame: int = {"down": 0, "left": 1, "right": 2}.get(seat.facing, -1)
	if _sit_tex and frame >= 0:
		_sprite.texture = _sit_tex
		_sprite.hframes = maxi(1, floori(_sit_tex.get_width() / float(PixelArt.FRAME_WIDTH)))
		_sprite.vframes = 1
		_sprite.frame = mini(frame, _sprite.hframes - 1)
	elif _walk_tex and _sprite.vframes == 4:
		var row: int = {"down": PixelArt.Facing.DOWN, "up": PixelArt.Facing.UP,
			"left": PixelArt.Facing.LEFT, "right": PixelArt.Facing.RIGHT}.get(seat.facing, 0)
		_sprite.frame_coords = Vector2i(0, row)
	if game:
		game.customer_seated(self)
	queue_redraw()


## Waited too long: leaves without eating (and without paying).
func _give_up() -> void:
	reaction = Mood.ANNOYED
	if game:
		game.customer_gave_up(self)
	_leave()


## The kitchen served this customer's dish.
func receive_dish() -> void:
	reaction = mood
	state = State.EATING
	_timer = EAT_TIME
	queue_redraw()


func _leave() -> void:
	state = State.WALK_OUT
	_use_walk_art()
	_path = PackedVector2Array()
	if game:
		var res: Dictionary = game.nav.find_path(position, Rect2(_exit_pos - Vector2(16, 16), Vector2(32, 32)), 8.0)
		if res.ok:
			_path = res.points
	_path.append(_exit_pos)
	queue_redraw()


# --- Drawing: placeholder body, order bubble, reaction face ---------------------

func _draw() -> void:
	if _sprite == null or _sprite.texture == null:
		draw_circle(Vector2.ZERO, RADIUS, _color)
		draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 24, _color.darkened(0.6), 3.0)
	var top := _top()
	if state == State.WAITING and dish != "":
		_draw_order_bubble(Vector2(0, top - 34))
	elif state == State.EATING and reaction >= 0:
		_draw_face(Vector2(0, top - 30), reaction, 18.0)
	elif state == State.EATING:
		_draw_dish(Vector2(0, top - 26), dish, 0.6)
	elif state == State.WALK_OUT and reaction == Mood.ANNOYED and dish != "" and waited >= patience:
		_draw_face(Vector2(0, top - 30), Mood.ANNOYED, 18.0)


func _top() -> float:
	if _sprite and _sprite.texture:
		var h := float(_sprite.texture.get_height()) / _sprite.vframes
		var blank := PixelArt.blank_rows_top(_sprite.texture, int(h)) if _sprite.vframes == 4 else 0
		return FEET_Y - (h - blank) * PixelArt.SCALE
	return -RADIUS


func _draw_order_bubble(center: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if not order_taken:
		_draw_waiting_bubble(center)
		return
	var icon := _dish_icon(dish)
	var label := Kitchen.title_of(dish)
	var w := 52.0 if icon else font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18
	var box := Rect2(center - Vector2(w / 2.0 + 14, 22), Vector2(w + 28, 44))
	var edge: Color = [Color(0.35, 0.7, 0.3), Color(0.9, 0.7, 0.2), Color(0.85, 0.25, 0.2)][mood]
	draw_rect(box, Color(1, 0.98, 0.92))
	draw_rect(box, edge, false, 3.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-6, 22), center + Vector2(6, 22), center + Vector2(0, 30)]), edge)
	if icon:
		_draw_dish(center + Vector2(-8, 0), dish, 1.0)
	else:
		draw_string(font, Vector2(box.position.x + 9, center.y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.25, 0.15, 0.08))
	_draw_face(Vector2(box.end.x - 12, box.position.y + 12), mood, 8.0)
	# Patience left.
	var left := clampf(1.0 - waited / patience, 0.0, 1.0)
	var bar := Rect2(box.position + Vector2(4, box.size.y - 7), Vector2((box.size.x - 8) * left, 4))
	draw_rect(bar, edge)


## Before anyone takes the order: a "?" bubble (they want to order).
func _draw_waiting_bubble(center: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var edge: Color = [Color(0.35, 0.7, 0.3), Color(0.9, 0.7, 0.2), Color(0.85, 0.25, 0.2)][mood]
	var box := Rect2(center - Vector2(30, 22), Vector2(60, 44))
	draw_rect(box, Color(1, 0.98, 0.92))
	draw_rect(box, edge, false, 3.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-6, 22), center + Vector2(6, 22), center + Vector2(0, 30)]), edge)
	draw_string(font, Vector2(box.position.x + 8, center.y + 10), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.25, 0.15, 0.08))
	_draw_face(Vector2(box.end.x - 14, center.y - 2), mood, 9.0)
	var left := clampf(1.0 - waited / patience, 0.0, 1.0)
	draw_rect(Rect2(box.position + Vector2(4, box.size.y - 7), Vector2((box.size.x - 8) * left, 4)), edge)


func _dish_icon(d: String) -> Texture2D:
	var t := PixelArt.find(["res://assets/ui/windows/recipe_book/dish_%s.png" % d.to_lower()])
	return t if t else PixelArt.food_icon(d, true, true)


func _draw_dish(center: Vector2, d: String, scale: float) -> void:
	var t := _dish_icon(d)
	if t == null:
		return
	var fit := 40.0 * scale / maxf(t.get_width(), t.get_height())
	var sz := t.get_size() * fit
	draw_texture_rect(t, Rect2(center - sz / 2.0, sz), false)


## Simple face: green smile, yellow straight mouth, red frown.
func _draw_face(c: Vector2, m: int, r: float) -> void:
	var col: Color = [Color(0.45, 0.8, 0.35), Color(0.98, 0.8, 0.25), Color(0.9, 0.35, 0.25)][m]
	draw_circle(c, r, col)
	draw_arc(c, r, 0, TAU, 20, col.darkened(0.55), maxf(1.5, r / 8.0))
	var eye := r * 0.35
	draw_circle(c + Vector2(-eye, -eye * 0.6), r * 0.12, Color(0.15, 0.1, 0.05))
	draw_circle(c + Vector2(eye, -eye * 0.6), r * 0.12, Color(0.15, 0.1, 0.05))
	var mw := maxf(1.5, r / 7.0)
	match m:
		Mood.HAPPY:
			draw_arc(c + Vector2(0, r * 0.05), r * 0.45, 0.15 * PI, 0.85 * PI, 10, Color(0.15, 0.1, 0.05), mw)
		Mood.OKAY:
			draw_line(c + Vector2(-r * 0.35, r * 0.35), c + Vector2(r * 0.35, r * 0.35), Color(0.15, 0.1, 0.05), mw)
		_:
			draw_arc(c + Vector2(0, r * 0.7), r * 0.4, 1.15 * PI, 1.85 * PI, 10, Color(0.15, 0.1, 0.05), mw)

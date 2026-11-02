extends Node2D
## Rounded paper bubble above the manager's head showing what E does here,
## e.g. "[E] Program Jane" (Paper Notebook style), with a small tail pointing
## at the thing E acts on. Shown while something interactable is right next
## to the manager.

const Paper := preload("res://scenes/ui/common/paper.gd")
const PAD := Vector2(12, 8)
const FS := 16
var text := "":
	set(v):
		text = v
		visible = v != ""
		_pop = 0.0
		queue_redraw()
## What E acts on (the tail points at it).
var target: Node2D = null
var _pop := 1.0
var _last_dir := Vector2.ZERO


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	if _pop < 1.0:
		_pop = minf(1.0, _pop + delta * 6.0)
		queue_redraw()
	var d := _target_dir()
	if d.distance_to(_last_dir) > 2.0:
		_last_dir = d
		queue_redraw()


func _target_dir() -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	return target.global_position - global_position


func _draw() -> void:
	if text == "":
		return
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	var key_w := 44.0
	var w := tw + key_w + 10 + PAD.x * 2
	var h := 24.0 + PAD.y * 2
	var k := 0.6 + 0.4 * _pop
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var rect := Rect2(-w / 2.0, -h, w, h)
	var cream := Color(1.0, 0.97, 0.9)
	var ink := Paper.INK
	# Tail: from the bubble's bottom edge toward the target (or straight down).
	var d := _target_dir()
	var tx := clampf(d.x * 0.25, -w / 2.0 + 14.0, w / 2.0 - 14.0) if d != Vector2.ZERO else -6.0
	var tip := Vector2(tx + signf(d.x) * 6.0, 14.0) if d != Vector2.ZERO else Vector2(-10.0, 14.0)
	var base_l := Vector2(tx - 8.0, -2.0)
	var base_r := Vector2(tx + 8.0, -2.0)
	draw_colored_polygon(PackedVector2Array([base_l + Vector2(-3, 0), base_r + Vector2(3, 0), tip + Vector2(0, 4)]), ink)
	var sb: StyleBox = Paper.bubble(Vector4(0, 0, 0, 0))
	draw_style_box(sb, rect)
	draw_colored_polygon(PackedVector2Array([base_l, base_r, tip]), cream)
	# Key chip "E".
	var chip: Texture2D = Paper.tex("key_chip")
	var kr := Rect2(rect.position.x + PAD.x, rect.position.y + PAD.y, key_w, 24)
	if chip:
		draw_texture_rect(chip, kr, false)
	else:
		var kb := StyleBoxFlat.new()
		kb.bg_color = ink
		kb.set_corner_radius_all(5)
		draw_style_box(kb, kr)
	draw_string(font, kr.position + Vector2(16, 18), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, FS, ink)
	draw_string(font, Vector2(kr.end.x + 10, kr.position.y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, ink)
	draw_set_transform(Vector2.ZERO)

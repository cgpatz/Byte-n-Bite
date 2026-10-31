extends Node2D
## Thought bubble above the manager's head showing what E does here, e.g.
## "( E ) Shop at Butcher". Shown while something interactable is in reach.

const PAD := Vector2(12, 8)
const FS := 16
var text := "":
	set(v):
		text = v
		visible = v != ""
		_pop = 0.0
		queue_redraw()
var _pop := 1.0


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	visible = false


func _process(delta: float) -> void:
	if visible and _pop < 1.0:
		_pop = minf(1.0, _pop + delta * 6.0)
		queue_redraw()


func _draw() -> void:
	if text == "":
		return
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	var key_w := 22.0
	var w := tw + key_w + 10 + PAD.x * 2
	var h := 26.0 + PAD.y * 2
	var k := 0.6 + 0.4 * _pop
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var rect := Rect2(-w / 2.0, -h, w, h)
	var cream := Color(1.0, 0.97, 0.9)
	var ink := Color(0.24, 0.13, 0.07)
	var sb := StyleBoxFlat.new()
	sb.bg_color = cream
	sb.border_color = ink
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	draw_style_box(sb, rect)
	# Thought dots trailing down to the head.
	for d in [[Vector2(-6, 10), 6.0], [Vector2(-12, 22), 4.0]]:
		draw_circle(d[0], d[1] + 1.5, ink)
		draw_circle(d[0], d[1], cream)
	# Key cap "E".
	var kr := Rect2(rect.position.x + PAD.x, rect.position.y + PAD.y + 1, key_w, 24)
	var kb := StyleBoxFlat.new()
	kb.bg_color = ink
	kb.set_corner_radius_all(5)
	draw_style_box(kb, kr)
	draw_string(font, kr.position + Vector2(6, 18), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color.WHITE)
	draw_string(font, Vector2(kr.end.x + 10, kr.position.y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, ink)
	draw_set_transform(Vector2.ZERO)

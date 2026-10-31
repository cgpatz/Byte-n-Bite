extends Node2D
## Thought bubble above a staff member's head showing what their program
## printf()s, e.g. printf("Hi, I'm Jane, here's your %s for %.2f\n", dish, price).
## Text is collected until a new line (\n); each finished line pops up and
## stays for a few seconds (longer lines stay longer). The newest line wins.

const FS := 15
const MAX_W := 300.0
const PAD := Vector2(12, 8)
const MAX_CHARS := 140

var text := ""
var _left := 0.0
var _pop := 1.0
var _pending := ""
var _flush_in := -1.0


func _ready() -> void:
	z_index = 31
	z_as_relative = false
	visible = false


## Called with each piece printf writes.
func add_output(t: String) -> void:
	_pending += t
	while "\n" in _pending:
		var cut := _pending.find("\n")
		var line := _pending.substr(0, cut).strip_edges()
		_pending = _pending.substr(cut + 1)
		if line != "":
			say(line)
	# printf without \n: show it anyway after a short moment.
	_flush_in = 0.35 if _pending.strip_edges() != "" else -1.0


func say(line: String) -> void:
	if line.length() > MAX_CHARS:
		line = line.substr(0, MAX_CHARS - 1) + "…"
	text = line
	_left = clampf(2.0 + line.length() / 18.0, 2.5, 7.0)
	_pop = 0.0
	visible = true
	modulate.a = 1.0
	queue_redraw()


func clear() -> void:
	_pending = ""
	_flush_in = -1.0
	text = ""
	visible = false


func _process(delta: float) -> void:
	if _flush_in > 0.0:
		_flush_in -= delta
		if _flush_in <= 0.0:
			_flush_in = -1.0
			var line := _pending.strip_edges()
			_pending = ""
			if line != "":
				say(line)
	if not visible:
		return
	if _pop < 1.0:
		_pop = minf(1.0, _pop + delta * 6.0)
		queue_redraw()
	_left -= delta
	if _left < 0.4:
		modulate.a = maxf(0.0, _left / 0.4)
	if _left <= 0.0:
		visible = false


func _draw() -> void:
	if text == "":
		return
	var font := ThemeDB.fallback_font
	var one := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	var wrap := minf(one + 2.0, MAX_W)
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap, FS)
	var w := sz.x + PAD.x * 2
	var h := sz.y + PAD.y * 2
	var k := 0.6 + 0.4 * _pop
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var rect := Rect2(-w / 2.0, -h - 14, w, h)
	var cream := Color(1.0, 0.98, 0.92)
	var ink := Color(0.24, 0.13, 0.07)
	var sb := StyleBoxFlat.new()
	sb.bg_color = cream
	sb.border_color = ink
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	draw_style_box(sb, rect)
	for d in [[Vector2(4, -6), 5.0], [Vector2(9, 4), 3.5]]:
		draw_circle(d[0], d[1] + 1.5, ink)
		draw_circle(d[0], d[1], cream)
	draw_multiline_string(font, rect.position + PAD + Vector2(0, FS), text, HORIZONTAL_ALIGNMENT_LEFT, wrap, FS, -1, ink)
	draw_set_transform(Vector2.ZERO)

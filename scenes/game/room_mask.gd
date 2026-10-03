extends Node2D
## Darkens everything outside the current room so only that room is in view.

const COLOR := Color(0.1, 0.075, 0.06, 1.0)
const FAR := 100000.0

var rect := Rect2():
	set(v):
		rect = v
		queue_redraw()


func _ready() -> void:
	z_index = 100  # above the restaurant and characters (UI is on its own layer)


func _draw() -> void:
	if rect.size == Vector2.ZERO:
		return
	var r := rect
	draw_rect(Rect2(-FAR, -FAR, FAR * 2.0, r.position.y + FAR), COLOR)                  # above
	draw_rect(Rect2(-FAR, r.end.y, FAR * 2.0, FAR), COLOR)                                # below
	draw_rect(Rect2(-FAR, r.position.y, r.position.x + FAR, r.size.y), COLOR)             # left
	draw_rect(Rect2(r.end.x, r.position.y, FAR, r.size.y), COLOR)                         # right

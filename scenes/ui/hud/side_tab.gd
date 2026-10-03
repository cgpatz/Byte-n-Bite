extends Control
## A narrow tab stuck to the screen's left edge with sideways (vertical) text.
## Click it to open / close the drawer it belongs to.

signal pressed

var text := "":
	set(v):
		text = v
		queue_redraw()
var font_size := 16
var _hover := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.33, 0.2, 0.12) if _hover else Color(0.25, 0.15, 0.09))
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x - 3, r.size.y - 4)), Color(0.55, 0.36, 0.2), false, 3.0)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Text reads bottom-to-top, centred in the tab.
	draw_set_transform(Vector2(size.x / 2.0 + font_size * 0.35, size.y / 2.0 + w / 2.0), -PI / 2.0)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.86, 0.55))
	draw_set_transform(Vector2.ZERO)

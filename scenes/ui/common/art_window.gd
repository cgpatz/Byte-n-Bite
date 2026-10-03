extends Control
## Base for the pixel-art windows (Stats, Recipe Book, Library, Lessons, Code
## Sets). Everything is laid out on a 1920×1080 `frame` (positions from the
## mockups in Documents/Byte n' Bite/ui), shown as a FLOATING window:
##   · drag the window's background to move it,
##   · drag the corner grip to resize it (the whole page scales),
##   · several windows can be open at once; clicking one brings it to the front,
##   · Esc closes the front-most window.
## Where each window was left is remembered (SettingsManager.windows).
## Subclasses draw into `frame` in _build() and update it in _refresh().

signal closed

const Art := preload("res://scenes/ui/common/ui_art.gd")
const DESIGN := Vector2(1920, 1080)
const GRIP := 34.0
const MIN_SCALE := 0.3
const DEFAULT_SCALE := 0.62

var frame: Control
var close_button: Button
## The visible part of the 1920×1080 page (the board/book art). Dragging works
## on it; the corner grip sits at its bottom-right.
var window_rect := Rect2(152, 40, 1616, 1000)

var _hit: Control
var _grip: Control
var _drag := ""
var _drag_from := Vector2.ZERO
var _pos_from := Vector2.ZERO
var _scale_from := 1.0
var _placed := false
static var _opened_count := 0


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame = Control.new()
	frame.size = DESIGN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_hit = Control.new()
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hit.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_hit.gui_input.connect(_on_hit_input)
	frame.add_child(_hit)
	_build()
	_hit.position = window_rect.position
	_hit.size = window_rect.size
	_grip = Control.new()
	_grip.size = Vector2(GRIP, GRIP)
	_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_grip.tooltip_text = "Drag to resize"
	_grip.draw.connect(_draw_grip)
	_grip.gui_input.connect(_on_grip_input)
	add_child(_grip)
	if close_button:
		close_button.pressed.connect(close)
	resized.connect(func(): if visible: _place(frame.position, frame.scale.x))
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


## Marks this as a floating window (see is_topmost()).
func is_floating_window() -> bool:
	return true


func open() -> void:
	_refresh()
	show()
	move_to_front()
	if not _placed:
		_placed = true
		var saved = SettingsManager.windows.get(String(name), null)
		if saved is Array and saved.size() == 3:
			_place(Vector2(saved[0], saved[1]), saved[2])
		else:
			# New windows cascade so they don't hide each other.
			var s := DEFAULT_SCALE
			var c := (size - window_rect.size * s) / 2.0 - window_rect.position * s
			_place(c + Vector2(40, 30) * (_opened_count % 5) - Vector2(80, 60), s)
			_opened_count += 1
	else:
		_place(frame.position, frame.scale.x)
	if close_button:
		close_button.grab_focus()


func close() -> void:
	_on_close()
	hide()
	closed.emit()


## True when no other visible floating window is in front of this one.
func is_topmost() -> bool:
	var p := get_parent()
	for i in range(p.get_child_count() - 1, -1, -1):
		var c := p.get_child(i)
		if c is Control and c.visible and c.has_method("is_floating_window"):
			return c == self
	return false


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and is_topmost():
		get_viewport().set_input_as_handled()
		close()


func _on_focus_changed(c: Control) -> void:
	if visible and c != null and is_ancestor_of(c):
		move_to_front()


## Puts the page at pos with this scale, keeping some of it on screen.
func _place(pos: Vector2, s: float) -> void:
	var vs := size
	var max_s := minf(vs.x / window_rect.size.x, vs.y / window_rect.size.y)
	s = clampf(s, MIN_SCALE, maxf(MIN_SCALE, max_s))
	var vis := Rect2(pos + window_rect.position * s, window_rect.size * s)
	vis.position.x = clampf(vis.position.x, 120.0 - vis.size.x, vs.x - 120.0)
	vis.position.y = clampf(vis.position.y, 0.0, vs.y - 60.0)
	frame.scale = Vector2(s, s)
	frame.position = vis.position - window_rect.position * s
	_grip.position = vis.end - Vector2(GRIP, GRIP)
	_grip.queue_redraw()


func _remember() -> void:
	SettingsManager.windows[String(name)] = [frame.position.x, frame.position.y, frame.scale.x]
	SettingsManager.save_settings()


func _on_hit_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			move_to_front()
			_drag = "move"
			_drag_from = e.global_position
			_pos_from = frame.position
		elif _drag != "":
			_drag = ""
			_remember()
	elif e is InputEventMouseMotion and _drag == "move":
		_place(_pos_from + e.global_position - _drag_from, frame.scale.x)


func _on_grip_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			move_to_front()
			_drag = "resize"
			_drag_from = e.global_position
			_scale_from = frame.scale.x
		elif _drag != "":
			_drag = ""
			_remember()
	elif e is InputEventMouseMotion and _drag == "resize":
		# Scale so the corner follows the mouse (keeps the page's shape).
		var d: Vector2 = e.global_position - _drag_from
		var s := _scale_from + maxf(d.x / window_rect.size.x, d.y / window_rect.size.y)
		_place(frame.position, s)


func _draw_grip() -> void:
	var c := Color(0.98, 0.85, 0.6, 0.95)
	for i in 3:
		var d := 9.0 + i * 8.0
		_grip.draw_line(Vector2(GRIP - 5, GRIP - 5 - d), Vector2(GRIP - 5 - d, GRIP - 5), c, 3.0)


## Adds the standard "Close" plank button.
func add_close_button(pos: Vector2) -> void:
	close_button = Art.button(frame, "Close", Rect2(pos, Vector2(160, 68)), false, 28)


## Paper title card with two pins (Library and Stats).
func add_title_card(path: String, text: String, pos: Vector2) -> void:
	var sz := Art.size_of(path)
	if sz == Vector2.ZERO:
		sz = Vector2(480, 96)
	Art.panel(frame, path, Rect2(pos, sz), [4, 4, 6, 6])
	Art.label(frame, text, pos + Vector2(0, 10), 52, Art.INK, false, sz.x - 8, HORIZONTAL_ALIGNMENT_CENTER, Art.serif())
	Art.image(frame, "library/pin_blue.png", pos + Vector2(8, -8))
	Art.image(frame, "library/pin_blue.png", pos + Vector2(sz.x - 36, -8))


## Override: create the window's controls inside `frame`.
func _build() -> void:
	pass


## Override: update the controls each time the window opens.
func _refresh() -> void:
	pass


## Override: runs just before the window closes.
func _on_close() -> void:
	pass

extends Control
## Fridge window: [E] at the FRIDGE. An open fridge with every ingredient on its
## shelves and how many the kitchen has (pick_up() uses one). Empty items are
## greyed with a red count, low ones (3 or less) orange, locked ones show the
## level that unlocks them. The door shows deliveries on the way, crates
## waiting in the delivery area and the next Market restock.
## Art: assets/ui/windows/market/fridge_open.png (260 × 180, shown 4×).

signal closed
signal market_requested

const Art := preload("res://scenes/ui/common/ui_art.gd")
const Market := preload("res://systems/market/market_rules.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const PixelArt := preload("res://scenes/art/pixel_art.gd")
const W := 1920.0
const H := 1080.0
## Fridge art position in the 1920 × 1080 frame.
const AT := Vector2(440, 150)
const COLS := 6
const LOW := 3
## Shelf layout in art px: first row top, row height, column x, column width.
const ROW_TOP := 32
const ROW_H := 34
const COL_X := 8
const COL_W := 30

var frame: Control
var _slots: Control
var _on_way: Label
var _crates: Label
var _restock: Label


func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.01, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	frame = Control.new()
	frame.size = Vector2(W, H)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	Art.image(frame, "market/fridge_open.png", AT)
	Art.label(frame, "Fridge", AT + Vector2(244, 20), 34, Art.CREAM, false, 312, HORIZONTAL_ALIGNMENT_CENTER, Art.serif())
	_slots = Control.new()
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_slots)
	# Door: deliveries, crates, restock.
	var door := AT + Vector2(822, 0)
	var dark := Color(0.24, 0.13, 0.07)
	for spec in [[84, "On the way"], [292, "Crates waiting"], [484, "Market restock"]]:
		Art.label(frame, spec[1], door + Vector2(0, spec[0]), 17, dark, true, 200, HORIZONTAL_ALIGNMENT_CENTER)
	_on_way = Art.label(frame, "", door + Vector2(0, 168), 22, dark, true, 200, HORIZONTAL_ALIGNMENT_CENTER)
	_crates = Art.label(frame, "", door + Vector2(0, 376), 22, dark, true, 200, HORIZONTAL_ALIGNMENT_CENTER)
	_restock = Art.label(frame, "", door + Vector2(0, 568), 22, dark, true, 200, HORIZONTAL_ALIGNMENT_CENTER)
	Art.label(frame, "Every pick_up() uses one ingredient.  Buy more at the Market, then press E on the crates in the delivery area.",
		Vector2(240, 888), 21, Art.CREAM, false, 1440, HORIZONTAL_ALIGNMENT_CENTER)
	var go := Art.button(frame, "Go to Market (M)", Rect2(640, 940, 340, 76), true, 28)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func():
		close()
		market_requested.emit())
	var shut := Art.button(frame, "Close  (E / Esc)", Rect2(1000, 940, 300, 76), false, 26)
	shut.focus_mode = Control.FOCUS_NONE
	shut.pressed.connect(close)
	GameState.inventory_changed.connect(func():
		if visible:
			_fill())
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	var vp := get_viewport_rect().size
	var k := minf(vp.x / W, vp.y / H)
	frame.scale = Vector2(k, k)
	frame.position = (vp - Vector2(W, H) * k) / 2.0


func open() -> void:
	_fit()
	_fill()
	_update_door()
	show()
	move_to_front()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _process(_delta: float) -> void:
	if visible:
		_update_door()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("market"):
		get_viewport().set_input_as_handled()
		close()
		market_requested.emit()


## Restaurant ingredients on the top two shelves, Café ones on the bottom two.
func _fill() -> void:
	for c in _slots.get_children():
		c.queue_free()
	var restaurant: Array = []
	var cafe: Array = []
	for ing in Kitchen.INGREDIENTS:
		(cafe if ing in Kitchen.CAFE_INGREDIENTS else restaurant).append(ing)
	for i in restaurant.size():
		_slot(restaurant[i], i / COLS, i % COLS)
	if GameState.cafe_step < 1:
		# Café shelves stay empty until the Café is bought.
		var s := float(PixelArt.SCALE)
		var y := AT.y + (ROW_TOP + 2 * ROW_H) * s
		Art.image(_slots, "recipe_book/lock.png", Vector2(AT.x + 99 * s - 24, y + 70), Vector2(48, 48)).modulate = Color(1, 1, 1, 0.75)
		Art.label(_slots, "Café shelves", Vector2(AT.x + 8 * s, y + 130), 26, Color(0.16, 0.22, 0.27), true, 182 * s, HORIZONTAL_ALIGNMENT_CENTER)
		var sub := Art.label(_slots, "Coffee, milk and matcha arrive with the Café (Restaurant Lv 5).", Vector2(AT.x + 8 * s, y + 168), 19, Color(0.24, 0.32, 0.38), false, 182 * s, HORIZONTAL_ALIGNMENT_CENTER)
		sub.clip_text = false
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.size = Vector2(182 * s, 60)
		return
	for i in cafe.size():
		_slot(cafe[i], 2 + i / COLS, i % COLS)


func _slot(ing: String, row: int, col: int) -> void:
	var s := float(PixelArt.SCALE)
	var x0 := AT.x + (COL_X + col * COL_W) * s
	var top := AT.y + (ROW_TOP + row * ROW_H) * s
	var shelf := top + (ROW_H - 3) * s
	var w := COL_W * s
	var why := Kitchen.available(ing, GameState.restaurant_level, GameState.cafe_step)
	var dark := Color(0.16, 0.22, 0.27)
	if why != "":
		Art.image(_slots, "recipe_book/lock.png", Vector2(x0 + w / 2.0 - 20, shelf - 70), Vector2(40, 40)).modulate = Color(1, 1, 1, 0.7)
		var need: int = Kitchen.INGREDIENTS.get(ing, 1)
		var tag := "Lv %d" % need if need > GameState.restaurant_level else "Café"
		Art.label(_slots, tag, Vector2(x0, shelf - 26), 17, Color(0.3, 0.38, 0.44), true, w, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var n := GameState.stock_of(ing)
	Art.label(_slots, Market.title(ing), Vector2(x0, top + 8), 17 if ing.length() <= 9 else 14, dark, true, w, HORIZONTAL_ALIGNMENT_CENTER)
	var icon := TextureRect.new()
	icon.texture = PixelArt.food_icon(ing, false, false)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(60, 60)
	icon.position = Vector2(x0 + w / 2.0 - 30, shelf - 62)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if n <= 0:
		icon.modulate = Color(0.45, 0.5, 0.55, 0.55)
	_slots.add_child(icon)
	# Count badge on the shelf edge.
	var badge := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.72, 0.16, 0.12) if n <= 0 else (Color(0.86, 0.5, 0.12) if n <= LOW else Color(0.17, 0.1, 0.07))
	st.border_color = Color(0.1, 0.05, 0.03)
	st.set_border_width_all(2)
	st.content_margin_left = 6
	st.content_margin_right = 6
	badge.add_theme_stylebox_override("panel", st)
	badge.position = Vector2(x0 + w / 2.0 + 6, shelf - 34)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.tooltip_text = "Out!" if n <= 0 else ("Running low" if n <= LOW else "")
	_slots.add_child(badge)
	var l := Label.new()
	l.text = "Out" if n <= 0 else str(n)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_font_override("font", Art.bold_font())
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 0)
	badge.add_child(l)


func _update_door() -> void:
	var dv: Array = GameState.deliveries
	if dv.is_empty():
		_on_way.text = "None"
	else:
		var next := INF
		for d in dv:
			next = minf(next, float(d.left))
		_on_way.text = "%d · next %s" % [dv.size(), Market.clock(next)]
	var c: int = GameState.crates.size()
	_crates.text = "None" if c == 0 else "%d crate%s" % [c, "" if c == 1 else "s"]
	_restock.text = Market.clock(GameState.market_restock_left)

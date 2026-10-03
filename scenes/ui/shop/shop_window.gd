extends Control
## Night Market stall window (FR-11, FR-59): opens with [E] at a stall tent.
## Shows the stall close up with its vendor, each ingredient with its price,
## how many the Market has (random, see GameState.market_stock), a - / + stepper,
## and the Order Slip with the total, delivery time, crates and Express option.
## Built on a 1920 × 1080 frame scaled to the screen. Art: assets/ui/windows/market/
## (Night Market set, "2 stall shop screens"). Esc = leave the stall.

signal closed

const Art := preload("res://scenes/ui/common/ui_art.gd")
const Market := preload("res://systems/market/market_rules.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const PixelArt := preload("res://scenes/art/pixel_art.gd")
const W := 1920.0
const H := 1080.0
const VENDOR_X := 708.0
const LEFT_SPAN := Vector2(68, 580)
const RIGHT_SPAN := Vector2(836, 1348)
const SLIP_ROWS_Y := 176.0
const SLIP_ROW_H := 50.0
const MAX_SLIP_ROWS := 6

var stall := ""
var cart := {}
var express := false

var frame: Control
var _stall_layer: Control
var _slip_rows: Control
var _coins: Label
var _restock: Label
var _bubble_text: Label
var _total: Label
var _delivery: Label
var _crates: Label
var _express: CheckBox
var _order: Button
var _leave: Button
## ingredient -> {"qty": Label, "tag": Control, "tag_label": Label, "stock": Label, "plus": Button, "minus": Button}
var _cells := {}


func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	frame = Control.new()
	frame.size = Vector2(W, H)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	Art.image(frame, "market/night_background.png", Vector2.ZERO)
	var lights := PixelArt.find(["res://assets/market/string_lanterns.png"])
	for i in 8:
		var l := TextureRect.new()
		l.texture = lights
		l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		l.size = Vector2(256, 56)
		l.position = Vector2(i * 256 - 8, -4)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(l)
	_stall_layer = Control.new()
	_stall_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_stall_layer)
	# Coins and restock time.
	var cbox := ColorRect.new()
	cbox.color = Color(0.17, 0.1, 0.07, 0.95)
	cbox.position = Vector2(36, 28)
	cbox.size = Vector2(240, 48)
	frame.add_child(cbox)
	Art.image(frame, "recipe_book/coin.png", Vector2(46, 32), Vector2(40, 40))
	_coins = Art.label(frame, "", Vector2(100, 33), 28, Art.GOLD, true, 160, HORIZONTAL_ALIGNMENT_CENTER)
	_restock = Art.label(frame, "", Vector2(296, 40), 20, Color(0.85, 0.75, 0.6), false, 420)
	_build_slip()
	GameState.money_changed.connect(func(_m):
		if visible:
			_refresh_slip())
	GameState.market_changed.connect(func():
		if visible:
			_build_stall())
	get_viewport().size_changed.connect(_fit)


func _process(_delta: float) -> void:
	if visible:
		_restock.text = "New stock in %s" % Market.clock(GameState.market_restock_left)


func _fit() -> void:
	var vp := get_viewport_rect().size
	var k := minf(vp.x / W, vp.y / H)
	frame.scale = Vector2(k, k)
	frame.position = (vp - Vector2(W, H) * k) / 2.0


# --- Opening / closing ---------------------------------------------------------------

func open(stall_key: String) -> void:
	stall = stall_key
	cart = {}
	express = false
	_express.set_pressed_no_signal(false)
	_fit()
	_build_stall()
	show()
	move_to_front()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func is_closed_stall() -> bool:
	return Market.STALLS[stall].get("cafe", false) and GameState.cafe_step < 1


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# --- The stall ---------------------------------------------------------------------

func _build_stall() -> void:
	for c in _stall_layer.get_children():
		c.queue_free()
	_cells.clear()
	var info: Dictionary = Market.STALLS[stall]
	Art.image(_stall_layer, "market/tent_closeup_%s.png" % stall.to_lower(), Vector2(48, 72))
	Art.image(_stall_layer, "market/name_sign.png", Vector2(468, 184))
	Art.label(_stall_layer, info.title, Vector2(468, 222), 30, Art.INK, false, 480, HORIZONTAL_ALIGNMENT_CENTER, Art.serif())
	var closed_stall := is_closed_stall()
	if not closed_stall:
		_add_vendor(info.vendor)
	Art.image(_stall_layer, "market/counter.png", Vector2(48, 676))
	if closed_stall:
		Art.image(_stall_layer, "market/closed_boards.png", Vector2(48, 436))
		Art.label(_stall_layer, "Opens when you buy the Café", Vector2(432, 648), 28, Art.INK, true, 556, HORIZONTAL_ALIGNMENT_CENTER)
		Art.label(_stall_layer, "(Restaurant Lv 5 · %s coins)" % _commas(Kitchen.CAFE_UNLOCK_COST), Vector2(432, 692), 20, Art.INK_SOFT, false, 556, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_add_bubble(info.greeting)
		var items: Array = info.items
		var n_left := ceili(items.size() / 2.0)
		for i in items.size():
			var left := i < n_left
			var span: Vector2 = LEFT_SPAN if left else RIGHT_SPAN
			var k := n_left if left else items.size() - n_left
			var j := i if left else i - n_left
			var slot_w := (span.y - span.x) / k
			_add_item(items[i], span.x + (j + 0.5) * slot_w, minf(1.0, (slot_w - 12.0) / 224.0))
	_refresh_slip()


func _add_vendor(look: String) -> void:
	var sheet := PixelArt.find(["res://assets/character/customers/%s_sheet.png" % look])
	if sheet == null:
		return
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(0, 0, 16, sheet.get_height() / 4.0)
	var r := TextureRect.new()
	r.texture = at
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2(256, at.region.size.y * 16)
	r.position = Vector2(VENDOR_X - 128, 760 - r.size.y)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stall_layer.add_child(r)


func _add_bubble(text: String) -> void:
	Art.image(_stall_layer, "market/speech_bubble.png", Vector2(836, 362))
	_bubble_text = Art.label(_stall_layer, text, Vector2(862, 382), 19, Art.INK, true, 420)
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.clip_text = false
	_bubble_text.size = Vector2(420, 60)


## The vendor says something (feedback for the player).
func say(text: String) -> void:
	if _bubble_text and is_instance_valid(_bubble_text):
		_bubble_text.text = text


func _piece(path: String, cx: float, y: float, k: float) -> TextureRect:
	var s := Art.size_of(path) * k
	return Art.image(_stall_layer, path, Vector2(cx - s.x / 2.0, y), s)


func _add_item(ing: String, cx: float, k: float) -> void:
	var why := Kitchen.available(ing, GameState.restaurant_level, GameState.cafe_step)
	var col_w := 224.0 * k
	Art.label(_stall_layer, Market.title(ing), Vector2(cx - 120, 708), 24, Art.CREAM, true, 240, HORIZONTAL_ALIGNMENT_CENTER)
	if why != "":
		_piece("market/cloth_cover_locked.png", cx, 492, k)
		_piece("market/tray.png", cx, 656, k)
		var need: int = Kitchen.INGREDIENTS.get(ing, 1)
		var lock_text := "Restaurant Lv %d" % need if need > GameState.restaurant_level else "Café"
		Art.label(_stall_layer, lock_text, Vector2(cx - 120, 766), 20, Art.GOLD, true, 240, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var icon := TextureRect.new()
	icon.texture = PixelArt.food_icon(ing, false, false)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(120, 120) * k
	icon.position = Vector2(cx - icon.size.x / 2.0, 664 - icon.size.y)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stall_layer.add_child(icon)
	_piece("market/tray.png", cx, 656, k)
	# "xN" tag shown while it's on the slip.
	var tag := ColorRect.new()
	tag.color = Color(0.72, 0.13, 0.13)
	tag.position = Vector2(cx + col_w / 2.0 - 60, 522)
	tag.size = Vector2(64, 36)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stall_layer.add_child(tag)
	var tag_label := Art.label(tag, "", Vector2(0, 5), 18, Color.WHITE, true, 64, HORIZONTAL_ALIGNMENT_CENTER)
	# Price tag on a string.
	var string := ColorRect.new()
	string.color = Color(0.95, 0.9, 0.8)
	string.position = Vector2(cx - 2, 736)
	string.size = Vector2(4, 28)
	_stall_layer.add_child(string)
	var pt := _piece("market/price_tag.png", cx, 760, k)
	Art.label(_stall_layer, str(Market.price(ing)), Vector2(pt.position.x + 52 * k, 798), int(28 * maxf(k, 0.8)), Art.INK, true, 80 * k, HORIZONTAL_ALIGNMENT_CENTER)
	var stock_l := Art.label(_stall_layer, "", Vector2(cx - 120, 890), 18, Color(0.95, 0.8, 0.6), false, 240, HORIZONTAL_ALIGNMENT_CENTER)
	# Stepper: - [qty] +
	var st := _piece("market/stepper.png", cx, 928, k)
	var minus := _step_button(Rect2(st.position, Vector2(56, 56) * k), -1, ing)
	var plus := _step_button(Rect2(st.position + Vector2(152, 0) * k, Vector2(56, 56) * k), 1, ing)
	for pair in [[minus, "-"], [plus, "+"]]:
		var sign := Art.label(pair[0], pair[1], Vector2.ZERO, int(30 * maxf(k, 0.8)), Art.INK, true, 56 * k, HORIZONTAL_ALIGNMENT_CENTER)
		sign.size = Vector2(56, 56) * k
		sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var qty := Art.label(_stall_layer, "0", Vector2(st.position.x + 56 * k, 936), int(26 * maxf(k, 0.8)), Art.INK, true, 96 * k, HORIZONTAL_ALIGNMENT_CENTER)
	_cells[ing] = {"qty": qty, "tag": tag, "tag_label": tag_label, "stock": stock_l, "plus": plus, "minus": minus}


func _step_button(r: Rect2, delta: int, ing: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = ("Add one %s" if delta > 0 else "Take away one %s") % Market.title(ing)
	b.pressed.connect(func(): change(ing, delta))
	var empty := StyleBoxEmpty.new()
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, empty)
	_stall_layer.add_child(b)
	return b


## Adds or removes one of an ingredient from the slip (capped at the Market's stock).
func change(ing: String, delta: int) -> void:
	var have: int = GameState.market_stock.get(ing, 0)
	var now := clampi(int(cart.get(ing, 0)) + delta, 0, have)
	if delta > 0 and now == int(cart.get(ing, 0)):
		say("Sorry, that's all the %s I have tonight." % Market.title(ing).to_lower() if have > 0 else "Sold out! New stock in %s." % Market.clock(GameState.market_restock_left))
	if now <= 0:
		cart.erase(ing)
	else:
		cart[ing] = now
	_refresh_slip()


# --- Order Slip ---------------------------------------------------------------------

func _build_slip() -> void:
	Art.image(frame, "market/order_slip.png", Vector2(1416, 96))
	Art.label(frame, "Order Slip", Vector2(1416, 112), 26, Color.WHITE, true, 480, HORIZONTAL_ALIGNMENT_CENTER)
	_slip_rows = Control.new()
	_slip_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_slip_rows)
	_dashes(486)
	Art.label(frame, "Total", Vector2(1440, 506), 24, Art.INK, true)
	_total = Art.label(frame, "0", Vector2(1700, 506), 24, Art.INK, true, 164, HORIZONTAL_ALIGNMENT_RIGHT)
	var truck := TextureRect.new()
	truck.texture = PixelArt.find(["res://assets/delivery/truck_icon.png"])
	truck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	truck.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	truck.position = Vector2(1436, 546)
	truck.size = Vector2(56, 36)
	frame.add_child(truck)
	Art.label(frame, "Delivery", Vector2(1504, 550), 22, Art.INK, true)
	_delivery = Art.label(frame, "–", Vector2(1700, 550), 22, Art.INK, true, 164, HORIZONTAL_ALIGNMENT_RIGHT)
	_crates = Art.label(frame, "", Vector2(1440, 590), 18, Art.INK_SOFT, false, 424)
	_express = CheckBox.new()
	_express.text = "Express +%d  (half the time)" % Market.EXPRESS_COST
	_express.position = Vector2(1436, 618)
	_express.focus_mode = Control.FOCUS_NONE
	_express.add_theme_font_size_override("font_size", 19)
	_express.add_theme_constant_override("outline_size", 0)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_express.add_theme_color_override(k, Art.INK_SOFT)
	_express.toggled.connect(func(on: bool):
		express = on
		_refresh_slip())
	frame.add_child(_express)
	_dashes(664)
	_order = Art.button(frame, "Place Order", Rect2(1440, 696, 424, 80), true, 32)
	_order.focus_mode = Control.FOCUS_NONE
	_order.pressed.connect(place_order)
	_leave = Art.button(frame, "Leave stall  (Esc)", Rect2(1444, 800, 416, 56), false, 22)
	_leave.focus_mode = Control.FOCUS_NONE
	_leave.pressed.connect(close)


func _dashes(y: float) -> void:
	var x := 1434.0
	while x < 1866.0:
		var d := ColorRect.new()
		d.color = Color(0.8, 0.35, 0.2)
		d.position = Vector2(x, y)
		d.size = Vector2(12, 4)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(d)
		x += 20.0


func _refresh_slip() -> void:
	_coins.text = _commas(GameState.money)
	for c in _slip_rows.get_children():
		c.queue_free()
	var y := SLIP_ROWS_Y
	var shown := 0
	for ing in cart:
		if shown >= MAX_SLIP_ROWS:
			break
		var icon := TextureRect.new()
		icon.texture = PixelArt.food_icon(ing, false, false)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(1436, y)
		icon.size = Vector2(44, 44)
		_slip_rows.add_child(icon)
		Art.label(_slip_rows, "%s x%d" % [Market.title(ing), cart[ing]], Vector2(1494, y + 8), 21, Art.INK, true, 250)
		Art.image(_slip_rows, "recipe_book/coin.png", Vector2(1758, y + 6), Vector2(32, 32))
		Art.label(_slip_rows, str(int(cart[ing]) * Market.price(ing)), Vector2(1790, y + 8), 21, Art.INK, true, 74, HORIZONTAL_ALIGNMENT_RIGHT)
		y += SLIP_ROW_H
		shown += 1
	if cart.is_empty():
		Art.label(_slip_rows, "Nothing yet", Vector2(1416, 262), 20, Color(0.6, 0.55, 0.5), false, 480, HORIZONTAL_ALIGNMENT_CENTER)
	elif cart.size() > MAX_SLIP_ROWS:
		Art.label(_slip_rows, "+ %d more" % (cart.size() - MAX_SLIP_ROWS), Vector2(1494, y + 4), 18, Art.INK_SOFT)
	var items := Market.items_in(cart)
	var cost := Market.cost_of(cart) + (Market.EXPRESS_COST if express and items > 0 else 0)
	_total.text = str(cost)
	_delivery.text = Market.clock(Market.delivery_seconds(items, express)) if items > 0 else "–"
	var cap: int = GameState.crate_capacity()
	var n := Market.crates_for(cart)
	_crates.text = "Crates: %d / %d (one crate holds %d)" % [n, cap, Market.CRATE_SIZE]
	_crates.add_theme_color_override("font_color", Color(0.75, 0.2, 0.15) if n > cap else Art.INK_SOFT)
	_order.disabled = items <= 0 or is_closed_stall()
	for ing in _cells:
		var c: Dictionary = _cells[ing]
		var q := int(cart.get(ing, 0))
		var have := int(GameState.market_stock.get(ing, 0))
		c.qty.text = str(q)
		c.tag.visible = q > 0
		c.tag_label.text = "x%d" % q
		c.stock.text = "Sold out" if have <= 0 else "in stock: %d" % have
		c.stock.add_theme_color_override("font_color", Color(1, 0.45, 0.35) if have <= 0 else Color(0.95, 0.8, 0.6))
		c.plus.disabled = q >= have
		c.minus.disabled = q <= 0


## Pays for the slip; the order is delivered to the restaurant's delivery area.
func place_order() -> void:
	var items := Market.items_in(cart)
	var t := Market.delivery_seconds(items, express)
	var why: String = GameState.buy_from_market(cart, express)
	if why != "":
		say(why)
		return
	cart = {}
	express = false
	_express.set_pressed_no_signal(false)
	_build_stall()
	say("Thank you! Your crates reach the back door in %s." % Market.clock(t))


static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

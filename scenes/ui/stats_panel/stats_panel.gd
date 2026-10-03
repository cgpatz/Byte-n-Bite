extends "res://scenes/ui/common/art_window.gd"
## Player stats (Tab): the manager's profile card and a ledger of how many of
## each dish has been served. Counts are kept in GameState and saved with the game.
## Art: assets/ui/windows/stats/ (ledger, profile_card, portrait_frame, stat_tile,
## exp_bar_empty/full, stall_icon, title_paper) + recipe_book coin/lock/dish art.

const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const PixelArt := preload("res://scenes/art/pixel_art.gd")

const LEDGER := Vector2(712, 184)
## Ledger rows line up with the ruled lines in ledger.png (art px 16, 30, 44 …).
const FIRST_ROW_Y := 16 * 4
const ROW_H := 14 * 4

var _portrait: TextureRect
var _name: Label
var _manager: Label
var _level: Label
var _exp_text: Label
var _exp_fill: Control
var _restaurant: Label
var _restaurant_name: Label
var _served_total: Label
var _coins_total: Label
var _rows: Control
var _total_exp: Label
var _page := 0
var _page_buttons: Array[Button] = []
const PAGES := ["Restaurant", "Café Drinks", "Café Pastries"]


func _build() -> void:
	Art.panel(frame, "library/board.png", Rect2(152, 40, 1616, 1000), [6, 6, 6, 6], true)
	add_title_card("stats/title_paper.png", "Stats", Vector2(184, 64))
	add_close_button(Vector2(1572, 66))

	# Profile card.
	Art.panel(frame, "stats/profile_card.png", Rect2(184, 184, 496, 832), [2, 2, 4, 4])
	Art.image(frame, "library/pin_red.png", Vector2(418, 174))
	Art.image(frame, "stats/portrait_frame.png", Vector2(348, 216))
	var window := Control.new()       # inside of the frame (art px 4..36 × 4..50)
	window.clip_contents = true
	window.position = Vector2(364, 232)
	window.size = Vector2(128, 168)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(window)
	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(_portrait)
	_name = Art.label(frame, "", Vector2(200, 436), 34, Art.INK, false, 456, HORIZONTAL_ALIGNMENT_CENTER, Art.serif())
	_manager = Art.label(frame, "", Vector2(200, 478), 20, Art.INK_SOFT, false, 456, HORIZONTAL_ALIGNMENT_CENTER)
	Art.panel(frame, "recipe_book/badge_level.png", Rect2(340, 514, 176, 44), [2, 2, 2, 2])
	_level = Art.label(frame, "", Vector2(340, 518), 24, Art.CREAM, true, 176, HORIZONTAL_ALIGNMENT_CENTER)
	Art.label(frame, "EXP", Vector2(228, 566), 19, Art.RED_HEAD, true)
	_exp_text = Art.label(frame, "", Vector2(428, 566), 19, Art.INK, true, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	Art.image(frame, "stats/exp_bar_empty.png", Vector2(228, 600))
	_exp_fill = Control.new()
	_exp_fill.clip_contents = true
	_exp_fill.position = Vector2(228, 600)
	_exp_fill.size = Vector2(0, 28)
	_exp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_exp_fill)
	Art.image(_exp_fill, "stats/exp_bar_full.png", Vector2.ZERO)
	_total_exp = Art.label(frame, "", Vector2(228, 634), 18, Art.INK_SOFT, false, 400, HORIZONTAL_ALIGNMENT_RIGHT)
	Art.image(frame, "stats/stall_icon.png", Vector2(224, 684))
	_restaurant = Art.label(frame, "", Vector2(282, 680), 22, Art.INK, true)
	_restaurant_name = Art.label(frame, "", Vector2(282, 714), 20, Art.INK_SOFT)
	_served_total = _stat_tile(Vector2(220, 776), "dishes served", true)
	_coins_total = _stat_tile(Vector2(444, 776), "coins earned", false)

	# Ledger pages: restaurant dishes, Café drinks, Café pastries.
	for i in PAGES.size():
		var b := Art.button(frame, PAGES[i], Rect2(712 + i * 236, 112, 224, 60), false, 22)
		b.pressed.connect(func():
			_page = i
			_refresh())
		_page_buttons.append(b)
	# Ledger of dishes.
	Art.image(frame, "stats/ledger.png", LEDGER)
	Art.label(frame, "Dish", LEDGER + Vector2(68, 18), 22, Art.CREAM, true)
	Art.label(frame, "Served", LEDGER + Vector2(536, 18), 22, Art.CREAM, true, 200, HORIZONTAL_ALIGNMENT_CENTER)
	Art.label(frame, "Price", LEDGER + Vector2(764, 18), 22, Art.CREAM, true, 150, HORIZONTAL_ALIGNMENT_CENTER)
	Art.label(frame, "Earned", LEDGER + Vector2(886, 18), 22, Art.CREAM, true, 120, HORIZONTAL_ALIGNMENT_CENTER)
	_rows = Control.new()
	_rows.position = LEDGER
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_rows)
	GameState.stats_changed.connect(_on_stats_changed)


func _stat_tile(pos: Vector2, caption: String, dish_icon: bool) -> Label:
	Art.image(frame, "stats/stat_tile.png", pos)
	var icon := TextureRect.new()
	icon.texture = Art.dish_art("EGSILOG") if dish_icon else Art.tex("recipe_book/coin.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = pos + Vector2(70, 12)
	icon.size = Vector2(56, 40)
	frame.add_child(icon)
	var value := Art.label(frame, "0", pos + Vector2(0, 52), 44, Art.GOLD, false, 192, HORIZONTAL_ALIGNMENT_CENTER, Art.serif())
	Art.label(frame, caption, pos + Vector2(0, 118), 18, Art.CREAM, false, 192, HORIZONTAL_ALIGNMENT_CENTER)
	return value


func _on_stats_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	var gs = GameState
	# Profile.
	_name.text = gs.game_name if gs.game_name != "" else "Untitled game"
	_manager.text = "Manager: %s" % (gs.manager_name if gs.manager_name != "" else "Manager")
	_level.text = "Lv %d" % gs.player_level
	var need: int = gs.exp_needed()
	_exp_text.text = ("%d / %d" % [gs.player_exp, need]) if need > 0 else "MAX"
	if need <= 0:
		_exp_text.text = "%d / %d (max)" % [gs.total_exp(), gs.total_exp_to_max()]
	_total_exp.text = "Total EXP earned: %d / %d" % [gs.total_exp(), gs.total_exp_to_max()]
	var ratio := 1.0 if need <= 0 else clampf(float(gs.player_exp) / need, 0.0, 1.0)
	_exp_fill.size.x = roundf(400 * ratio / 4.0) * 4.0
	_restaurant.text = "Restaurant Lv %d" % gs.restaurant_level
	_restaurant_name.text = gs.level_data().display_name
	_served_total.text = str(gs.total_dishes_served())
	_coins_total.text = str(gs.coins_from_sales)
	_show_portrait()
	# Ledger rows.
	for c in _rows.get_children():
		c.queue_free()
	for i in _page_buttons.size():
		Art.set_button_look(_page_buttons[i], i == _page, 22)
	var keys: Array = Kitchen.restaurant_menu()
	if _page > 0:
		keys = []
		for d in Kitchen.cafe_menu():
			if Kitchen.DISHES[d].kind == ("drink" if _page == 1 else "pastry"):
				keys.append(d)
	for i in keys.size():
		_add_row(i, keys[i])


func _add_row(i: int, dish: String) -> void:
	var d: Dictionary = Kitchen.DISHES[dish]
	var y := FIRST_ROW_Y + i * ROW_H
	var row := Control.new()
	row.position = Vector2(0, y)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(row)
	var locked := Kitchen.available(dish, GameState.restaurant_level, GameState.cafe_step) != ""
	var ty := 12.0
	if locked:
		Art.image(row, "recipe_book/lock.png", Vector2(16, 10))
		Art.label(row, d.title, Vector2(68, ty), 22, Art.INK_LOCKED)
		var badge := Panel.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.91, 0.86, 0.76)
		st.border_color = Color(0.62, 0.52, 0.42)
		st.set_border_width_all(4)
		st.shadow_color = Color(0.62, 0.52, 0.42, 0.6)
		st.shadow_offset = Vector2(0, 4)
		badge.add_theme_stylebox_override("panel", st)
		badge.position = Vector2(516, 8)
		badge.size = Vector2(240, 36)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)
		var tag := "Restaurant Lv %d" % d.level
		if d.has("cafe") and GameState.restaurant_level >= d.level:
			tag = "Café locked" if GameState.cafe_step < 1 else "Café set %d" % d.cafe
		Art.label(row, tag, Vector2(516, 13), 17, Art.INK_SOFT, true, 240, HORIZONTAL_ALIGNMENT_CENTER)
		Art.label(row, str(d.price), Vector2(764, ty), 22, Art.INK_LOCKED, false, 150, HORIZONTAL_ALIGNMENT_CENTER)
		Art.label(row, "–", Vector2(886, ty), 22, Art.INK_LOCKED, false, 120, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var count := int(GameState.dishes_served.get(dish, 0))
	var icon := TextureRect.new()
	icon.texture = Art.dish_art(dish)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(6, 4)
	icon.size = Vector2(52, 44)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	Art.label(row, d.title, Vector2(68, ty), 22, Art.INK, true)
	Art.label(row, str(count), Vector2(536, ty - 2), 25, Art.INK, true, 200, HORIZONTAL_ALIGNMENT_CENTER)
	Art.image(row, "recipe_book/coin.png", Vector2(784, 10))
	Art.label(row, str(d.price), Vector2(828, ty), 22, Art.INK, true)
	Art.label(row, str(count * int(d.price)), Vector2(886, ty), 22, Art.INK, true, 120, HORIZONTAL_ALIGNMENT_CENTER)


## The manager's picture: first frame (standing, facing down) of manager art.
func _show_portrait() -> void:
	var tex := PixelArt.character("character", "manager")
	if tex == null:
		_portrait.texture = null
		return
	var frame_tex: Texture2D = tex
	if tex.resource_path.ends_with("_sheet.png") and int(tex.get_height()) % 4 == 0:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, PixelArt.FRAME_WIDTH, tex.get_height() / 4.0)
		frame_tex = at
	var s := frame_tex.get_size()
	var k := maxf(1.0, floorf(minf(128.0 / s.x, 184.0 / s.y)))
	_portrait.texture = frame_tex
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.size = s * k
	_portrait.position = Vector2((128 - s.x * k) / 2.0, 168 - s.y * k + 16)

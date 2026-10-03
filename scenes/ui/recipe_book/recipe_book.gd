extends "res://scenes/ui/common/art_window.gd"
## Recipe Book (R).
##  Dishes / Café tabs: each dish's picture, price and ingredients (and where to
##  get and cook them). The steps are left out on purpose: the player works out
##  the program themselves.
##  Kitchen Functions tab: C syntax lessons and every kitchen function; click one
##  to see its syntax, explanation, a short tutorial and an example.
## Art: assets/ui/windows/recipe_book/ (book, tabs, row_selected, badges, coin,
## lock, ribbon, code_card, dish_<name>.png pictures). Help text:
## data/help/c_reference.gd.

const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const Reference := preload("res://data/help/c_reference.gd")
const PANEL_SCRIPT := preload("res://scenes/ui/programming_panel/programming_panel.gd")
const PixelArt := preload("res://scenes/art/pixel_art.gd")

const BOOK := Vector2(264, 110)
const LEFT := Rect2(320, 150, 600, 820)      # left page content
const RIGHT := Rect2(992, 150, 624, 816)     # right page content
const ROW_Y := 220

enum Tab { DISHES, CAFE, FUNCTIONS }

var _tabs: Array[Button] = []
var _tab := Tab.DISHES
var _list_page: Control
var _functions_page: Control
var _rows_root: Control
var _row_highlight: NinePatchRect
var _list_title: Label
var _unlocked_label: Label
var _keys: Array = []
var _row_h := 56
var _selected := {Tab.DISHES: 0, Tab.CAFE: 0}

# Right page (dish details)
var _title: Label
var _art: TextureRect
var _no_art: Label
var _price: Label
var _level: Label
var _code_name: Label
var _details: VBoxContainer

# Kitchen Functions
var _entries: Array = []
var _entry_buttons: Array[Button] = []
var _entry_selected := 0
var _help: VBoxContainer
var _help_scroll: ScrollContainer


func _build() -> void:
	_tabs.append(_make_tab("Dishes", "recipe_book/tab_dishes.png", Rect2(340, 52, 184, 64)))
	_tabs.append(_make_tab("Café", "recipe_book/tab_dishes.png", Rect2(536, 52, 160, 64)))
	_tabs.append(_make_tab("Kitchen Functions", "recipe_book/tab_functions.png", Rect2(708, 52, 312, 64)))
	for i in _tabs.size():
		_tabs[i].pressed.connect(_show_tab.bind(i))
	window_rect = Rect2(BOOK, Vector2(1392, 920))
	Art.panel(frame, "recipe_book/book.png", Rect2(BOOK, Vector2(1392, 920)), [10, 10, 10, 10])
	Art.image(frame, "recipe_book/ribbon.png", BOOK + Vector2(944 - 264, 26))
	add_close_button(Vector2(1460, 26))

	_list_page = _page()
	_build_list()
	_build_dish_details()
	_functions_page = _page()
	_build_functions()


func _page() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = DESIGN
	frame.add_child(c)
	return c


func _make_tab(text: String, art: String, rect: Rect2) -> Button:
	var b := Art.button(frame, text, rect, false, 26)
	b.set_meta("art", art)
	return b


func _show_tab(tab: int) -> void:
	_tab = tab
	_list_page.visible = tab != Tab.FUNCTIONS
	_functions_page.visible = tab == Tab.FUNCTIONS
	for i in _tabs.size():
		var b := _tabs[i]
		var on := i == tab
		if on:
			var st := Art.style(b.get_meta("art"), [4, 4, 4, 5], Vector4(20, 6, 20, 10))
			for k in ["normal", "hover", "pressed", "hover_pressed"]:
				b.add_theme_stylebox_override(k, st)
			for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(k, Color(0.29, 0.15, 0.06))
		else:
			Art.set_button_look(b, false, 24)
		b.position.y = 52 if on else 62
	if tab != Tab.FUNCTIONS:
		_fill_list()


# --- Dishes / Café lists ----------------------------------------------------------------

func _build_list() -> void:
	_list_title = Art.label(_list_page, "Recipes", LEFT.position + Vector2(0, -6), 46, Art.INK, false, 0, HORIZONTAL_ALIGNMENT_LEFT, Art.serif())
	_unlocked_label = Art.label(_list_page, "", Vector2(600, 166), 21, Art.INK_SOFT, false, 316, HORIZONTAL_ALIGNMENT_RIGHT)
	_row_highlight = Art.panel(_list_page, "recipe_book/row_selected.png", Rect2(LEFT.position.x, ROW_Y, 600, 48), [2, 2, 2, 2])
	_rows_root = Control.new()
	_rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_page.add_child(_rows_root)


func _fill_list() -> void:
	var cafe := _tab == Tab.CAFE
	_keys = Kitchen.cafe_menu() if cafe else Kitchen.restaurant_menu()
	_row_h = 48 if cafe else 56
	_list_title.text = "Café Menu" if cafe else "Recipes"
	for c in _rows_root.get_children():
		c.queue_free()
	var open := 0
	for i in _keys.size():
		var dish: String = _keys[i]
		if _is_open(dish):
			open += 1
		_rows_root.add_child(_make_row(i, dish))
	if cafe:
		_unlocked_label.text = "Café locked" if GameState.cafe_step < 1 else "%d of %d on your menu" % [open, _keys.size()]
	else:
		_unlocked_label.text = "%d of %d unlocked" % [open, _keys.size()]
	_show_dish(clampi(_selected[_tab], 0, _keys.size() - 1))


func _is_open(dish: String) -> bool:
	return Kitchen.available(dish, GameState.restaurant_level, GameState.cafe_step) == ""


func _make_row(i: int, dish: String) -> Button:
	var d: Dictionary = Kitchen.DISHES[dish]
	var row := Button.new()
	row.flat = true
	row.position = Vector2(LEFT.position.x, ROW_Y + i * _row_h)
	row.size = Vector2(600, _row_h - 4)
	row.focus_mode = Control.FOCUS_NONE
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		row.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	row.pressed.connect(_show_dish.bind(i))
	row.mouse_entered.connect(func(): row.modulate = Color(1.06, 1.03, 0.95))
	row.mouse_exited.connect(func(): row.modulate = Color.WHITE)
	var line := ColorRect.new()
	line.color = Color(0.87, 0.8, 0.67)
	line.position = Vector2(0, _row_h - 4)
	line.size = Vector2(600, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var ty := (_row_h - 4 - 34) / 2.0
	if not _is_open(dish):
		Art.image(row, "recipe_book/lock.png", Vector2(16, ty + 2))
		Art.label(row, d.title, Vector2(64, ty), 23, Art.INK_LOCKED)
		var tag := ("Set %d" % d.cafe) if d.has("cafe") else ("Lv %d" % d.level)
		Art.panel(row, "recipe_book/badge_locked.png", Rect2(500, ty - 2, 84, 38), [2, 2, 2, 2])
		Art.label(row, tag, Vector2(500, ty + 2), 18, Art.CREAM, true, 84, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var icon := TextureRect.new()
		icon.texture = Art.dish_art(dish)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(6, ty - 2)
		icon.size = Vector2(48, 38)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		Art.label(row, d.title, Vector2(64, ty), 23, Art.INK, true)
		if d.has("kind"):
			Art.label(row, d.kind, Vector2(484, ty + 2), 18, Art.INK_SOFT, false, 100, HORIZONTAL_ALIGNMENT_RIGHT)
	return row


# --- Dish details (right page) -------------------------------------------------------

func _build_dish_details() -> void:
	_title = Art.label(_list_page, "", RIGHT.position + Vector2(0, -4), 60, Art.INK, false, 610, HORIZONTAL_ALIGNMENT_LEFT, Art.serif())
	var bar := ColorRect.new()
	bar.color = Color(0.7, 0.36, 0.16)
	bar.position = Vector2(992, 238)
	bar.size = Vector2(610, 6)
	_list_page.add_child(bar)
	# Badges: price, level, code name.
	Art.panel(_list_page, "recipe_book/badge_price.png", Rect2(992, 262, 136, 44), [2, 2, 2, 2])
	Art.image(_list_page, "recipe_book/coin.png", Vector2(998, 266))
	_price = Art.label(_list_page, "", Vector2(1040, 266), 22, Art.INK, true)
	Art.panel(_list_page, "recipe_book/badge_level.png", Rect2(1144, 262, 136, 44), [2, 2, 2, 2])
	_level = Art.label(_list_page, "", Vector2(1144, 266), 20, Art.CREAM, true, 136, HORIZONTAL_ALIGNMENT_CENTER)
	Art.panel(_list_page, "recipe_book/badge_locked.png", Rect2(1296, 262, 306, 44), [2, 2, 2, 2])
	_code_name = Art.label(_list_page, "", Vector2(1296, 270), 19, Art.GOLD, false, 306, HORIZONTAL_ALIGNMENT_CENTER, Art.mono())
	# The dish picture.
	var plate := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.96, 0.91, 0.8)
	st.border_color = Color(0.85, 0.75, 0.6)
	st.set_border_width_all(4)
	st.set_corner_radius_all(12)
	plate.add_theme_stylebox_override("panel", st)
	plate.position = Vector2(992, 326)
	plate.size = Vector2(610, 250)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_page.add_child(plate)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.position = Vector2(1012, 340)
	_art.size = Vector2(570, 222)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_page.add_child(_art)
	_no_art = Art.label(_list_page, "", Vector2(992, 420), 22, Art.INK_LOCKED, false, 610, HORIZONTAL_ALIGNMENT_CENTER)

	_details = VBoxContainer.new()
	_details.position = Vector2(992, 592)
	_details.size = Vector2(610, 370)
	_details.add_theme_constant_override("separation", 4)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_page.add_child(_details)


func _refresh() -> void:
	_entries = Reference.entries()
	_fill_entries()
	_show_tab(_tab)


func _show_dish(index: int) -> void:
	if _keys.is_empty():
		return
	_selected[_tab] = index
	_row_highlight.position.y = ROW_Y + index * _row_h + (_row_h - 52) / 2.0
	_row_highlight.size.y = 48
	var dish: String = _keys[index]
	var d: Dictionary = Kitchen.DISHES[dish]
	_title.text = d.title
	var fs := 60
	while fs > 30 and Art.serif().get_string_size(d.title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 600:
		fs -= 4
	_title.add_theme_font_size_override("font_size", fs)
	_title.position.y = RIGHT.position.y - 4 + (60 - fs) * 0.8
	_price.text = str(d.price)
	_level.text = ("Café set %d" % d.cafe) if d.has("cafe") else ("Level %d" % d.level)
	_code_name.text = dish
	var pic := Art.dish_art(dish)
	_art.texture = pic
	_no_art.text = "" if pic else "Picture coming soon\n(assets/ui/windows/recipe_book/dish_%s.png)" % dish.to_lower()
	for c in _details.get_children():
		c.queue_free()
	var why := Kitchen.available(dish, GameState.restaurant_level, GameState.cafe_step)
	if why != "":
		_details.add_child(_text(why, 19, Color(0.7, 0.2, 0.12), true))
	_details.add_child(_heading("Ingredients"))
	for ing in d.recipe:
		_details.add_child(_ingredient_row(ing, int(d.recipe[ing])))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_details.add_child(gap)
	_details.add_child(_text("Your turn: plan the steps and write them in a staff program. Stuck? See Kitchen Functions.", 18, Art.INK_SOFT))


func _ingredient_row(ing: String, n: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 38)
	var icon := TextureRect.new()
	icon.texture = PixelArt.food_icon(ing, false, false)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var how := "fresh, no cooking"
	if ing in Kitchen.NEEDS_COOKING:
		var where: Array = []
		var verb := "cook"
		for st in Kitchen.cook_stations(ing):
			where.append(st)
			verb = Kitchen.COOK_VERB.get(st, "cook")
		how = "%s at %s" % [verb, " or ".join(where)]
	if not ing in Kitchen.STORAGE.FRIDGE:
		var from: Array = []
		for st in Kitchen.STORAGE:
			if ing in Kitchen.STORAGE[st]:
				from.append(st)
		how += "  ·  from " + " or ".join(from)
	var name_l := _text("%s%s" % [ing, (" ×%d" % n) if n > 1 else ""], 20, Art.INK, true)
	name_l.custom_minimum_size = Vector2(200, 0)
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_l)
	var how_l := _text(how, 19, Art.INK)
	how_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	how_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how_l.clip_text = true
	row.add_child(how_l)
	return row


func _heading(text: String, size := 30) -> Label:
	var h := Label.new()
	h.text = text
	h.add_theme_font_override("font", Art.serif())
	h.add_theme_font_size_override("font_size", size)
	h.add_theme_color_override("font_color", Art.RED_HEAD)
	h.add_theme_constant_override("outline_size", 0)
	return h


func _text(text: String, size := 20, color := Art.INK, bold := false) -> Label:
	var t := Label.new()
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", size)
	t.add_theme_color_override("font_color", color)
	t.add_theme_constant_override("outline_size", 0)
	if bold:
		t.add_theme_font_override("font", Art.bold_font())
	return t


# --- Kitchen Functions (C help) ------------------------------------------------------

func _build_functions() -> void:
	Art.label(_functions_page, "Kitchen Functions", LEFT.position + Vector2(0, -6), 40, Art.INK, false, 0, HORIZONTAL_ALIGNMENT_LEFT, Art.serif())
	Art.label(_functions_page, "Click a topic to learn it.", Vector2(320, 202), 19, Art.INK_SOFT)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(316, 236)
	scroll.size = Vector2(608, 732)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "TopicScroll"
	_functions_page.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "Topics"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	_help_scroll = ScrollContainer.new()
	_help_scroll.position = Vector2(988, 146)
	_help_scroll.size = Vector2(624, 822)
	_help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_functions_page.add_child(_help_scroll)
	_help = VBoxContainer.new()
	_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help.add_theme_constant_override("separation", 8)
	_help_scroll.add_child(_help)


func _fill_entries() -> void:
	var list: VBoxContainer = _functions_page.get_node("TopicScroll/Topics")
	for c in list.get_children():
		c.queue_free()
	_entry_buttons.clear()
	var group := ""
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		if e.group != group:
			group = e.group
			var h := _heading(group, 24)
			if list.get_child_count() > 0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 8)
				list.add_child(gap)
			list.add_child(h)
		var b := Button.new()
		b.text = e.title
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_constant_override("outline_size", 0)
		if e.group.begins_with("Kitchen"):
			b.add_theme_font_override("font", Art.mono())
		var locked: bool = e.level > GameState.restaurant_level
		if locked:
			b.icon = Art.tex("recipe_book/lock.png")
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 22)
		b.set_meta("locked", locked)
		b.pressed.connect(_show_entry.bind(i))
		list.add_child(b)
		_entry_buttons.append(b)
	_show_entry(clampi(_entry_selected, 0, _entries.size() - 1))


func _style_entry(b: Button, on: bool) -> void:
	var col := Art.INK_LOCKED if b.get_meta("locked") else Art.INK
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, Color(0.29, 0.15, 0.06) if on else col)
	var sel := Art.style("recipe_book/row_selected.png", [2, 2, 2, 2], Vector4(14, 2, 10, 2))
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.9, 0.8, 0.6, 0.5)
	hover.content_margin_left = 14
	var none := StyleBoxEmpty.new()
	none.content_margin_left = 14
	b.add_theme_stylebox_override("normal", sel if on else none)
	b.add_theme_stylebox_override("hover", sel if on else hover)
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("hover_pressed", sel)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _show_entry(i: int) -> void:
	_entry_selected = i
	for j in _entry_buttons.size():
		_style_entry(_entry_buttons[j], j == i)
	var e: Dictionary = _entries[i]
	for c in _help.get_children():
		c.queue_free()
	var t := _heading(e.title, 44)
	t.add_theme_color_override("font_color", Art.INK)
	_help.add_child(t)
	_help.add_child(_text(e.group, 18, Art.INK_SOFT))
	if e.level > GameState.restaurant_level:
		_help.add_child(_text("Unlocks at Restaurant Level %d. You can read about it now." % e.level, 19, Color(0.7, 0.2, 0.12), true))
	_help.add_child(_heading("Syntax", 26))
	_help.add_child(_code_card(e.syntax))
	if not e.get("points", []).is_empty():
		_help.add_child(_heading("Syntax explained", 26))
		for p in e.points:
			_help.add_child(_text("•  " + p, 19))
	_help.add_child(_heading("What it does", 26))
	_help.add_child(_text(e.about, 20))
	if not e.steps.is_empty():
		_help.add_child(_heading("How to use it", 26))
		for s in e.steps.size():
			_help.add_child(_text("%d.  %s" % [s + 1, e.steps[s]], 20))
	_help.add_child(_heading("Example", 26))
	_help.add_child(_code_card(e.example))
	if not e.get("mistakes", []).is_empty():
		_help.add_child(_heading("Common mistakes", 26))
		for m in e.mistakes:
			_help.add_child(_text("•  " + m, 19, Color(0.55, 0.2, 0.12)))
	if not e.get("related", []).is_empty():
		var rel: Array = []
		for r in e.related:
			rel.append(r + "()")
		_help.add_child(_text("See also: " + ", ".join(rel), 19, Art.INK_SOFT, true))
	if e.get("w3", "") != "":
		var link := Art.button(_help, "Learn more on W3Schools", Rect2(0, 0, 340, 56), false, 20)
		link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		link.custom_minimum_size = Vector2(340, 56)
		link.tooltip_text = e.w3
		link.pressed.connect(func(): OS.shell_open(e.w3))
		_help.add_child(_text("Syntax notes follow the W3Schools C Tutorial (w3schools.com/c).", 16, Art.INK_SOFT))
	_help_scroll.scroll_vertical = 0


## Read-only code on the dark code card, sized to fit its lines.
func _code_card(code: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Art.style("recipe_book/code_card.png", [4, 4, 4, 4], Vector4(20, 14, 16, 14)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ce := CodeEdit.new()
	ce.text = code
	ce.editable = false
	ce.context_menu_enabled = false
	ce.scroll_fit_content_height = true
	ce.add_theme_font_override("font", Art.mono())
	ce.add_theme_font_size_override("font_size", 18)
	ce.add_theme_constant_override("line_spacing", 6)
	ce.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	ce.add_theme_color_override("font_readonly_color", Color(0.92, 0.9, 0.85))
	ce.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	ce.add_theme_color_override("current_line_color", Color(0, 0, 0, 0))
	var empty := StyleBoxEmpty.new()
	for k in ["normal", "read_only", "focus"]:
		ce.add_theme_stylebox_override(k, empty)
	ce.syntax_highlighter = Art.c_highlighter(PANEL_SCRIPT.C_KEYWORDS, PANEL_SCRIPT.C_UNSUPPORTED)
	ce.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(ce)
	return card

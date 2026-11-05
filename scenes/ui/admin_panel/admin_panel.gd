extends Control
## Admin panel for Admin Runs (F10): set or add coins, jump to any restaurant
## level, jump to any player (manager) level, add EXP, open the ready-to-copy
## Code Sets, ingredient tools. Sections are tabs that scroll on their own.
## Only reachable when the game was started with the editor-only Admin Run button.

signal closed
## Asks Game to open the Code Sets window (ready-to-copy programs).
signal code_sets_requested

const QUICK_AMOUNTS := [100, 1000, 10000]

@onready var coins_input: SpinBox = %CoinsInput
@onready var set_button: Button = %SetButton
@onready var quick_row: HBoxContainer = %QuickRow
@onready var level_row: HBoxContainer = %LevelRow
@onready var close_button: Button = %CloseButton

var _level_buttons: Array[Button] = []
var _player_buttons: Array[Button] = []
var _player_info: Label
var _tabs: TabContainer
var _progress_info: Label
var _speed_buttons: Array[Button] = []
var _quick_info: Label
const CodeSets := preload("res://data/help/code_sets.gd")


func _ready() -> void:
	set_button.pressed.connect(_on_set_pressed)
	coins_input.get_line_edit().text_submitted.connect(func(_t): _on_set_pressed())
	close_button.pressed.connect(close)

	for amount in QUICK_AMOUNTS:
		_add_button(quick_row, "+%d" % amount, _add_coins.bind(amount))
	_add_button(quick_row, "Reset to 0", _set_coins.bind(0))

	for lv in range(1, GameState.MAX_RESTAURANT_LEVEL + 1):
		var b := _add_button(level_row, "Lv %d" % lv, _set_level.bind(lv))
		b.tooltip_text = GameState.level_data(lv).display_name
		_level_buttons.append(b)

	# Art preview: hide the placeholder boxes to see your art (collisions stay).
	var art_title := Label.new()
	art_title.text = "Art Preview"
	art_title.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
	art_title.add_theme_font_size_override("font_size", 28)
	level_row.get_parent().add_child(art_title)
	level_row.get_parent().move_child(art_title, level_row.get_index() + 1)
	var placeholders := CheckBox.new()
	placeholders.text = "Show placeholder boxes"
	placeholders.button_pressed = true
	placeholders.add_theme_font_size_override("font_size", 22)
	placeholders.toggled.connect(_on_placeholders_toggled)
	level_row.get_parent().add_child(placeholders)
	level_row.get_parent().move_child(placeholders, art_title.get_index() + 1)

	_build_player_section(placeholders.get_index() + 1)

	# Ready-to-copy code for every level, lesson and dish.
	var box := level_row.get_parent()
	var code_title := Label.new()
	code_title.text = "Code Sets"
	code_title.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
	code_title.add_theme_font_size_override("font_size", 28)
	box.add_child(code_title)
	box.move_child(code_title, _player_info.get_index() + 1)
	var code_row := HBoxContainer.new()
	box.add_child(code_row)
	box.move_child(code_row, code_title.get_index() + 1)
	_add_button(code_row, "Open ready-to-copy code", _on_code_sets)
	# One-click answers for what the player is on right now.
	var now_row := HBoxContainer.new()
	box.add_child(now_row)
	box.move_child(now_row, code_row.get_index() + 1)
	_add_button(now_row, "Copy current quest answer", _quick.bind("quest", "copy"))
	_add_button(now_row, "Give it & Run", _quick.bind("quest", "run"))
	var ch_row := HBoxContainer.new()
	box.add_child(ch_row)
	box.move_child(ch_row, now_row.get_index() + 1)
	_add_button(ch_row, "Copy next challenge code", _quick.bind("challenge", "copy"))
	_add_button(ch_row, "Give it & Run", _quick.bind("challenge", "run"))
	_quick_info = Label.new()
	_quick_info.add_theme_font_size_override("font_size", 18)
	_quick_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_quick_info)
	box.move_child(_quick_info, ch_row.get_index() + 1)

	# Ingredients and the Market.
	var ing_title := Label.new()
	ing_title.text = "Ingredients & Market"
	ing_title.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
	ing_title.add_theme_font_size_override("font_size", 28)
	box.add_child(ing_title)
	box.move_child(ing_title, _quick_info.get_index() + 1)
	var ing_row := HBoxContainer.new()
	box.add_child(ing_row)
	box.move_child(ing_row, ing_title.get_index() + 1)
	_add_button(ing_row, "+20 of each", func():
		for ing in GameState.Kitchen.INGREDIENTS:
			GameState.add_ingredient(ing, 20))
	_add_button(ing_row, "Restock Market", func():
		GameState.market_restock_left = 0.0
		GameState.tick_market(0.0))
	_add_button(ing_row, "Deliveries arrive now", func():
		for dv in GameState.deliveries:
			dv.left = 0.0
		GameState.tick_market(0.0))
	var unlimited := CheckBox.new()
	unlimited.text = "Unlimited ingredients"
	unlimited.button_pressed = GameState.unlimited_ingredients
	unlimited.add_theme_font_size_override("font_size", 22)
	unlimited.toggled.connect(func(on: bool): GameState.unlimited_ingredients = on)
	box.add_child(unlimited)
	box.move_child(unlimited, ing_row.get_index() + 1)

	GameState.money_changed.connect(func(_m): _refresh())
	GameState.player_exp_changed.connect(func(_l, _e, _n): _refresh())
	GameState.restaurant_level_changed.connect(func(_l): _refresh())
	_organize_tabs()
	_build_progress_tab()
	_build_world_tab()
	GameState.quests_changed.connect(_refresh)
	GameState.stats_changed.connect(_refresh)


## Puts the sections into tabs (each scrolls on its own) so the panel stays a
## fixed size: Code · Coins · Manager · Market (+ Progress and World, built below).
func _organize_tabs() -> void:
	var box: VBoxContainer = level_row.get_parent()
	var header := box.get_child(0)
	var groups := {"Coins": "Coins", "Restaurant Level": "Coins",
		"Manager Level & EXP": "Manager", "Ingredients & Market": "Market",
		"Art Preview": "Code", "Code Sets": "Code"}
	var order := ["Code", "Coins", "Manager", "Market"]
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(680, 470)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 20)
	var pages := {}
	for name in order:
		var sc := ScrollContainer.new()
		sc.name = name
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 12)
		sc.add_child(v)
		tabs.add_child(sc)
		pages[name] = v
	var current := "Coins"
	for c in box.get_children().duplicate():
		if c == header or c == close_button:
			continue
		if c is Label and groups.has((c as Label).text):
			current = groups[(c as Label).text]
		box.remove_child(c)
		pages["Coins" if c.name == "Note" else current].add_child(c)
	box.add_child(tabs)
	box.move_child(tabs, 1)
	_tabs = tabs


## A new scrolling tab page.
func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	_tabs.add_child(sc)
	return v


func _section(parent: Container, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
	l.add_theme_font_size_override("font_size", 24)
	parent.add_child(l)


func _row(parent: Container) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	parent.add_child(r)
	return r


func _game() -> Node:
	return get_tree().get_first_node_in_group("game_root")


func _lv() -> int:
	return GameState.restaurant_level


## Progress: this level's Chef Miso quests, Level Challenge, goals, the tour and
## the upgrade, in one place (set things done or start them over).
func _build_progress_tab() -> void:
	var v := _page("Progress")
	_progress_info = Label.new()
	_progress_info.add_theme_font_size_override("font_size", 20)
	_progress_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_progress_info)
	_section(v, "Chef Miso quests")
	var q := _row(v)
	_add_button(q, "Next quest ✔", func():
		GameState.complete_miso_quest(_lv(), GameState.miso_progress(_lv())))
	_add_button(q, "All quests ✔", func():
		GameState.quest_progress[str(_lv())] = GameState.MisoQuests.for_level(_lv()).size()
		GameState.quests_changed.emit())
	_add_button(q, "Reset", func(): GameState.reset_level_progress(_lv(), "quests"))
	_section(v, "Level Challenge & Mastery")
	var c := _row(v)
	_add_button(c, "All challenges ✔", func():
		for g in GameState.challenges_left(_lv()):
			GameState.complete_challenge(_lv(), g.id))
	_add_button(c, "All Mastery ✔", func():
		for m in GameState.LevelChallenges.mastery_for(_lv()):
			GameState.complete_mastery(_lv(), m.id))
	_add_button(c, "Reset", func(): GameState.reset_level_progress(_lv(), "challenges"))
	var once := CheckBox.new()
	once.text = "One challenge per Run (like a real player)"
	once.add_theme_font_size_override("font_size", 20)
	once.toggled.connect(func(on: bool):
		var g := _game()
		if g:
			g.admin_one_per_run = on)
	v.add_child(once)
	_section(v, "Restaurant goals")
	var gr := _row(v)
	_add_button(gr, "All goals ✔", func():
		for g in GameState.goals_left(_lv()):
			GameState.complete_goal(_lv(), g.id))
	_add_button(gr, "+5 sales of each dish", func():
		var g := _game()
		for d in GameState.Kitchen.menu(_lv(), GameState.cafe_step):
			for k in 5:
				GameState.record_sale(d, int(GameState.Kitchen.DISHES[d].price), g.dish_cost(d) if g else 0))
	_add_button(gr, "Reset", func(): GameState.reset_level_progress(_lv(), "goals"))
	_section(v, "Tour & upgrade")
	var t := _row(v)
	_add_button(t, "Skip tour", func():
		var g := _game()
		if g and g.guide and g.guide.is_running():
			g.guide._end())
	_add_button(t, "Replay tour", func():
		var g := _game()
		GameState.guides_done.erase(_lv())
		if g and g.guide:
			close()
			g.guide.run(_lv(), true))
	_add_button(t, "Finish level & upgrade", func():
		var lv := _lv()
		if lv >= GameState.MAX_RESTAURANT_LEVEL:
			return
		GameState.quest_progress[str(lv)] = GameState.MisoQuests.for_level(lv).size()
		for g in GameState.challenges_left(lv):
			GameState.complete_challenge(lv, g.id)
		for g in GameState.goals_left(lv):
			GameState.complete_goal(lv, g.id)
		GameState.money = maxi(GameState.money, GameState.level_data().upgrade_cost)
		GameState.upgrade_restaurant())


## World: customers (with an order size), game speed, day / evening, moving the
## Manager and test deliveries.
func _build_world_tab() -> void:
	var v := _page("World")
	_section(v, "Customers")
	var cr := _row(v)
	for q in [1, 2, 3]:
		_add_button(cr, "Customer ×%d" % q, _spawn.bind(q))
	_add_button(cr, "Clear all", func():
		var g := _game()
		if g:
			g._clear_customers()
			g.orders.clear()
			g._refresh_tickets())
	_section(v, "Game speed")
	var sp := _row(v)
	for k in [1.0, 2.0, 4.0]:
		var b := _add_button(sp, "%d×" % int(k), func():
			Engine.time_scale = k
			_refresh())
		_speed_buttons.append(b)
	_section(v, "Street")
	var st := _row(v)
	_add_button(st, "Auto", _evening.bind(-1))
	_add_button(st, "Day", _evening.bind(0))
	_add_button(st, "Evening", _evening.bind(1))
	_section(v, "Move the Manager")
	var mv := _row(v)
	_add_button(mv, "Entrance", _move.bind("entrance"))
	_add_button(mv, "Next to Jane", _move.bind("staff"))
	_add_button(mv, "Delivery yard", _move.bind("yard"))
	_section(v, "Deliveries")
	var dl := _row(v)
	_add_button(dl, "Free test delivery (truck)", func():
		var cart := {}
		for d in GameState.Kitchen.menu(_lv(), 0):
			for ing in GameState.Kitchen.DISHES[d].recipe:
				cart[ing] = 10
				if cart.size() >= GameState.crate_capacity():
					break
			if cart.size() >= GameState.crate_capacity():
				break
		var t := 5.0
		GameState.deliveries.append({"cart": cart, "left": t, "total": t, "waiting": false})
		GameState.deliveries_changed.emit()
		close())


func _spawn(q: int) -> void:
	var g := _game()
	if g == null:
		return
	var c = g.spawn_customer()
	if c:
		c.set_meta("qty", q)
	close()


func _evening(mode: int) -> void:
	var g := _game()
	if g:
		g.evening_override = mode
		g._update_evening()


func _move(where: String) -> void:
	var g := _game()
	if g == null:
		return
	var m: Node2D = g.manager
	match where:
		"entrance":
			m.global_position = g._outside_start() if g._level_has_outside() else g.restaurant.get_manager_spawn()
		"staff":
			var list: Array = g._staff_list()
			if not list.is_empty():
				m.global_position = (list[0] as Node2D).global_position + Vector2(0, 70)
		"yard":
			var r: Rect2 = g._yard_crate_rect() if g._level_has_outside() else Rect2()
			if r.size != Vector2.ZERO:
				m.global_position = r.get_center() + Vector2(0, r.size.y / 2.0 + 30)
	close()


## "Manager Level" title, Lv 1–10 buttons and EXP buttons.
func _build_player_section(at: int) -> void:
	var box := level_row.get_parent()
	var title := Label.new()
	title.text = "Manager Level & EXP"
	title.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	box.move_child(title, at)
	var grid := GridContainer.new()
	grid.columns = 5
	box.add_child(grid)
	box.move_child(grid, at + 1)
	for lv in range(1, GameState.Progression.MAX_PLAYER_LEVEL + 1):
		var b := _add_button(grid, "Lv %d" % lv, GameState.set_player_level.bind(lv))
		_player_buttons.append(b)
	var exp_row := HBoxContainer.new()
	box.add_child(exp_row)
	box.move_child(exp_row, at + 2)
	for amount in [25, 100, 500]:
		_add_button(exp_row, "+%d EXP" % amount, GameState.add_exp.bind(amount, "admin"))
	_add_button(exp_row, "Quest (+80)", func(): GameState.add_quest_exp("normal"))
	_player_info = Label.new()
	_player_info.add_theme_font_size_override("font_size", 20)
	box.add_child(_player_info)
	box.move_child(_player_info, at + 3)


func _on_code_sets() -> void:
	close()
	code_sets_requested.emit()


func _add_button(parent: Container, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func open() -> void:
	_refresh()
	show()
	coins_input.get_line_edit().grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _refresh() -> void:
	coins_input.set_value_no_signal(GameState.money)
	for i in _level_buttons.size():
		_level_buttons[i].disabled = (i + 1) == GameState.restaurant_level
	for i in _player_buttons.size():
		_player_buttons[i].disabled = (i + 1) == GameState.player_level
	if _progress_info:
		var lv := _lv()
		_progress_info.text = "Restaurant Lv %d · Chef Miso %d / %d · Challenges %d left · Goals %d left · Coins %d (upgrade %d)" % [
			lv, GameState.miso_progress(lv), GameState.MisoQuests.for_level(lv).size(), GameState.challenges_left(lv).size(),
			GameState.goals_left(lv).size(), GameState.money, GameState.level_data().upgrade_cost]
	for i in _speed_buttons.size():
		_speed_buttons[i].disabled = is_equal_approx(Engine.time_scale, [1.0, 2.0, 4.0][i])
	if _player_info:
		var names: Array = GameState.staff_roster().map(func(e): return e.name)
		_player_info.text = "Manager Lv %d  ·  EXP %d / %d  ·  Staff: %s" % [
			GameState.player_level, GameState.player_exp, GameState.exp_needed(), ", ".join(names)]


func _on_set_pressed() -> void:
	coins_input.apply()  # take what was typed even if Enter wasn't pressed
	_set_coins(int(coins_input.value))


func _set_coins(amount: int) -> void:
	GameState.money = maxi(amount, 0)


func _add_coins(amount: int) -> void:
	GameState.money += amount


func _set_level(level: int) -> void:
	# Same rule as a real upgrade: seating starts over at 1 table / 1 chair.
	GameState.table_chairs = GameState.START_SEATING.duplicate()
	GameState.restaurant_level = level
	GameState.seating_changed.emit()


func _on_placeholders_toggled(on: bool) -> void:
	var game := get_tree().current_scene
	if game and game.has_method("set_placeholders_visible"):
		game.set_placeholders_visible(on)


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("admin_panel")):
		get_viewport().set_input_as_handled()
		close()



## The ready answer for the quest the player is on, or the program for the
## first Level Challenge still to do. {} when there is none.
func _quick_set(kind: String) -> Dictionary:
	var lv := _lv()
	if kind == "quest":
		var k: int = GameState.miso_progress(lv)
		var prefix := "L%d Q%d:" % [lv, k + 1]
		for st in CodeSets.quest_sets():
			if String(st.title).begins_with(prefix) and not String(st.title).contains("(broken"):
				return st
		return {}
	var left: Array = GameState.challenges_left(lv)
	if left.is_empty():
		return {}
	var c0 = left[0]
	var title: String = String(c0.get("title", "")) if c0 is Dictionary else ""
	for st in CodeSets.single_challenge_sets():
		if st.title == "L%d: %s" % [lv, title]:
			return st
	return {"title": "Level %d challenges" % lv, "note": CodeSets.challenges_note(lv), "code": CodeSets.challenges_program(lv), "level": lv}


## Copy it to the clipboard, or load it into the first staff member and Run.
func _quick(kind: String, how: String) -> void:
	var st := _quick_set(kind)
	if st.is_empty():
		_quick_info.text = "Nothing to do: every %s at this level is done." % ("quest" if kind == "quest" else "challenge")
		return
	if how == "copy":
		DisplayServer.clipboard_set(String(st.code))
		_quick_info.text = "Copied: %s. Paste it into a staff editor with Ctrl+V." % st.title
		return
	var g := _game()
	var list: Array = g._staff_list() if g else []
	if list.is_empty():
		_quick_info.text = "No staff to give it to."
		return
	var staff: Node = list[0]
	staff.program_source = String(st.code)
	GameState.staff_programs[staff.staff_name] = staff.program_source
	if g.programming_panel and g.programming_panel.visible and g.programming_panel.staff == staff:
		g.programming_panel.code_edit.text = staff.program_source
	if staff.is_running():
		staff.restart_program()
	else:
		staff.run_program()
	close()

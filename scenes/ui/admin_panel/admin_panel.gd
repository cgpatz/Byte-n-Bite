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

	# Ingredients and the Market.
	var ing_title := Label.new()
	ing_title.text = "Ingredients & Market"
	ing_title.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
	ing_title.add_theme_font_size_override("font_size", 28)
	box.add_child(ing_title)
	box.move_child(ing_title, code_row.get_index() + 1)
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


## Puts the sections into tabs (each scrolls on its own) so the panel stays a
## fixed size: Coins & Level · Manager · Ingredients · Art & Code.
func _organize_tabs() -> void:
	var box: VBoxContainer = level_row.get_parent()
	var header := box.get_child(0)
	var groups := {"Coins": "Coins & Level", "Restaurant Level": "Coins & Level",
		"Manager Level & EXP": "Manager", "Ingredients & Market": "Ingredients",
		"Art Preview": "Art & Code", "Code Sets": "Art & Code"}
	var order := ["Coins & Level", "Manager", "Ingredients", "Art & Code"]
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(680, 470)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 22)
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
	var current := "Coins & Level"
	for c in box.get_children().duplicate():
		if c == header or c == close_button:
			continue
		if c is Label and groups.has((c as Label).text):
			current = groups[(c as Label).text]
		box.remove_child(c)
		pages["Coins & Level" if c.name == "Note" else current].add_child(c)
	box.add_child(tabs)
	box.move_child(tabs, 1)


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

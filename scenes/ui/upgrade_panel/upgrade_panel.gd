extends Control
## Restaurant level + seating upgrades (opened with U).
## Costs and caps come from data/levels/level_N.tres.

signal closed

@onready var level_info: Label = %LevelInfo
@onready var upgrade_button: Button = %UpgradeButton
@onready var seating_info: Label = %SeatingInfo
@onready var table_button: Button = %TableButton
@onready var chair_button: Button = %ChairButton
@onready var close_button: Button = %CloseButton
@onready var cafe_title: Label = %CafeTitle
@onready var cafe_info: Label = %CafeInfo
@onready var cafe_button: Button = %CafeButton

const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")


func _ready() -> void:
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	table_button.pressed.connect(func(): GameState.buy_table())
	chair_button.pressed.connect(func(): GameState.buy_chair())
	close_button.pressed.connect(close)
	cafe_button.pressed.connect(func(): GameState.buy_cafe_step())
	GameState.cafe_changed.connect(func(_s): _refresh())
	GameState.money_changed.connect(func(_m): _refresh())
	GameState.seating_changed.connect(_refresh)
	GameState.restaurant_level_changed.connect(func(_l): _refresh())


func open() -> void:
	_refresh()
	show()
	close_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _refresh() -> void:
	var gs = GameState
	var d: RestaurantLevelData = gs.level_data()
	var staff_n: int = gs.staff_roster().size()
	level_info.text = "Level %d: %s  ·  teaches %s  ·  %d staff" % [
		d.level, d.display_name, d.c_focus, staff_n]
	if gs.restaurant_level >= gs.MAX_RESTAURANT_LEVEL:
		upgrade_button.text = "Fully upgraded"
		upgrade_button.disabled = true
	else:
		var next: RestaurantLevelData = gs.level_data(gs.restaurant_level + 1)
		upgrade_button.text = "Upgrade to %s (%d coins)" % [next.display_name, d.upgrade_cost]
		upgrade_button.disabled = not gs.can_upgrade_restaurant()

	seating_info.text = "Tables: %d / %d  ·  Seats: %d  ·  Up to %d chairs per table" % [
		gs.tables_owned(), gs.table_limit(), gs.total_seats(), d.max_chairs_per_table]
	if 6 in gs.slot_chair_caps:
		seating_info.text += "  ·  family tables seat 6"
	if gs.tables_owned() >= gs.table_limit():
		table_button.text = "Table limit reached"
		if gs.table_limit() < d.table_cap:
			seating_info.text += "  ·  open the Café for %d more tables" % (d.table_cap - gs.table_limit())
	else:
		table_button.text = "Add Table (%d)" % gs.next_table_cost()
	table_button.disabled = not gs.can_buy_table()
	chair_button.text = "Add Chair (%d)" % d.chair_cost
	chair_button.disabled = not gs.can_buy_chair()
	_refresh_cafe()


func _refresh_cafe() -> void:
	var gs = GameState
	var step: int = gs.cafe_step
	if gs.restaurant_level < gs.MAX_RESTAURANT_LEVEL:
		cafe_info.text = "The Café opens at Restaurant Level %d (Grand Restaurant)." % gs.MAX_RESTAURANT_LEVEL
		cafe_button.text = "Locked"
		cafe_button.disabled = true
		return
	if step == 0:
		cafe_info.text = "Open the Café room: coffee drinks and pastries, starting with Macchiato. Café tables can be bought after."
		cafe_button.text = "Unlock the Café (%d coins)" % gs.next_cafe_cost()
	elif step >= Kitchen.CAFE_STEPS:
		cafe_info.text = "Café menu complete: %d / %d recipe sets." % [step, Kitchen.CAFE_STEPS]
		cafe_button.text = "Café menu complete"
		cafe_button.disabled = true
		return
	else:
		var names: Array = []
		for d in Kitchen.cafe_step_dishes(step + 1):
			names.append(Kitchen.title_of(d))
		cafe_info.text = "Café menu: %d / %d recipe sets bought." % [step, Kitchen.CAFE_STEPS]
		cafe_button.text = "Buy %s (%d coins)" % [" + ".join(names), gs.next_cafe_cost()]
	cafe_button.disabled = not gs.can_buy_cafe_step()


func _on_upgrade_pressed() -> void:
	if GameState.upgrade_restaurant():
		close()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("upgrades")):
		get_viewport().set_input_as_handled()
		close()

extends Node
## Game smoke test (press F6 on tests/GameSmokeTest.tscn; results in Output):
##  1. every restaurant level: Jane can reach every station
##  2. every dish on the menu is cooked, plated, assembled and served at its level
##  3. sales give coins + EXP; manager levels give rewards
##  4. staff join: Jane at start, John (Restaurant Lv 3), Lee (Manager Lv 5),
##     Rose (Restaurant Lv 5), Gab (Manager Lv 10) = 5 staff + the manager
##  5. save + load keeps names, levels and coins

const GAME := preload("res://scenes/game/Game.tscn")
const CodeSets := preload("res://data/help/code_sets.gd")
const LG_GOALS := preload("res://systems/goals/level_goals.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")

var _failed := 0
var game


func _ready() -> void:
	GameState.reset()
	GameState.money = 0
	game = GAME.instantiate()
	add_child(game)
	await get_tree().process_frame
	var jane: Staff = game.get_node("Characters/Staff/Jane")
	game.customers_enabled = false
	game.tutorials_enabled = false
	Engine.time_scale = 8.0

	for lv in range(1, GameState.MAX_RESTAURANT_LEVEL + 1):
		GameState.restaurant_level = lv
		await get_tree().process_frame
		await get_tree().process_frame
		if lv == GameState.MAX_RESTAURANT_LEVEL:
			# Café: door locked at first, then bought (all 10 recipe sets).
			var coffee: Station = game.get_station("COFFEE_MACHINE")
			_report(not game.find_path(jane.global_position, coffee, Staff.REACH).ok, "Café locked: COFFEE_MACHINE can't be reached")
			_report(GameState.table_limit() == GameState.level_data().table_cap - GameState.CAFE_TABLE_SLOTS, "Café locked: Café tables held back")
			jane.program_source = "void main() { go_to(FRIDGE); pick_up(COFFEE); }"
			jane.clear_log()
			await jane.run_program()
			_report(jane.log_text.contains("Unlock the Café"), "Café locked: COFFEE can't be picked up")
			GameState.money = 100000
			var bought := 0
			while GameState.buy_cafe_step():
				bought += 1
			await get_tree().process_frame
			_report(bought == 10 and GameState.cafe_step == 10 and GameState.current_menu().size() == 28, "Café bought: %d purchases, menu has %d dishes" % [bought, GameState.current_menu().size()])
		# 1. Reachability for every staff member on the team.
		for staff in game._staff_list():
			var missing: Array = []
			var count := 0
			for sname in Kitchen.STATIONS:
				var st: Station = game.get_station(sname)
				if st == null:
					continue
				count += 1
				if not game.find_path(staff.global_position, st, Staff.REACH).ok and not game.find_path(staff.global_position, st, Staff.FAR_REACH).ok:
					missing.append(sname)
			_report(missing.is_empty(), "Restaurant Lv %d: %s reaches %d stations %s" % [lv, staff.staff_name, count, "" if missing.is_empty() else "UNREACHABLE: %s" % ", ".join(missing)])
		# 2. Every dish new at this level.
		for dish in Kitchen.DISHES:
			if Kitchen.DISHES[dish].level != lv:
				continue
			var before := GameState.money
			game.place_order(null, dish)
			jane.program_source = "void main() {\n%s}" % CodeSets.dish_steps(dish, "    ")
			jane.clear_log()
			await jane.run_program()
			var price: int = Kitchen.DISHES[dish].price
			var ok := GameState.money >= before + price
			_report(ok, "Restaurant Lv %d: Jane makes %s with its Code Set (+%d coins)" % [lv, dish, price])
			if not ok:
				print(jane.log_text)
		# 2b. Level 5: the admin make_dish() Code Set makes every dish, Café included.
		if lv == 5:
			var bad: Array = []
			for dish in Kitchen.DISHES:
				var before2 := GameState.money
				game.place_order(null, dish)
				jane.program_source = CodeSets.make_dish() + "\nvoid main() { make_dish(next_order()); }"
				jane.clear_log()
				await jane.run_program()
				if GameState.money < before2 + int(Kitchen.DISHES[dish].price):
					bad.append(dish)
					print(jane.log_text)
			_report(bad.is_empty(), "Code Set make_dish() makes all %d dishes %s" % [Kitchen.DISHES.size(), "" if bad.is_empty() else "FAILED: %s" % ", ".join(bad)])

	# 3 + 4. Staff roster and manager levels.
	Engine.time_scale = 1.0
	GameState.restaurant_level = 1
	GameState.set_player_level(1)
	await get_tree().process_frame
	_report(game._staff_list().size() == 1, "Start: 1 staff (Jane)")
	GameState.restaurant_level = 3
	await get_tree().process_frame
	_report(_names() == ["Jane", "John"], "Restaurant Lv 3 adds John: %s" % [_names()])
	var coins := GameState.money
	var ups: Array = []
	GameState.player_leveled_up.connect(func(l, _r): ups.append(l))
	GameState.add_exp(100 + 160 + 240)  # Lv 1 -> 4
	await get_tree().process_frame
	_report(GameState.player_level == 4 and ups == [2, 3, 4], "500 EXP: Manager Lv 1 -> 4 (level-ups %s)" % [ups])
	_report(GameState.money == coins + 50 + 75 + 100, "Level-up coins +225 (got +%d)" % (GameState.money - coins))
	_report(not "Lee" in _names(), "Manager Lv 4: no new staff yet: %s" % [_names()])
	GameState.add_exp(340)
	await get_tree().process_frame
	_report("Lee" in _names(), "Manager Lv 5 adds Lee: %s" % [_names()])
	GameState.restaurant_level = 5
	GameState.set_player_level(10)
	await get_tree().process_frame
	_report(_names() == ["Jane", "John", "Lee", "Rose", "Gab"], "Restaurant Lv 5 + Manager Lv 10: all 5 staff %s" % [_names()])
	GameState.add_quest_exp("hard")
	_report(GameState.player_exp == 0, "No EXP past max level")
	GameState.restaurant_level = 1
	GameState.set_player_level(1)
	await get_tree().process_frame
	await get_tree().process_frame
	_report(_names() == ["Jane"], "Admin jump back to Lv 1: only Jane stays %s" % [_names()])

	# Seating: fill every table in every level with its maximum chairs.
	for lv in range(1, GameState.MAX_RESTAURANT_LEVEL + 1):
		GameState.restaurant_level = lv
		await get_tree().process_frame
		var d := GameState.level_data()
		var all: Array[int] = []
		for i in d.table_cap: all.append(1)
		GameState.table_chairs = all
		GameState.seating_changed.emit()
		await get_tree().process_frame
		var bought := 0
		GameState.money = 1000000
		while GameState.can_buy_chair():
			GameState.buy_chair()
			bought += 1
		var fam := GameState.slot_chair_caps.count(6)
		await get_tree().process_frame
		_report(GameState.total_seats() == GameState.slot_chair_caps.reduce(func(a, b): return a + b, 0),
			"Restaurant Lv %d: %d tables (%d family) seat %d" % [lv, d.table_cap, fam, GameState.total_seats()])
	# Stats + Library: Jane uses a Library function to make an Egsilog.
	GameState.restaurant_level = 1
	await get_tree().process_frame
	var served_before := int(GameState.dishes_served.get("EGSILOG", 0))
	GameState.library_slots = GameState.new_library()
	game.place_order(null, "EGSILOG")
	jane.program_source = "void main() { fetch_and_cook(RICE); fetch_and_cook(EGG); assemble(EGSILOG); go_to(SERVING_COUNTER); serve(); }"
	Engine.time_scale = 8.0
	await jane.run_program()
	Engine.time_scale = 1.0
	_report(int(GameState.dishes_served.get("EGSILOG", 0)) == served_before + 1, "Library function + stats: Egsilog count %d -> %d" % [served_before, GameState.dishes_served.get("EGSILOG", 0)])
	# Customers: one walks in, sits, orders; Jane takes the order and serves it.
	GameState.restaurant_level = 3
	await get_tree().process_frame
	await get_tree().process_frame
	_report(game.seats.size() >= 1, "Restaurant Lv 3 has %d seats (chairs + stools)" % game.seats.size())
	Engine.time_scale = 8.0
	var guest = game.spawn_customer("TOCILOG")
	_report(guest != null, "A customer walks in")
	var waited := 0
	while guest and guest.state != 1 and waited < 400:
		await get_tree().process_frame
		waited += 1
	_report(guest != null and guest.state == 1 and guest.dish == "TOCILOG", "Customer sat down and ordered %s" % (guest.dish if guest else "?"))
	var coins_before := GameState.money
	jane.program_source = _order_program()
	jane.clear_log()
	await jane.run_program()
	_report(GameState.money == coins_before + 45 and guest.state == 2, "take_order() walks to %s, Tocilog served (+%d)" % [guest.customer_name, GameState.money - coins_before])
	if GameState.money != coins_before + 45:
		print(jane.log_text)
	waited = 0
	while is_instance_valid(guest) and waited < 2000:
		await get_tree().process_frame
		waited += 1
	_report(not is_instance_valid(guest) and game.orders.is_empty(), "Customer ate and left")
	jane.program_source = _program_for("EGSILOG")
	await jane.run_program()
	_report(game.counter_dishes == ["EGSILOG"], "Unordered dish waits on the counter")
	game.place_order(null, "EGSILOG")
	game.take_order_now(null)
	_report(game.counter_dishes.is_empty() and game.orders.is_empty(), "A later order takes the dish from the counter once it's taken")
	var impatient = game.spawn_customer("HOTSILOG")
	waited = 0
	while impatient and impatient.state != 1 and waited < 400:
		await get_tree().process_frame
		waited += 1
	var lost := GameState.customers_lost
	impatient.waited = impatient.patience
	await get_tree().process_frame
	await get_tree().process_frame
	_report(GameState.customers_lost == lost + 1 and game.orders.is_empty(), "Customer who waits too long leaves and the order is cancelled")
	# Waiter + cook: John takes the order and posts a ticket; Jane checks the counter.
	var john: Staff = null
	for st in game._staff_list():
		if st.staff_name == "John":
			john = st
	var diner = game.spawn_customer("EGSILOG")
	waited = 0
	while diner and diner.state != 1 and waited < 400:
		await get_tree().process_frame
		waited += 1
	_report(diner != null and not diner.order_taken, "New customer shows '?' until someone takes the order")
	if john:
		john.program_source = "void main() {\n    int order = take_order();\n    go_to(SERVING_COUNTER);\n    post_order(order);\n}"
		john.clear_log()
		await john.run_program()
		_report(diner.order_taken and game.counter_tickets() == ["EGSILOG"], "Waiter John took the order and posted ticket %s" % [game.counter_tickets()])
		var coins_w := GameState.money
		jane.program_source = "void main() {\n    int order = check_counter();\n    if (order == EGSILOG) {\n%s    }\n}" % CodeSets.dish_steps("EGSILOG", "        ")
		jane.clear_log()
		await jane.run_program()
		_report(GameState.money >= coins_w + 30 and game.counter_tickets().is_empty() and diner.state == 2,
			"Cook Jane: check_counter() -> Egsilog served to %s (+%d)" % [diner.customer_name, GameState.money - coins_w])
		if GameState.money < coins_w + 30:
			print(john.log_text, "\n", jane.log_text)
	else:
		_report(false, "John is on the team at Restaurant Level 3")
	Engine.time_scale = 1.0
	# Arrays (Level 4): one generic program makes any dish with recipe() + cook_station().
	GameState.restaurant_level = 4
	await get_tree().process_frame
	await get_tree().process_frame
	Engine.time_scale = 8.0
	game.place_order(null, "CHICKEN_SANDWICH")
	var coins_arr := GameState.money
	jane.program_source = """void main() {
    int items[8];
    int order = next_order();
    int n = recipe(order, items);
    for (int i = 0; i < n; i++) {
        go_to(FRIDGE);
        pick_up(items[i]);
        int where = cook_station(items[i]);
        if (where != NOTHING) {
            go_to(where);
            cook();
        }
        go_to(ASSEMBLY);
        plate();
    }
    assemble(order);
    serve();
}"""
	jane.clear_log()
	await jane.run_program()
	_report(GameState.money >= coins_arr + 65, "Arrays: recipe() + cook_station() made a Chicken Sandwich (+%d)" % (GameState.money - coins_arr))
	if GameState.money < coins_arr + 65:
		print(jane.log_text)
	# Today's Special: at Restaurant Level 1 every customer orders it.
	GameState.restaurant_level = 1
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.todays_special = "EGSILOG"
	GameState.next_special()
	var special_guest = game.spawn_customer()
	waited = 0
	while special_guest and special_guest.state != 1 and waited < 600:
		await get_tree().process_frame
		waited += 1
	_report(GameState.todays_special == "HOTSILOG" and special_guest != null and special_guest.dish == "HOTSILOG" and special_guest.patience == 150.0,
		"Level 1 customer orders Today's Special (%s) with 150 s patience" % (special_guest.dish if special_guest else "?"))
	Engine.time_scale = 1.0
	# In-world upgrades: walk-up spots + confirmation (no Upgrades key).
	GameState.restaurant_level = 1
	GameState.table_chairs = GameState.START_SEATING.duplicate()
	GameState.seating_changed.emit()
	await get_tree().process_frame
	GameState.money = 5000
	var spot = null
	for c in game.tables_root.get_children():
		if c.get_script() == game.TABLE_SPOT_SCRIPT and not c.is_queued_for_deletion():
			spot = c
	_report(spot != null, "Level 1 shows a '+ Table' spot")
	if spot:
		game._offer_upgrade(spot)
		var asked: bool = game.confirm_dialog.visible
		game.confirm_dialog._confirm()
		await get_tree().process_frame
		_report(asked and GameState.tables_owned() == 2, "E on the '+ Table' spot asks, then buys a table (%d tables)" % GameState.tables_owned())
	var tbl = null
	for c in game.tables_root.get_children():
		if c is Table and not c.is_queued_for_deletion():
			tbl = c
	var ti: int = tbl.table_index
	game._offer_upgrade(tbl)
	game.confirm_dialog._confirm()
	await get_tree().process_frame
	_report(GameState.table_chairs[ti] == 2, "E on a table asks, then adds a chair")
	var board: Station = null
	for c in game.restaurant.get_node("Stations/Decor").get_children():
		if c is Station and c.opens == "upgrades":
			board = c
	# Level 1 challenges: the upgrade is locked until they're done.
	GameState.challenges_done = []
	game._offer_upgrade(board)
	_report(game.confirm_dialog.visible and game.confirm_dialog._yes.disabled, "Upgrade locked until the Level 1 challenges are done")
	game.confirm_dialog.close()
	jane.program_source = "void main() { int served = 0; float price = 30.50; char size = 'L'; go_to(FRIDGE); pick_up(EGG); printf(\"%d %.2f %c\\n\", served, price, size); }"
	await jane.run_program()
	_report(GameState.challenges_done.is_empty(), "No goal without serving a dish")
	game.place_order(null, "EGSILOG")
	var coins_g := GameState.money
	jane.program_source = CodeSets.level1_challenges("EGSILOG")
	jane.clear_log()
	Engine.time_scale = 8.0
	await jane.run_program()
	Engine.time_scale = 1.0
	_report(GameState.challenges_left(1).is_empty() and GameState.money >= coins_g + 220,
		"Level 1 challenges: int/%%d, float/%%.2f, char/%%c and the receipt all done (%s, +%d coins)" % [GameState.challenges_done, GameState.money - coins_g])
	if not GameState.challenges_left(1).is_empty():
		print(jane.log_text)
	# Level 1 goals: 10 Hotsilog, 10 Egsilog, 300 profit (counted from sales at this level).
	GameState.goals_reached = []
	GameState.level_sales = {}
	_report(not GameState.can_upgrade_restaurant(), "Upgrade still locked until the Level 1 goals are reached")
	var exp_g := GameState.total_exp()
	for k in 10:
		GameState.record_sale("EGSILOG", 30)
	_report(GameState.goal_reached_at(1, "egsilog") and not GameState.goal_reached_at(1, "hotsilog") and GameState.goal_reached_at(1, "profit"),
		"Goals: 10 Egsilog reached, profit 300 reached, Hotsilog %d / 10" % GameState.goal_progress(LG_GOALS.find(1, "hotsilog")))
	for k in 10:
		GameState.record_sale("HOTSILOG", 40)
	_report(GameState.goals_left(1).is_empty() and GameState.total_exp() > exp_g, "All Level 1 goals reached (+%d EXP)" % (GameState.total_exp() - exp_g))
	game._offer_upgrade(board)
	game.confirm_dialog.close()
	_report(GameState.restaurant_level == 1, "Cancel on the Upgrade Board keeps Level 1")
	game._offer_upgrade(board)
	game.confirm_dialog._confirm()
	await get_tree().process_frame
	await get_tree().process_frame
	_report(GameState.restaurant_level == 2, "Upgrade Board (chalkboard) + confirm -> Restaurant Level 2")
	for lv in range(2, 6):
		GameState.restaurant_level = lv
		await get_tree().process_frame
		await get_tree().process_frame
		var b: Station = null
		for c in game.restaurant.get_node("Stations/Decor").get_children():
			if c is Station and c.opens == "upgrades":
				b = c
		_report(b != null and game.nav.find_path(game.manager.global_position, Rect2(b.global_position - b.size / 2.0, b.size), 60.0).ok,
			"Restaurant Lv %d: the manager can walk to the Upgrade Board" % lv)
	# Level challenges 2-5, each finished by its Code Sets program.
	GameState.challenges_done = []
	Engine.time_scale = 8.0
	GameState.restaurant_level = 2
	await get_tree().process_frame
	await get_tree().process_frame
	game.place_order(null, "TOCILOG")
	jane.program_source = CodeSets.challenges_program(2)
	await jane.run_program()
	_report(GameState.challenges_left(2).is_empty(), "Level 2 challenges (take_order, if/else, switch+default) done: %s" % [GameState.challenges_done])
	GameState.restaurant_level = 3
	await get_tree().process_frame
	await get_tree().process_frame
	jane = game.get_node("Characters/Staff/Jane")
	for d in ["EGSILOG", "HAMBURGER", "TOCILOG"]:
		game.place_order(null, d)
		game.take_order_now(null)
		game.post_order(null, d)
	jane.program_source = CodeSets.challenges_program(3)
	await jane.run_program()
	_report(GameState.challenges_left(3).is_empty(), "Level 3 challenges (3 in a Run, for loop, waiter + cook) done: %s" % [GameState.challenges_left(3).map(func(g): return g.id)])
	GameState.restaurant_level = 4
	await get_tree().process_frame
	await get_tree().process_frame
	jane = game.get_node("Characters/Staff/Jane")
	game.place_order(null, "EGSILOG")
	game.place_order(null, "HAMBURGER")
	jane.program_source = CodeSets.challenges_program(4).replace("while (1)", "for (int r = 0; r < 2; r++)")
	await jane.run_program()
	_report(GameState.challenges_left(4).is_empty(), "Level 4 challenges (recipe array, 2 dishes, sizeof) done: %s" % [GameState.challenges_left(4).map(func(g): return g.id)])
	GameState.restaurant_level = 5
	await get_tree().process_frame
	await get_tree().process_frame
	jane = game.get_node("Characters/Staff/Jane")
	GameState.library_slots = GameState.new_library()
	GameState.library_slots[1].code = CodeSets.make_dish()
	game.place_order(null, "EGSILOG")
	jane.program_source = CodeSets.challenges_program(5).replace("while (1)", "for (int r = 0; r < 1; r++)")
	var exp_before := GameState.total_exp()
	await jane.run_program()
	_report(GameState.challenges_left(5).is_empty() and GameState.total_exp() > exp_before,
		"Level 5 challenges (function, return, Library) done, EXP +%d" % (GameState.total_exp() - exp_before))
	if not GameState.challenges_left(5).is_empty():
		print(jane.log_text)
	Engine.time_scale = 1.0
	GameState.library_slots = GameState.new_library()
	# Admin: Code Sets window opens, gives a program to staff and closes.
	game._open_code_sets()
	await get_tree().process_frame
	var csw = game.code_sets_window
	csw._select(0)
	csw._on_give()
	_report(csw.visible and csw.frame.size.x == 1920 and game._staff_list()[0].program_source == csw.current_code(),
		"Admin Code Sets window: %d sets, Give to staff works" % csw._sets.size())
	csw.close()
	# Save and load.
	GameState.game_name = "Test Kitchen"
	GameState.manager_name = "Chris"
	GameState.money = 777
	GameState.library_slots[2] = {"name": "Mine", "code": "void hi() { }", "enabled": false}
	var served_n := GameState.total_dishes_served()
	var saved := GameState.to_save()
	GameState.reset()
	GameState.from_save(saved)
	_report(GameState.game_name == "Test Kitchen" and GameState.manager_name == "Chris" and GameState.money == 777 and GameState.library_slots[2].name == "Mine" and GameState.library_slots[2].code == "void hi() { }" and not GameState.library_slots[2].enabled and GameState.total_dishes_served() == served_n,
		"Save/load keeps game name, manager name and coins")
	print("==== Smoke test: %s ====" % ("ALL PASSED" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(_failed)


## Cooks whatever the next customer ordered (Level 2 dishes).
func _order_program() -> String:
	return """void main() {
    int order = take_order();
    if (order == TOCILOG) {
        go_to(FRIDGE); pick_up(RICE); go_to(GRILL); cook(); go_to(ASSEMBLY); plate();
        go_to(FRIDGE); pick_up(EGG); go_to(GRILL); cook(); go_to(ASSEMBLY); plate();
        go_to(FRIDGE); pick_up(TOCINO); go_to(GRILL); cook(); go_to(ASSEMBLY); plate();
        assemble(TOCILOG);
        go_to(SERVING_COUNTER); serve();
    } else {
        printf("Got %s\\n", order);
    }
}"""


func _names() -> Array:
	return game._staff_list().map(func(s): return s.staff_name)


## Writes a straight-line C program that makes and serves one dish.
func _program_for(dish: String) -> String:
	var lines := ["void main() {"]
	var recipe: Dictionary = Kitchen.DISHES[dish].recipe
	for ing in recipe:
		for n in recipe[ing]:
			var store := "FRIDGE"
			for st in Kitchen.STORAGE:
				if ing in Kitchen.STORAGE[st] and game.get_station(st) != null:
					store = st
					break
			lines.append("    go_to(%s); pick_up(%s);" % [store, ing])
			if ing in Kitchen.NEEDS_COOKING:
				for st in Kitchen.COOKING:
					if ing in Kitchen.COOKING[st] and game.get_station(st) != null:
						lines.append("    go_to(%s); cook();" % st)
						break
			lines.append("    go_to(ASSEMBLY); plate();")
	lines.append("    assemble(%s);" % dish)
	lines.append("    go_to(SERVING_COUNTER); serve();")
	lines.append("}")
	return "\n".join(lines)


func _report(ok: bool, msg: String) -> void:
	if not ok:
		_failed += 1
	print("PASS  " if ok else "FAIL  ", msg)

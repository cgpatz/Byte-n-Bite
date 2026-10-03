extends Node
## Live gameplay state for the current run. Saved/loaded by SaveManager later.

signal money_changed(amount: int)
signal restaurant_level_changed(level: int)
signal seating_changed
## Player (manager) EXP/level changed.
signal player_exp_changed(level: int, exp_now: int, needed: int)
## Reached a new player level. rewards = text lines ("+100 coins", "Carla joins your staff").
signal player_leveled_up(level: int, rewards: Array)
## Staff members joined or left (new restaurant/player level). joined = names.
signal staff_roster_changed(joined: Array)
## A dish was served (stats changed).
signal stats_changed
## The Café was unlocked or a Café recipe was bought (Restaurant Level 5).
signal cafe_changed(step: int)
## A staff member was upgraded (new level, specialization or "").
signal staff_upgraded(staff_name: String, level: int, spec: String)

const MAX_RESTAURANT_LEVEL := 5
const MAX_STAFF := 6
const START_MONEY := 100
## Number of Library slots (separate sets of saved code).
const LIBRARY_SLOTS := 6

## Starter code for the Library (the player's shared functions).
const DEFAULT_LIBRARY := """// My Library: functions written here can be called
// from EVERY staff member's program.
// Example: call fetch_and_cook(EGG); in any program.

void fetch_and_cook(int item) {
    go_to(FRIDGE);
    pick_up(item);
    go_to(GRILL);
    cook();
    go_to(ASSEMBLY);
    plate();
}
"""
const Progression := preload("res://data/progression/progression.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const Market := preload("res://systems/market/market_rules.gd")
## Grand Restaurant table slots inside the Café room (used once the Café opens).
const CAFE_TABLE_SLOTS := 4

const LEVELS: Array[RestaurantLevelData] = [
	preload("res://data/levels/level_1.tres"),
	preload("res://data/levels/level_2.tres"),
	preload("res://data/levels/level_3.tres"),
	preload("res://data/levels/level_4.tres"),
	preload("res://data/levels/level_5.tres"),
]

## Name of this game/save (shown on the Load Game screen) and the manager's name.
var game_name := ""
var manager_name := "Manager"

## Stats: dishes served per dish name ({"EGSILOG": 3}) and coins earned from sales.
var dishes_served := {}
var coins_from_sales := 0
## Customers who left because their food took too long.
var customers_lost := 0
## Today's Special: until take_order() unlocks (Restaurant Level 2), every
## customer orders this one dish, so beginners know what to cook.
var todays_special := "EGSILOG"
signal special_changed(dish: String)
const SPECIAL_UNTIL_LEVEL := 2
## Restaurant levels whose C lesson the player has seen.
var tutorials_seen: Array = []
## Level challenges finished, e.g. ["1:count", "1:receipt"] (systems/challenges/level_challenges.gd).
var challenges_done: Array = []
signal challenge_completed(level: int, id: String)
## Level goals (sell N dishes, earn a profit): sales made at each level and the
## goals reached, e.g. {"1": {"dishes": {"EGSILOG": 4}, "profit": 120}} and ["1:profit"].
var level_sales := {}
var goals_reached: Array = []
signal goal_reached(level: int, id: String)
const LevelGoals := preload("res://systems/goals/level_goals.gd")
const LevelChallenges := preload("res://systems/challenges/level_challenges.gd")
## Library: the player's own C functions, usable in every staff member's program.
var library_slots: Array = new_library()
## Each staff member's C program, by name (so programs survive saving).
var staff_programs := {}
## Ingredients in the kitchen ({"RICE": 10}). pick_up() uses one; Market
## orders arrive as crates in the delivery area and are added when claimed.
var inventory := Market.START_INVENTORY.duplicate()
## What the Market has for sale right now (random, renewed every few minutes).
var market_stock := {}
var market_restock_left := 0.0
## Market orders on their way: [{"cart": {"RICE": 10}, "left": secs, "total": secs, "waiting": bool}]
var deliveries: Array = []
## Crates waiting in the delivery area: [{"ing": "RICE", "n": 10}]
var crates: Array = []
## Tests / Admin: ingredients never run out (not saved).
var unlimited_ingredients := false
signal inventory_changed
signal market_changed
signal deliveries_changed
## A delivery reached the delivery area (its crates are now in `crates`).
signal delivery_arrived(cart: Dictionary)

## Staff levels and Lv 10 specializations by name ({"Jane": 3}, {"Jane": "Chef"}).
var staff_levels := {}
var staff_specs := {}
## Café progress: 0 = locked, 1 = open (Macchiato), up to 10 = full Café menu.
var cafe_step := 0

var money := START_MONEY:
	set(value):
		money = value
		money_changed.emit(money)

var restaurant_level := 1:
	set(value):
		restaurant_level = clampi(value, 1, MAX_RESTAURANT_LEVEL)
		restaurant_level_changed.emit(restaurant_level)
		_check_roster()

## Player (manager) level 1–10 and EXP toward the next level.
var player_level := 1
var player_exp := 0
## Names of staff currently on the team (see Progression.STAFF).
var _roster_names: Array = ["Jane"]

## True during an Admin Run (editor-only test game with the admin panel).
var admin_mode := false

## Chairs at each bought table, in table-slot order. Size = tables owned.
## Seating starts at 1 table with 1 chair, and resets to that on every restaurant upgrade.
const START_SEATING: Array[int] = [1]
var table_chairs: Array[int] = START_SEATING.duplicate()


func _ready() -> void:
	if market_stock.is_empty():
		market_stock = Market.roll_stock()
		market_restock_left = Market.RESTOCK_SECONDS


func reset() -> void:
	game_name = ""
	manager_name = "Manager"
	dishes_served = {}
	coins_from_sales = 0
	customers_lost = 0
	tutorials_seen = []
	challenges_done = []
	level_sales = {}
	goals_reached = []
	todays_special = "EGSILOG"
	library_slots = new_library()
	staff_programs = {}
	staff_levels = {}
	staff_specs = {}
	inventory = Market.START_INVENTORY.duplicate()
	market_stock = Market.roll_stock()
	market_restock_left = Market.RESTOCK_SECONDS
	deliveries = []
	crates = []
	cafe_step = 0
	table_chairs = START_SEATING.duplicate()
	money = START_MONEY
	player_level = 1
	player_exp = 0
	restaurant_level = 1
	seating_changed.emit()
	cafe_changed.emit(cafe_step)
	player_exp_changed.emit(player_level, player_exp, exp_needed())


# --- Saving (local save slots, SaveManager) ----------------------------------

## Gameplay state written to the save file.
func to_save() -> Dictionary:
	return {
		"game_name": game_name, "manager_name": manager_name,
		"money": money, "restaurant_level": restaurant_level,
		"player_level": player_level, "player_exp": player_exp,
		"table_chairs": table_chairs,
		"dishes_served": dishes_served, "coins_from_sales": coins_from_sales,
		"library_slots": library_slots, "staff_programs": staff_programs,
		"staff_levels": staff_levels, "staff_specs": staff_specs,
		"inventory": inventory, "market_stock": market_stock, "market_restock_left": market_restock_left,
		"deliveries": deliveries, "crates": crates,
		"cafe_step": cafe_step, "customers_lost": customers_lost,
		"tutorials_seen": tutorials_seen, "challenges_done": challenges_done, "level_sales": level_sales, "goals_reached": goals_reached, "todays_special": todays_special,
	}


## Short summary for the Load Game screen.
func save_meta() -> Dictionary:
	return {
		"game_name": game_name, "manager_name": manager_name,
		"restaurant_level": restaurant_level, "player_level": player_level,
		"money": money, "staff": staff_roster().size(),
	}


func from_save(d: Dictionary) -> void:
	reset()
	game_name = str(d.get("game_name", ""))
	manager_name = str(d.get("manager_name", "Manager"))
	var chairs: Array[int] = []
	for c in d.get("table_chairs", START_SEATING):
		chairs.append(int(c))
	table_chairs = chairs if not chairs.is_empty() else START_SEATING.duplicate()
	money = int(d.get("money", START_MONEY))
	player_level = clampi(int(d.get("player_level", 1)), 1, Progression.MAX_PLAYER_LEVEL)
	player_exp = int(d.get("player_exp", 0))
	dishes_served = {}
	var served: Dictionary = d.get("dishes_served", {})
	for k in served:
		dishes_served[str(k)] = int(served[k])
	coins_from_sales = int(d.get("coins_from_sales", 0))
	customers_lost = int(d.get("customers_lost", 0))
	todays_special = str(d.get("todays_special", "EGSILOG"))
	if not Kitchen.DISHES.has(todays_special):
		todays_special = "EGSILOG"
	challenges_done = []
	for g in d.get("challenges_done", d.get("goals_done", [])):  # older saves: goals_done
		challenges_done.append(str(g))
	level_sales = d.get("level_sales", {})
	goals_reached = []
	for g in d.get("goals_reached", []):
		goals_reached.append(str(g))
	tutorials_seen = []
	for t in d.get("tutorials_seen", []):
		tutorials_seen.append(int(t))
	library_slots = new_library()
	if d.has("library_slots"):
		var saved: Array = d.library_slots
		for i in mini(saved.size(), LIBRARY_SLOTS):
			var s: Dictionary = saved[i]
			library_slots[i] = {"name": str(s.get("name", "Slot %d" % (i + 1))),
				"code": str(s.get("code", "")), "enabled": bool(s.get("enabled", true))}
	elif d.has("library_code"):  # older saves had a single Library
		library_slots[0].code = str(d.library_code)
	staff_programs = {}
	var progs: Dictionary = d.get("staff_programs", {})
	for k in progs:
		staff_programs[str(k)] = str(progs[k])
	var lvls: Dictionary = d.get("staff_levels", {})
	for k in lvls:
		staff_levels[str(k)] = clampi(int(lvls[k]), 1, Progression.MAX_STAFF_LEVEL)
	var specs: Dictionary = d.get("staff_specs", {})
	for k in specs:
		if str(specs[k]) in Progression.STAFF_SPECIALIZATIONS:
			staff_specs[str(k)] = str(specs[k])
	cafe_step = clampi(int(d.get("cafe_step", 0)), 0, Kitchen.CAFE_STEPS)
	_load_market(d)
	restaurant_level = int(d.get("restaurant_level", 1))
	seating_changed.emit()
	cafe_changed.emit(cafe_step)
	player_exp_changed.emit(player_level, player_exp, exp_needed())


## Saves to the current slot (does nothing in Admin Runs or without a slot).
func save_now() -> bool:
	if admin_mode or SaveManager.current_slot < 0:
		return false
	return SaveManager.save_game(SaveManager.current_slot, to_save(), save_meta())


## A fresh Library: slot 1 has the example, the others are empty.
static func new_library() -> Array:
	var slots: Array = []
	for i in LIBRARY_SLOTS:
		slots.append({"name": "Slot %d" % (i + 1), "code": "", "enabled": true})
	slots[0].name = "Basics"
	slots[0].code = DEFAULT_LIBRARY
	return slots


# --- Stats -------------------------------------------------------------------------

func record_sale(dish: String, price: int) -> void:
	dishes_served[dish] = int(dishes_served.get(dish, 0)) + 1
	coins_from_sales += price
	_count_level_sale(dish, price)
	stats_changed.emit()


func total_dishes_served() -> int:
	var n := 0
	for k in dishes_served:
		n += int(dishes_served[k])
	return n


# --- Player level & EXP -----------------------------------------------------------

func exp_needed() -> int:
	return Progression.exp_to_next(player_level)


## Adds EXP (from a sale or a quest) and handles level-ups and their rewards.
func add_exp(amount: int, _source := "") -> void:
	if amount <= 0 or player_level >= Progression.MAX_PLAYER_LEVEL:
		return
	player_exp += amount
	while player_level < Progression.MAX_PLAYER_LEVEL and player_exp >= exp_needed():
		player_exp -= exp_needed()
		player_level += 1
		money += Progression.LEVEL_COINS.get(player_level, 0)
		player_leveled_up.emit(player_level, Progression.reward_lines(player_level))
	if player_level >= Progression.MAX_PLAYER_LEVEL:
		player_exp = 0
	player_exp_changed.emit(player_level, player_exp, exp_needed())
	_check_roster()


## EXP for serving a dish worth `price` coins.
func add_sale_exp(price: int) -> int:
	var amount := Progression.sale_exp(price)
	add_exp(amount, "sale")
	return amount


## EXP for finishing a quest ("easy" | "normal" | "hard").
func add_quest_exp(difficulty := "normal") -> int:
	var amount: int = Progression.QUEST_EXP.get(difficulty, 80)
	add_exp(amount, "quest")
	return amount


## Admin/testing: jump straight to a player level (no coin rewards).
func set_player_level(level: int) -> void:
	player_level = clampi(level, 1, Progression.MAX_PLAYER_LEVEL)
	player_exp = 0
	player_exp_changed.emit(player_level, player_exp, exp_needed())
	_check_roster()


# --- Staff roster -----------------------------------------------------------------

## Staff entries on the team now: [{"name", "color", ...}], Jane first.
func staff_roster() -> Array:
	return Progression.staff_for(restaurant_level, player_level)


func staff_level(staff_name: String) -> int:
	return int(staff_levels.get(staff_name, 1))


func staff_spec(staff_name: String) -> String:
	return str(staff_specs.get(staff_name, ""))


## Coins for this staff member's next level (0 = max level).
func staff_upgrade_cost(staff_name: String) -> int:
	return Progression.staff_upgrade_cost(staff_level(staff_name))


func can_upgrade_staff(staff_name: String) -> bool:
	var cost := staff_upgrade_cost(staff_name)
	return cost > 0 and money >= cost


## Pays and levels up a staff member. Reaching Lv 10 needs a role
## (Chef / Barista / Cashier / Waiter).
func upgrade_staff(staff_name: String, spec := "") -> bool:
	if not can_upgrade_staff(staff_name):
		return false
	var next := staff_level(staff_name) + 1
	if next >= Progression.MAX_STAFF_LEVEL and not spec in Progression.STAFF_SPECIALIZATIONS:
		return false
	money -= staff_upgrade_cost(staff_name)
	staff_levels[staff_name] = next
	if next >= Progression.MAX_STAFF_LEVEL:
		staff_specs[staff_name] = spec
	staff_upgraded.emit(staff_name, next, staff_spec(staff_name))
	save_now()
	return true


# --- Inventory and the Market ------------------------------------------------------

func _load_market(d: Dictionary) -> void:
	inventory = {}
	if d.has("inventory"):
		var inv: Dictionary = d.inventory
		for k in inv:
			inventory[str(k)] = maxi(0, int(inv[k]))
	else:
		# Saves from before the Market: start with 15 of every unlocked ingredient.
		for ing in Kitchen.INGREDIENTS:
			if Kitchen.available(ing, int(d.get("restaurant_level", 1)), cafe_step) == "":
				inventory[ing] = 15
	if d.has("market_stock"):
		market_stock = {}
		var ms: Dictionary = d.market_stock
		for k in ms:
			market_stock[str(k)] = maxi(0, int(ms[k]))
	market_restock_left = float(d.get("market_restock_left", Market.RESTOCK_SECONDS))
	deliveries = []
	for dv in d.get("deliveries", []):
		var cart := {}
		for k in dv.get("cart", {}):
			cart[str(k)] = int(dv.cart[k])
		deliveries.append({"cart": cart, "left": float(dv.get("left", 0)), "total": float(dv.get("total", 1)), "waiting": false})
	crates = []
	for c in d.get("crates", []):
		crates.append({"ing": str(c.get("ing", "RICE")), "n": int(c.get("n", 1))})


## How many of an ingredient the kitchen has (stock()).
func stock_of(ing: String) -> int:
	if unlimited_ingredients:
		return 99
	return int(inventory.get(ing, 0))


## Uses one ingredient (pick_up()). False when there is none left.
func take_ingredient(ing: String) -> bool:
	if unlimited_ingredients:
		return true
	if stock_of(ing) <= 0:
		return false
	inventory[ing] = stock_of(ing) - 1
	inventory_changed.emit()
	return true


func add_ingredient(ing: String, n: int) -> void:
	inventory[ing] = int(inventory.get(ing, 0)) + n
	inventory_changed.emit()


## Crates the delivery area holds at this restaurant level.
func crate_capacity() -> int:
	return Market.crate_capacity(restaurant_level)


## Crates already on their way.
func crates_on_the_way() -> int:
	var n := 0
	for dv in deliveries:
		n += Market.crates_for(dv.cart)
	return n


## Why this cart can't be bought, or "" if it can.
func market_order_problem(cart: Dictionary, express := false) -> String:
	if Market.items_in(cart) <= 0:
		return "Pick something to buy first."
	for ing in cart:
		var why := Kitchen.available(ing, restaurant_level, cafe_step)
		if why != "":
			return why
		if int(cart[ing]) > int(market_stock.get(ing, 0)):
			return "The Market only has %d %s right now." % [int(market_stock.get(ing, 0)), ing.capitalize()]
	var crates_n := Market.crates_for(cart)
	if crates_n > crate_capacity():
		return "That's %d crates, but the delivery area holds %d. Buy less or upgrade the restaurant." % [crates_n, crate_capacity()]
	var cost := Market.cost_of(cart) + (Market.EXPRESS_COST if express else 0)
	if money < cost:
		return "Not enough coins: %d needed." % cost
	return ""


## Pays for a Market order and sends it on its way. Returns "" or the problem.
func buy_from_market(cart: Dictionary, express := false) -> String:
	var clean := {}
	for ing in cart:
		if int(cart[ing]) > 0:
			clean[ing] = int(cart[ing])
	var why := market_order_problem(clean, express)
	if why != "":
		return why
	money -= Market.cost_of(clean) + (Market.EXPRESS_COST if express else 0)
	for ing in clean:
		market_stock[ing] = int(market_stock[ing]) - int(clean[ing])
	var t := Market.delivery_seconds(Market.items_in(clean), express)
	deliveries.append({"cart": clean, "left": t, "total": t, "waiting": false})
	market_changed.emit()
	deliveries_changed.emit()
	return ""


## Runs the Market clock: restocks, delivery timers, arrivals. Called by Game.
func tick_market(delta: float) -> void:
	market_restock_left -= delta
	if market_restock_left <= 0.0:
		market_stock = Market.roll_stock()
		market_restock_left = Market.RESTOCK_SECONDS
		market_changed.emit()
	var arrived: Array = []
	for dv in deliveries:
		dv.left = maxf(0.0, dv.left - delta)
		if dv.left <= 0.0:
			var need := Market.crates_for(dv.cart)
			if crates.size() + need <= crate_capacity():
				arrived.append(dv)
			elif not dv.waiting:
				dv.waiting = true
				deliveries_changed.emit()
	for dv in arrived:
		deliveries.erase(dv)
		crates.append_array(Market.split_crates(dv.cart))
		delivery_arrived.emit(dv.cart)
	if not arrived.is_empty():
		deliveries_changed.emit()


## The manager claims a crate: its ingredients go into the kitchen.
func claim_crate(i: int) -> Dictionary:
	if i < 0 or i >= crates.size():
		return {}
	var c: Dictionary = crates[i]
	crates.remove_at(i)
	add_ingredient(c.ing, int(c.n))
	deliveries_changed.emit()
	return c


## Customer patience drain multiplier: slower while a Lv 10 Waiter is on staff.
func customer_patience_mult() -> float:
	for st in staff_roster():
		if staff_spec(st.name) == "Waiter":
			return Progression.WAITER_PATIENCE_MULT
	return 1.0


func _check_roster() -> void:
	var names: Array = staff_roster().map(func(s): return s.name)
	if names == _roster_names:
		return
	var joined: Array = names.filter(func(n): return not n in _roster_names)
	_roster_names = names
	staff_roster_changed.emit(joined)


func level_data(level := restaurant_level) -> RestaurantLevelData:
	return LEVELS[clampi(level, 1, MAX_RESTAURANT_LEVEL) - 1]


# --- Restaurant upgrade --------------------------------------------------------

func can_upgrade_restaurant() -> bool:
	return restaurant_level < MAX_RESTAURANT_LEVEL and money >= level_data().upgrade_cost \
		and challenges_left().is_empty() and goals_left().is_empty()


# --- Level goals (sell N dishes, earn a profit) ----------------------------------

func sales_at(level := restaurant_level) -> Dictionary:
	return level_sales.get(str(level), {"dishes": {}, "profit": 0})


func goal_progress(goal: Dictionary, level := restaurant_level) -> int:
	return mini(LevelGoals.progress(goal, sales_at(level)), int(goal.n))


func goal_reached_at(level: int, id: String) -> bool:
	return ("%d:%s" % [level, id]) in goals_reached


## This level's goals not reached yet (the upgrade waits for them).
func goals_left(level := restaurant_level) -> Array:
	var out: Array = []
	for g in LevelGoals.for_level(level):
		if not goal_reached_at(level, g.id):
			out.append(g)
	return out


## Counts a sale toward this level's goals and pays any goal just reached.
func _count_level_sale(dish: String, price: int) -> void:
	var key := str(restaurant_level)
	var s: Dictionary = level_sales.get(key, {"dishes": {}, "profit": 0})
	s.dishes[dish] = int(s.dishes.get(dish, 0)) + 1
	s.profit = int(s.profit) + price
	level_sales[key] = s
	for g in LevelGoals.for_level(restaurant_level):
		if not goal_reached_at(restaurant_level, g.id) and LevelGoals.progress(g, s) >= int(g.n):
			goals_reached.append("%d:%s" % [restaurant_level, g.id])
			money += int(g.coins)
			add_exp(int(g.exp), "goal")
			goal_reached.emit(restaurant_level, g.id)


## This level's challenges not finished yet (the upgrade waits for them).
func challenges_left(level := restaurant_level) -> Array:
	var out: Array = []
	for g in LevelChallenges.for_level(level):
		if not ("%d:%s" % [level, g.id]) in challenges_done:
			out.append(g)
	return out


func challenge_done(level: int, id: String) -> bool:
	return ("%d:%s" % [level, id]) in challenges_done


## Marks a challenge finished and pays its reward. False if it was already done.
func complete_challenge(level: int, id: String) -> bool:
	var key := "%d:%s" % [level, id]
	if key in challenges_done:
		return false
	var g: Dictionary = LevelChallenges.find(level, id)
	if g.is_empty():
		return false
	challenges_done.append(key)
	money += int(g.coins)
	add_exp(int(g.exp), "challenge")
	challenge_completed.emit(level, id)
	return true


func upgrade_restaurant() -> bool:
	if not can_upgrade_restaurant():
		return false
	money -= level_data().upgrade_cost
	# New, bigger restaurant: seating starts over at 1 table / 1 chair.
	table_chairs = START_SEATING.duplicate()
	# The new level's goals start from zero: profit and dish counts reset.
	level_sales[str(restaurant_level + 1)] = {"dishes": {}, "profit": 0}
	restaurant_level += 1
	seating_changed.emit()
	return true


# --- Seating -------------------------------------------------------------------

func tables_owned() -> int:
	return table_chairs.size()


func total_seats() -> int:
	var n := 0
	for c in table_chairs:
		n += c
	return n


func next_table_cost() -> int:
	return level_data().table_base_cost * tables_owned()


## Tables allowed now (the Grand Restaurant's Café tables wait for the Café).
func table_limit() -> int:
	var cap: int = level_data().table_cap
	if restaurant_level >= MAX_RESTAURANT_LEVEL and cafe_step < 1:
		cap -= CAFE_TABLE_SLOTS
	return cap


func can_buy_table() -> bool:
	return tables_owned() < table_limit() and money >= next_table_cost()


func buy_table() -> bool:
	if not can_buy_table():
		return false
	money -= next_table_cost()
	table_chairs.append(1)  # each new table comes with 1 chair
	seating_changed.emit()
	return true


## Most chairs each table slot can hold (family tables: 6). Set by the game
## when a restaurant loads; empty = use the level's max_chairs_per_table.
var slot_chair_caps: Array[int] = []


func chair_cap(table_index: int) -> int:
	if table_index < slot_chair_caps.size():
		return slot_chair_caps[table_index]
	return level_data().max_chairs_per_table


## Index of the first table that can take another chair, or -1.
func _table_with_room() -> int:
	for i in table_chairs.size():
		if table_chairs[i] < chair_cap(i):
			return i
	return -1


func can_buy_chair() -> bool:
	return _table_with_room() != -1 and money >= level_data().chair_cost


## Chairs for one particular table (the one the manager walked up to).
func can_buy_chair_at(i: int) -> bool:
	return i >= 0 and i < table_chairs.size() and table_chairs[i] < chair_cap(i) \
		and money >= level_data().chair_cost


func buy_chair_at(i: int) -> bool:
	if not can_buy_chair_at(i):
		return false
	money -= level_data().chair_cost
	table_chairs[i] += 1
	seating_changed.emit()
	return true


func buy_chair() -> bool:
	if not can_buy_chair():
		return false
	money -= level_data().chair_cost
	table_chairs[_table_with_room()] += 1
	seating_changed.emit()
	return true


# --- Café (Restaurant Level 5) -------------------------------------------------

## Dishes on the menu right now (restaurant + bought Café recipes).
func current_menu() -> Array:
	return Kitchen.menu(restaurant_level, cafe_step)


## Price of the next Café purchase (opening it, then each recipe), 0 when done.
func next_cafe_cost() -> int:
	if cafe_step >= Kitchen.CAFE_STEPS:
		return 0
	if cafe_step == 0:
		return Kitchen.CAFE_UNLOCK_COST
	return Kitchen.CAFE_STEP_COST[cafe_step + 1]


func can_buy_cafe_step() -> bool:
	return restaurant_level >= MAX_RESTAURANT_LEVEL and cafe_step < Kitchen.CAFE_STEPS \
		and money >= next_cafe_cost()


## Opens the Café, or adds the next recipe(s) to its menu.
func buy_cafe_step() -> bool:
	if not can_buy_cafe_step():
		return false
	money -= next_cafe_cost()
	cafe_step += 1
	cafe_changed.emit(cafe_step)
	stats_changed.emit()
	return true


## Total EXP earned (all levels so far) and the total needed to reach max level.
func total_exp() -> int:
	var n := player_exp
	for i in player_level - 1:
		n += Progression.EXP_TO_NEXT[i]
	return n


func total_exp_to_max() -> int:
	var n := 0
	for e in Progression.EXP_TO_NEXT:
		n += e
	return n


# --- Today's Special (Restaurant Level 1) -----------------------------------------

## True while customers only order Today's Special.
func special_active() -> bool:
	return restaurant_level < SPECIAL_UNTIL_LEVEL


## Picks the next dish on the menu as Today's Special (cycles).
func next_special() -> void:
	var menu: Array = Kitchen.menu(restaurant_level, 0)
	if menu.is_empty():
		return
	var i := menu.find(todays_special)
	todays_special = menu[(i + 1) % menu.size()]
	special_changed.emit(todays_special)

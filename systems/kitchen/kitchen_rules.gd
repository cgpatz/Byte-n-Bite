extends RefCounted
## Byte n' Bite kitchen rules: the names C programs can use (stations,
## ingredients, dishes), where ingredients are stored, what each station cooks,
## the Version 1 menu (13 dishes, 12 ingredients) and when each unlocks.
## Pure data + lookups; no nodes. Use via preload("res://systems/kitchen/kitchen_rules.gd").
## Source: "Byte n' Bite Menu Design: Dishes, Ingredients, and Unlock Levels" (Sep 2026).

const NOTHING := 0

## Station names usable in code, e.g. go_to(GRILL). Numbered 1, 2, 3...
## The names must match station_id in the level scenes.
const STATIONS := [
	"FRIDGE", "PANTRY", "FREEZER", "GRILL", "FRYER", "STOVE", "OVEN", "RICE_COOKER",
	"PREP_BOARD", "ASSEMBLY", "SERVING_COUNTER", "SINK", "TRASH", "RECEIVING", "BACK_DOOR",
	"COFFEE_MACHINE", "BLENDER", "DRINKS_DISPENSER", "PASTRY_CASE", "SPICE_RACK", "DISH_RACK",
]

## Ingredients (numbered from 101) and the restaurant level that unlocks them.
const INGREDIENTS := {
	"RICE": 1, "EGG": 1, "HOTDOG": 1,
	"TOCINO": 2, "BREAD": 2, "CHEESE": 2,
	"BUN": 3, "PATTY": 3, "LETTUCE": 3, "TOMATO": 3, "CHICKEN": 3,
	"NOODLES": 4,
	# Café (Restaurant Level 5, after the Café is bought)
	"COFFEE": 5, "MILK": 5, "CONDENSED_MILK": 5, "MATCHA": 5, "CHOCOLATE": 5,
	"ICE": 5, "WATER": 5, "DOUGH": 5, "BUTTER": 5, "SUGAR": 5,
}
## Café ingredients: only available once the Café is unlocked.
const CAFE_INGREDIENTS := ["COFFEE", "MILK", "CONDENSED_MILK", "MATCHA", "CHOCOLATE", "ICE", "WATER", "DOUGH", "BUTTER", "SUGAR"]
## Ingredients that must be cooked before plating.
const NEEDS_COOKING := ["RICE", "EGG", "HOTDOG", "TOCINO", "BREAD", "PATTY", "CHICKEN", "NOODLES",
	"COFFEE", "MATCHA", "CHOCOLATE", "DOUGH"]

## The menu (numbered from 201). recipe = {ingredient: how many}.
## price = coins per sale; the menu is cumulative (earlier dishes stay).
const DISHES := {
	# Level 1 — syntax, variables, arithmetic
	"EGGSILOG": {"title": "Eggsilog", "level": 1, "price": 30, "recipe": {"RICE": 1, "EGG": 1}},
	"HOTSILOG": {"title": "Hotsilog", "level": 1, "price": 40, "recipe": {"RICE": 1, "EGG": 1, "HOTDOG": 1}},
	# Level 2 — if / else, switch
	"TOCILOG": {"title": "Tocilog", "level": 2, "price": 45, "recipe": {"RICE": 1, "EGG": 1, "TOCINO": 1}},
	"GRILLED_CHEESE": {"title": "Grilled Cheese Sandwich", "level": 2, "price": 35, "recipe": {"BREAD": 1, "CHEESE": 1}},
	# Level 3 — loops
	"HAMBURGER": {"title": "Hamburger", "level": 3, "price": 55, "recipe": {"BUN": 1, "PATTY": 1, "LETTUCE": 1, "TOMATO": 1}},
	"FRIED_CHICKEN_MEAL": {"title": "Fried Chicken Meal", "level": 3, "price": 60, "recipe": {"RICE": 1, "CHICKEN": 1}},
	"GARDEN_SALAD": {"title": "Garden Salad", "level": 3, "price": 40, "recipe": {"LETTUCE": 1, "TOMATO": 1, "CHEESE": 1}},
	# Level 4 — arrays
	"CHEESEBURGER": {"title": "Cheeseburger", "level": 4, "price": 65, "recipe": {"BUN": 1, "PATTY": 1, "CHEESE": 1, "LETTUCE": 1, "TOMATO": 1}},
	"PANCIT_CANTON": {"title": "Pancit Canton", "level": 4, "price": 60, "recipe": {"NOODLES": 1, "CHICKEN": 1, "EGG": 1}},
	"CHICKEN_SANDWICH": {"title": "Chicken Sandwich", "level": 4, "price": 65, "recipe": {"BUN": 1, "CHICKEN": 1, "LETTUCE": 1, "CHEESE": 1}},
	# Level 5 — functions, everything combined
	"DOUBLE_CHEESEBURGER": {"title": "Double Cheeseburger", "level": 5, "price": 90, "recipe": {"BUN": 1, "PATTY": 2, "CHEESE": 2, "LETTUCE": 1, "TOMATO": 1}},
	"SILOG_PLATTER": {"title": "Silog Platter", "level": 5, "price": 85, "recipe": {"RICE": 1, "EGG": 2, "HOTDOG": 1, "TOCINO": 1}},
	"SIGNATURE_BOWL": {"title": "Byte n' Bite Signature Bowl", "level": 5, "price": 100, "recipe": {"RICE": 1, "CHICKEN": 1, "EGG": 1, "LETTUCE": 1, "TOMATO": 1}},
	# Café menu (Restaurant Level 5). "cafe" = the purchase step that adds it
	# (1 = comes with the Café). "kind" = drink or pastry.
	"MACCHIATO": {"title": "Macchiato", "level": 5, "cafe": 1, "kind": "drink", "price": 75, "recipe": {"COFFEE": 1, "MILK": 1}},
	"SPANISH_LATTE": {"title": "Spanish Latte", "level": 5, "cafe": 2, "kind": "drink", "price": 95, "recipe": {"COFFEE": 1, "MILK": 1, "CONDENSED_MILK": 1}},
	"PLAIN_CROISSANT": {"title": "Plain Croissant", "level": 5, "cafe": 2, "kind": "pastry", "price": 50, "recipe": {"DOUGH": 1, "BUTTER": 1}},
	"MATCHA_LATTE": {"title": "Matcha Latte", "level": 5, "cafe": 3, "kind": "drink", "price": 100, "recipe": {"MATCHA": 1, "MILK": 1}},
	"ESPRESSO": {"title": "Espresso", "level": 5, "cafe": 4, "kind": "drink", "price": 60, "recipe": {"COFFEE": 1}},
	"ENSAIMADA": {"title": "Ensaimada", "level": 5, "cafe": 4, "kind": "pastry", "price": 65, "recipe": {"DOUGH": 1, "BUTTER": 1, "SUGAR": 1, "CHEESE": 1}},
	"MOCHA": {"title": "Mocha", "level": 5, "cafe": 5, "kind": "drink", "price": 105, "recipe": {"COFFEE": 1, "CHOCOLATE": 1, "MILK": 1}},
	"HOT_CHOCOLATE": {"title": "Hot Chocolate", "level": 5, "cafe": 6, "kind": "drink", "price": 80, "recipe": {"CHOCOLATE": 1, "MILK": 1}},
	"CHEESE_ROLL": {"title": "Cheese Roll", "level": 5, "cafe": 6, "kind": "pastry", "price": 55, "recipe": {"DOUGH": 1, "CHEESE": 1, "SUGAR": 1}},
	"COLD_CHOCOLATE": {"title": "Cold Chocolate", "level": 5, "cafe": 7, "kind": "drink", "price": 90, "recipe": {"CHOCOLATE": 1, "MILK": 1, "ICE": 1}},
	"AMERICANO": {"title": "Americano", "level": 5, "cafe": 8, "kind": "drink", "price": 70, "recipe": {"COFFEE": 1, "WATER": 1}},
	"CHOCO_MOIST": {"title": "Choco Moist Cake", "level": 5, "cafe": 8, "kind": "pastry", "price": 75, "recipe": {"DOUGH": 1, "CHOCOLATE": 1, "SUGAR": 1}},
	"CAPPUCCINO": {"title": "Cappuccino", "level": 5, "cafe": 9, "kind": "drink", "price": 90, "recipe": {"COFFEE": 1, "MILK": 2}},
	"AMERICANO_DOUBLE_SHOT": {"title": "Americano (Double Shot)", "level": 5, "cafe": 10, "kind": "drink", "price": 85, "recipe": {"COFFEE": 2, "WATER": 1}},
	"BRAZO_DE_MERCEDES": {"title": "Brazo de Mercedes", "level": 5, "cafe": 10, "kind": "pastry", "price": 95, "recipe": {"EGG": 2, "SUGAR": 1, "CONDENSED_MILK": 1}},
}

## Café: price to open it (comes with step 1) and the price of each next step.
const CAFE_UNLOCK_COST := 2500
const CAFE_STEP_COST := {2: 400, 3: 500, 4: 600, 5: 700, 6: 800, 7: 900, 8: 1000, 9: 1200, 10: 1500}
const CAFE_STEPS := 10

const ITEM_BASE := 101
const DISH_BASE := 201

## Where pick_up(ITEM) works. The FRIDGE holds everything (L1–L4 have no pantry);
## the Grand Restaurant's PANTRY and FREEZER hold their usual goods too.
const STORAGE := {
	"FRIDGE": ["RICE", "EGG", "HOTDOG", "TOCINO", "BREAD", "CHEESE", "BUN", "PATTY", "LETTUCE", "TOMATO", "CHICKEN", "NOODLES",
		"COFFEE", "MILK", "CONDENSED_MILK", "MATCHA", "CHOCOLATE", "DOUGH", "BUTTER", "SUGAR"],
	"PANTRY": ["RICE", "BREAD", "BUN", "NOODLES", "COFFEE", "MATCHA", "CHOCOLATE", "SUGAR"],
	"FREEZER": ["HOTDOG", "TOCINO", "PATTY", "CHICKEN", "ICE", "DOUGH"],
	"DRINKS_DISPENSER": ["WATER", "ICE", "MILK"],
	"PASTRY_CASE": ["DOUGH", "BUTTER", "SUGAR"],
	"SINK": ["WATER"],
}
## cook(): which station cooks which ingredient.
const COOKING := {
	"GRILL": ["RICE", "EGG", "HOTDOG", "TOCINO", "BREAD", "PATTY"],
	"FRYER": ["CHICKEN"],
	"STOVE": ["NOODLES", "EGG", "CHOCOLATE"],
	"RICE_COOKER": ["RICE"],
	"COFFEE_MACHINE": ["COFFEE", "MATCHA"],
	"OVEN": ["DOUGH"],
}
## Seconds each cook() takes, per station.
const COOK_TIME := {"GRILL": 2.0, "FRYER": 2.5, "STOVE": 2.5, "RICE_COOKER": 2.5, "COFFEE_MACHINE": 2.0, "OVEN": 3.0}
## What cook() is called at each station, for messages and the Recipe Book.
const COOK_VERB := {"COFFEE_MACHINE": "brew", "OVEN": "bake", "STOVE": "cook", "GRILL": "cook", "FRYER": "fry", "RICE_COOKER": "cook"}


## Every name a C program can use -> its number.
static func constants() -> Dictionary:
	var out := {"NOTHING": NOTHING}
	for i in STATIONS.size():
		out[STATIONS[i]] = i + 1
	var ings := INGREDIENTS.keys()
	for i in ings.size():
		out[ings[i]] = ITEM_BASE + i
	var dishes := DISHES.keys()
	for i in dishes.size():
		out[dishes[i]] = DISH_BASE + i
	# Old spelling still works in saved programs.
	out["EGSILOG"] = out["EGGSILOG"]
	return out


## Number -> name ("" if unknown).
static func name_of(id: int) -> String:
	if is_dish(id):
		return DISHES.keys()[id - DISH_BASE]
	if is_item(id):
		return INGREDIENTS.keys()[id - ITEM_BASE]
	if is_station(id):
		return STATIONS[id - 1]
	return "NOTHING" if id == 0 else ""


static func id_of(name: String) -> int:
	return constants().get(name, -1)


static func is_station(id: int) -> bool:
	return id >= 1 and id <= STATIONS.size()


static func is_item(id: int) -> bool:
	return id >= ITEM_BASE and id < ITEM_BASE + INGREDIENTS.size()


static func is_dish(id: int) -> bool:
	return id >= DISH_BASE and id < DISH_BASE + DISHES.size()


## Restaurant level that unlocks an ingredient or dish (by name).
static func unlock_level(name: String) -> int:
	if INGREDIENTS.has(name):
		return INGREDIENTS[name]
	if DISHES.has(name):
		return DISHES[name].level
	return 1


## Dish names on the menu at this restaurant level (cumulative). Café dishes
## are included up to `cafe_step` (0 = Café not bought).
static func menu(level: int, cafe_step := 0) -> Array:
	var out: Array = []
	for d in DISHES:
		if available(d, level, cafe_step) == "":
			out.append(d)
	return out


static func is_cafe(name: String) -> bool:
	return DISHES.has(name) and DISHES[name].has("cafe") or name in CAFE_INGREDIENTS


## Café dishes in purchase order.
static func cafe_menu() -> Array:
	var out: Array = []
	for d in DISHES:
		if DISHES[d].has("cafe"):
			out.append(d)
	return out


## Restaurant dishes (not Café).
static func restaurant_menu() -> Array:
	var out: Array = []
	for d in DISHES:
		if not DISHES[d].has("cafe"):
			out.append(d)
	return out


## "" if this dish or ingredient can be used now, else why not.
static func available(name: String, level: int, cafe_step: int) -> String:
	var need := unlock_level(name)
	if need > level:
		if is_cafe(name):
			return "%s is on the Café menu (Restaurant Level %d)." % [name, need]
		return "%s unlocks at Restaurant Level %d." % [name, need]
	if name in CAFE_INGREDIENTS and cafe_step < 1:
		return "%s is a Café ingredient. Unlock the Café first at the Café door." % name
	if DISHES.has(name) and DISHES[name].has("cafe") and cafe_step < DISHES[name].cafe:
		if cafe_step < 1:
			return "%s is on the Café menu. Unlock the Café first at the Café door." % name
		return "%s isn't on your Café menu yet. Buy it at the Café menu board." % name
	return ""


## Café dishes added by one purchase step.
static func cafe_step_dishes(step: int) -> Array:
	var out: Array = []
	for d in DISHES:
		if DISHES[d].get("cafe", 0) == step:
			out.append(d)
	return out


## Stations that cook an ingredient, e.g. ["GRILL", "STOVE"].
static func cook_stations(ing: String) -> Array:
	var out: Array = []
	for st in COOKING:
		if ing in COOKING[st]:
			out.append(st)
	return out


static func title_of(dish: String) -> String:
	return DISHES[dish].title if DISHES.has(dish) else dish


## Readable label for a held item, e.g. "cooked EGG".
static func describe(held: Dictionary) -> String:
	if held.is_empty():
		return "nothing"
	var n := name_of(held.id)
	if held.get("cooked", false) and is_item(held.id):
		return "cooked " + n
	return n


## Readable plate contents, e.g. "RICE, EGG x2".
static func describe_plate(plate: Dictionary) -> String:
	if plate.is_empty():
		return "empty"
	var parts: Array = []
	for ing in plate:
		parts.append(ing if plate[ing] == 1 else "%s x%d" % [ing, plate[ing]])
	return ", ".join(parts)

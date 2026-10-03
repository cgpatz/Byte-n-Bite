extends RefCounted
## Market rules (FR-11–FR-14, FR-58–FR-60): the five stalls and what they sell,
## ingredient prices, random stock, crates and delivery times. Pure data +
## helpers; GameState keeps the live state (inventory, stock, deliveries).
## All numbers are placeholders to balance during testing.

const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")

## Stalls in the Market, in display order. "cafe": opens after the Café is bought.
const STALLS := {
	"GRAINS": {"title": "Grains & Bakery", "vendor": "bruno", "greeting": "Warm bread, fresh rice!",
		"items": ["RICE", "BREAD", "BUN", "NOODLES", "DOUGH", "SUGAR"]},
	"DAIRY": {"title": "Eggs & Dairy", "vendor": "mochi", "greeting": "Eggs laid this morning!",
		"items": ["EGG", "CHEESE", "BUTTER", "CONDENSED_MILK"]},
	"BUTCHER": {"title": "Butcher", "vendor": "rusty", "greeting": "Fresh cuts tonight!",
		"items": ["HOTDOG", "TOCINO", "PATTY", "CHICKEN"]},
	"GREENS": {"title": "Fresh Greens", "vendor": "hazel", "greeting": "Picked today, crunchy!",
		"items": ["LETTUCE", "TOMATO"]},
	"CAFE": {"title": "Café Supplies", "vendor": "kiko", "greeting": "Beans from the hills!", "cafe": true,
		"items": ["COFFEE", "MILK", "MATCHA", "CHOCOLATE", "ICE", "WATER"]},
}

## Coins per ingredient.
const PRICES := {
	"RICE": 5, "EGG": 5, "HOTDOG": 8, "TOCINO": 10, "BREAD": 6, "CHEESE": 8,
	"BUN": 6, "PATTY": 14, "LETTUCE": 5, "TOMATO": 5, "CHICKEN": 15, "NOODLES": 8,
	"COFFEE": 12, "MILK": 7, "CONDENSED_MILK": 9, "MATCHA": 15, "CHOCOLATE": 12,
	"ICE": 2, "WATER": 1, "DOUGH": 7, "BUTTER": 7, "SUGAR": 4,
}

## Express Delivery (FR-61): halves the delivery time for a fixed extra cost.
const EXPRESS_COST := 15

## Random stock: every RESTOCK_SECONDS each stall gets new amounts. An item is
## sold out with SOLD_OUT_CHANCE (never the staples), otherwise it has a random
## amount that depends on its price (cheap items come in bigger batches).
const RESTOCK_SECONDS := 120.0
const SOLD_OUT_CHANCE := 0.15
const STAPLES := ["RICE", "EGG"]

## One crate holds up to CRATE_SIZE of one ingredient.
const CRATE_SIZE := 10
## Crates the delivery area holds, per restaurant level (also the most crates
## one order can bring).
const CRATE_CAPACITY := [2, 4, 4, 9, 12]

## Delivery time: BASE + PER_ITEM seconds per item, at most MAX.
const DELIVERY_BASE := 15.0
const DELIVERY_PER_ITEM := 3.0
const DELIVERY_MAX := 90.0

## Ingredients a new game starts with (enough for the first Egsilogs).
const START_INVENTORY := {"RICE": 10, "EGG": 10, "HOTDOG": 5}


static func price(ing: String) -> int:
	return int(PRICES.get(ing, 5))


static func stall_of(ing: String) -> String:
	for k in STALLS:
		if ing in STALLS[k].items:
			return k
	return ""


## Range of a random batch for an ingredient.
static func batch_range(ing: String) -> Vector2i:
	var p := price(ing)
	if p <= 6:
		return Vector2i(8, 30)
	if p <= 10:
		return Vector2i(5, 18)
	return Vector2i(3, 12)


## New random amounts for every ingredient.
static func roll_stock(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var out := {}
	for ing in PRICES:
		var r := batch_range(ing)
		if not ing in STAPLES and rng.randf() < SOLD_OUT_CHANCE:
			out[ing] = 0
		else:
			out[ing] = rng.randi_range(r.x, r.y)
	return out


static func crates_for(cart: Dictionary) -> int:
	var n := 0
	for ing in cart:
		n += ceili(int(cart[ing]) / float(CRATE_SIZE))
	return n


static func items_in(cart: Dictionary) -> int:
	var n := 0
	for ing in cart:
		n += int(cart[ing])
	return n


static func cost_of(cart: Dictionary) -> int:
	var n := 0
	for ing in cart:
		n += int(cart[ing]) * price(ing)
	return n


static func delivery_seconds(item_count: int, express := false) -> float:
	if item_count <= 0:
		return 0.0
	var t := minf(DELIVERY_BASE + DELIVERY_PER_ITEM * item_count, DELIVERY_MAX)
	return t / 2.0 if express else t


static func crate_capacity(restaurant_level: int) -> int:
	return CRATE_CAPACITY[clampi(restaurant_level, 1, CRATE_CAPACITY.size()) - 1]


## Splits a cart into crates: [{"ing": "RICE", "n": 10}, ...].
static func split_crates(cart: Dictionary) -> Array:
	var out: Array = []
	for ing in cart:
		var left := int(cart[ing])
		while left > 0:
			var n := mini(left, CRATE_SIZE)
			out.append({"ing": ing, "n": n})
			left -= n
	return out


## "Condensed Milk"
static func title(ing: String) -> String:
	return ing.capitalize()


## "0:45"
static func clock(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	return "%d:%02d" % [s / 60, s % 60]

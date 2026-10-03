extends RefCounted
## Player (manager) levels 1–10, EXP, level-up rewards, and when each staff
## member joins. Edit the numbers here to rebalance; no other code changes needed.
##
## EXP comes from sales (every dish served) and quests (challenges).
## Staff levels 1–10 are separate: each staff member levels up on their own.

const MAX_PLAYER_LEVEL := 10

## EXP needed to go from level N to N+1 (first entry = Lv 1 -> 2).
const EXP_TO_NEXT := [100, 160, 240, 340, 460, 600, 760, 940, 1140]

## EXP for a sale = dish price / SALE_EXP_DIVISOR (at least 1).
const SALE_EXP_DIVISOR := 5
## EXP for finishing a quest, by difficulty.
const QUEST_EXP := {"easy": 40, "normal": 80, "hard": 150}

## Coins given when reaching each player level (placeholder amounts).
const LEVEL_COINS := {2: 50, 3: 75, 4: 100, 5: 150, 6: 200, 7: 250, 8: 300, 9: 400, 10: 500}

## Staff members in join order. 6 characters in total: the manager (named by
## the player) + these 5 staff:
##   Jane from the start, John at Restaurant Lv 3, Lee at Manager Lv 5,
##   Rose at Restaurant Lv 5, Gab at Manager Lv 10.
## "by": "start" | "restaurant" | "player", "level": level that unlocks them.
const STAFF := [
	{"name": "Jane", "by": "start", "level": 1, "color": Color(0.45, 0.75, 0.95)},
	{"name": "John", "by": "restaurant", "level": 3, "color": Color(0.95, 0.6, 0.35)},
	{"name": "Lee", "by": "player", "level": 5, "color": Color(0.6, 0.85, 0.45)},
	{"name": "Rose", "by": "restaurant", "level": 5, "color": Color(0.85, 0.5, 0.85)},
	{"name": "Gab", "by": "player", "level": 10, "color": Color(0.95, 0.85, 0.35)},
]

## Staff levels: each staff member is upgraded separately with coins (expensive
## on purpose: a full Lv 1 -> 10 costs 12,050 coins per staff member).
const MAX_STAFF_LEVEL := 10
## Coins to go from Lv N to N+1 (first entry = Lv 1 -> 2).
const STAFF_UPGRADE_COST := [250, 400, 600, 850, 1150, 1500, 1900, 2400, 3000]
## Per level above 1: walks faster, works faster, earns more per dish served.
const STAFF_WALK_PER_LEVEL := 0.06   # Lv 10: +54% walking speed
const STAFF_WORK_PER_LEVEL := 0.05   # Lv 10: actions take 55% of the time
const STAFF_PROFIT_PER_LEVEL := 0.03 # Lv 10: +27% coins on dishes they serve
## Role picked when reaching Lv 10 (FR-17/18).
const STAFF_SPECIALIZATIONS := ["Chef", "Barista", "Cashier", "Waiter"]
const SPECIALIZATION_INFO := {
	"Chef": "Cooks 30% faster (grill, fryer, stove, rice cooker).",
	"Barista": "Brews and bakes 30% faster in the Café (coffee machine, oven).",
	"Cashier": "+20% coins on every dish they serve.",
	"Waiter": "Walks 20% faster; while a Waiter is on staff, customers lose patience 25% slower.",
}
## Café stations sped up by the Barista.
const CAFE_STATIONS := ["COFFEE_MACHINE", "OVEN"]
## Customer patience drain while a Waiter is on staff.
const WAITER_PATIENCE_MULT := 0.75


## Coins for the next staff upgrade (0 = already max level).
static func staff_upgrade_cost(level: int) -> int:
	if level >= MAX_STAFF_LEVEL:
		return 0
	return STAFF_UPGRADE_COST[clampi(level, 1, MAX_STAFF_LEVEL - 1) - 1]


## Total coins spent to reach `level` from Lv 1.
static func staff_spent_to(level: int) -> int:
	var n := 0
	for l in range(1, clampi(level, 1, MAX_STAFF_LEVEL)):
		n += staff_upgrade_cost(l)
	return n


## Walking speed multiplier.
static func staff_walk_mult(level: int, spec := "") -> float:
	var m := 1.0 + STAFF_WALK_PER_LEVEL * (clampi(level, 1, MAX_STAFF_LEVEL) - 1)
	return m * (1.2 if spec == "Waiter" else 1.0)


## Time multiplier for an action ("pick", "cook", "brew" (Café cooking), "plate",
## "assemble", "serve", "trash", "take").
static func staff_work_mult(level: int, spec := "", kind := "") -> float:
	var m := 1.0 - STAFF_WORK_PER_LEVEL * (clampi(level, 1, MAX_STAFF_LEVEL) - 1)
	var fast := false
	match spec:
		"Chef": fast = kind == "cook"
		"Barista": fast = kind == "brew"
	return m * (0.7 if fast else 1.0)


## Coin multiplier for dishes this staff member serves.
static func staff_profit_mult(level: int, spec := "") -> float:
	var m := 1.0 + STAFF_PROFIT_PER_LEVEL * (clampi(level, 1, MAX_STAFF_LEVEL) - 1)
	return m + (0.2 if spec == "Cashier" else 0.0)


## Short "what this level gives" text, e.g. for the upgrade popup.
static func staff_perks_text(level: int, spec := "") -> String:
	var walk := roundi((staff_walk_mult(level, spec) - 1.0) * 100)
	var work := roundi((1.0 - staff_work_mult(level)) * 100)
	var profit := roundi((staff_profit_mult(level, spec) - 1.0) * 100)
	return "+%d%% walking speed · %d%% faster work · +%d%% coins per dish" % [walk, work, profit]


static func exp_to_next(level: int) -> int:
	if level >= MAX_PLAYER_LEVEL:
		return 0
	return EXP_TO_NEXT[clampi(level, 1, MAX_PLAYER_LEVEL - 1) - 1]


static func sale_exp(price: int) -> int:
	return maxi(1, floori(price / float(SALE_EXP_DIVISOR)))


## Staff entries unlocked at these restaurant and player levels.
static func staff_for(restaurant_level: int, player_level: int) -> Array:
	var out: Array = []
	for s in STAFF:
		var ok: bool = s.by == "start" \
			or (s.by == "restaurant" and restaurant_level >= s.level) \
			or (s.by == "player" and player_level >= s.level)
		if ok:
			out.append(s)
	return out


## Text lines describing the rewards for reaching a player level.
static func reward_lines(level: int) -> Array:
	var lines: Array = []
	if LEVEL_COINS.has(level):
		lines.append("+%d coins" % LEVEL_COINS[level])
	for s in STAFF:
		if s.by == "player" and s.level == level:
			lines.append("%s joins your staff" % s.name)
	return lines

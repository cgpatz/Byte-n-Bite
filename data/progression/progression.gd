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

## Staff levels (each staff member levels up separately; upgrades come later).
const MAX_STAFF_LEVEL := 10
const STAFF_SPECIALIZATIONS := ["Chef", "Assistant Chef", "Sales"]


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

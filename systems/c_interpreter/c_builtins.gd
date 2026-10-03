extends RefCounted
## Kitchen functions the player's C code can call, and the restaurant level that
## unlocks each one. Their behaviour lives in the staff script (run_builtin).
## C focus per level (programming learning order): L1 syntax, variables &
## arithmetic, L2 if / else & switch, L3 loops, L4 arrays, L5 functions.

## name -> {"level": unlock level, "args": count, "sig": how it's written, "desc": help text}
const FUNCS := {
	# Level 1 — Tiny Stall: syntax, output, variables, arithmetic
	"go_to": {"level": 1, "args": 1, "sig": "go_to(STATION)", "desc": "Walk up to a station, ready to work there."},
	# Older name for go_to(); still works in saved programs, hidden from lists.
	"move_to": {"level": 1, "args": 1, "sig": "move_to(STATION)", "desc": "Old name for go_to().", "hidden": true},
	"pick_up": {"level": 1, "args": 1, "sig": "pick_up(INGREDIENT)", "desc": "Take an ingredient from the FRIDGE."},
	"cook": {"level": 1, "args": 0, "sig": "cook()", "desc": "Cook what you're holding (GRILL, FRYER, STOVE...)."},
	"plate": {"level": 1, "args": 0, "sig": "plate()", "desc": "At ASSEMBLY: put what you're holding on your plate."},
	"assemble": {"level": 1, "args": 1, "sig": "assemble(DISH)", "desc": "At ASSEMBLY: turn your plate into a dish, e.g. assemble(EGSILOG)."},
	"serve": {"level": 1, "args": 0, "sig": "serve()", "desc": "Carry the dish you're holding to the customer who ordered it."},
	"wait": {"level": 1, "args": 1, "sig": "wait(seconds)", "desc": "Stand still for some seconds."},
	"holding": {"level": 1, "args": 0, "sig": "holding()", "desc": "Returns what you're holding, or NOTHING."},
	# Level 2 — Small Diner: if / else and switch
	"take_order": {"level": 2, "args": 0, "sig": "take_order()", "desc": "Walk to the customer who has waited longest, take their order and return the dish (NOTHING if nobody is waiting)."},
	# Older name for take_order(); still works in saved programs, hidden from lists.
	"next_order": {"level": 2, "args": 0, "sig": "next_order()", "desc": "Old name for take_order().", "hidden": true},
	"is_burnt": {"level": 2, "args": 0, "sig": "is_burnt()", "desc": "Returns 1 if what you're holding is burnt."},
	"trash": {"level": 2, "args": 0, "sig": "trash()", "desc": "At TRASH: throw away what you're holding."},
	# Level 3 — Neighborhood Cafe: loops
	"has_order": {"level": 3, "args": 0, "sig": "has_order()", "desc": "Returns 1 while a customer is waiting for someone to take their order."},
	"post_order": {"level": 3, "args": 1, "sig": "post_order(DISH)", "desc": "At SERVING_COUNTER: pin the order you took as a ticket at the back of the queue."},
	"check_counter": {"level": 3, "args": 0, "sig": "check_counter()", "desc": "Walk to the SERVING_COUNTER and take the oldest ticket (first in, first out). Returns its dish, or NOTHING."},
	"stock": {"level": 3, "args": 1, "sig": "stock(INGREDIENT)", "desc": "Returns how many of an ingredient the kitchen has (the manager buys more at the Market)."},
	"doneness": {"level": 3, "args": 0, "sig": "doneness()", "desc": "Returns 0-100: how cooked the held food is."},
	"flip": {"level": 3, "args": 0, "sig": "flip()", "desc": "At GRILL: flip what's cooking."},
	# Level 4 — Busy Eatery: arrays (answered by the interpreter itself, no walking)
	"recipe": {"level": 4, "args": 2, "sig": "recipe(DISH, items)", "desc": "Fills the array items with the dish's ingredients and returns how many.", "array_arg": 1},
	"orders": {"level": 4, "args": 1, "sig": "orders(list)", "desc": "Copies the dishes on the counter's tickets (oldest first) into an array and returns how many.", "array_arg": 0},
	"cook_station": {"level": 4, "args": 1, "sig": "cook_station(INGREDIENT)", "desc": "Returns the station that cooks an ingredient, or NOTHING if it's served fresh."},
	# Level 5 — Grand Restaurant: your own functions
}

## Standard C functions handled by the interpreter itself.
const C_FUNCS := ["printf"]

const LEVEL_NAMES := ["Tiny Stall", "Small Diner", "Neighborhood Cafe", "Busy Eatery", "Grand Restaurant"]


static func level_name(level: int) -> String:
	return LEVEL_NAMES[clampi(level, 1, LEVEL_NAMES.size()) - 1]


## Function names usable at this restaurant level, in unlock order.
static func unlocked(level: int) -> Array:
	var out: Array = []
	for n in FUNCS:
		if FUNCS[n].level <= level and not FUNCS[n].get("hidden", false):
			out.append(n)
	return out

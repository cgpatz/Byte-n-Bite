extends RefCounted
## Level GOALS: restaurant targets for each level (sell N of each dish, earn a
## profit). They are tracked from sales made at that level. Together with the
## level's CHALLENGES (programming tasks, level_challenges.gd) they unlock the
## next restaurant upgrade. Each goal pays coins and EXP when reached.
##
## Goal: {"id", "title", "dish" (count this dish) or "profit" (coins from
## sales), "n" (target), "coins", "exp"}

const GOALS := {
	1: [
		{"id": "hotsilog", "title": "Make 10 Hotsilog", "dish": "HOTSILOG", "n": 10, "coins": 30, "exp": 40},
		{"id": "eggsilog", "title": "Make 10 Eggsilog", "dish": "EGGSILOG", "n": 10, "coins": 30, "exp": 40},
		{"id": "profit", "title": "Earn 300 profit", "profit": true, "n": 300, "coins": 50, "exp": 60},
	],
	2: [
		{"id": "tocilog", "title": "Make 10 Tocilog", "dish": "TOCILOG", "n": 10, "coins": 40, "exp": 50},
		{"id": "grilled_cheese", "title": "Make 10 Grilled Cheese", "dish": "GRILLED_CHEESE", "n": 10, "coins": 40, "exp": 50},
		{"id": "profit", "title": "Earn 600 profit", "profit": true, "n": 600, "coins": 80, "exp": 80},
	],
	3: [
		{"id": "hamburger", "title": "Make 8 Hamburgers", "dish": "HAMBURGER", "n": 8, "coins": 50, "exp": 60},
		{"id": "fried_chicken", "title": "Make 8 Fried Chicken Meals", "dish": "FRIED_CHICKEN_MEAL", "n": 8, "coins": 50, "exp": 60},
		{"id": "salad", "title": "Make 8 Garden Salads", "dish": "GARDEN_SALAD", "n": 8, "coins": 50, "exp": 60},
		{"id": "profit", "title": "Earn 1000 profit", "profit": true, "n": 1000, "coins": 100, "exp": 100},
	],
	4: [
		{"id": "cheeseburger", "title": "Make 8 Cheeseburgers", "dish": "CHEESEBURGER", "n": 8, "coins": 60, "exp": 80},
		{"id": "pancit", "title": "Make 8 Pancit Canton", "dish": "PANCIT_CANTON", "n": 8, "coins": 60, "exp": 80},
		{"id": "chicken_sandwich", "title": "Make 8 Chicken Sandwiches", "dish": "CHICKEN_SANDWICH", "n": 8, "coins": 60, "exp": 80},
		{"id": "profit", "title": "Earn 1600 profit", "profit": true, "n": 1600, "coins": 150, "exp": 120},
	],
	5: [
		{"id": "double_cheeseburger", "title": "Make 6 Double Cheeseburgers", "dish": "DOUBLE_CHEESEBURGER", "n": 6, "coins": 80, "exp": 100},
		{"id": "silog_platter", "title": "Make 6 Silog Platters", "dish": "SILOG_PLATTER", "n": 6, "coins": 80, "exp": 100},
		{"id": "signature_bowl", "title": "Make 6 Signature Bowls", "dish": "SIGNATURE_BOWL", "n": 6, "coins": 80, "exp": 100},
		{"id": "profit", "title": "Earn 2500 profit", "profit": true, "n": 2500, "coins": 200, "exp": 150},
	],
}


static func for_level(level: int) -> Array:
	return GOALS.get(level, [])


static func find(level: int, id: String) -> Dictionary:
	for g in for_level(level):
		if g.id == id:
			return g
	return {}


## Current amount toward a goal: dishes of that kind sold, or coins from sales,
## at this level. sales = {"dishes": {DISH: n}, "profit": coins}.
static func progress(goal: Dictionary, sales: Dictionary) -> int:
	if goal.get("profit", false):
		return int(sales.get("profit", 0))
	return int(sales.get("dishes", {}).get(goal.dish, 0))

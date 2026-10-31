extends RefCounted
## Ready-to-copy code sets for Admin Runs (testing and demos): a program for
## every dish, the best program for each restaurant level (using only the C
## that level has taught), full solutions to every lesson practice, and
## functions to paste into the Library. All of it is generated from the menu
## data, so it stays correct when recipes change. Every set is compiled by the
## interpreter tests.
##
## Set: {"group", "title", "level", "note", "code"}

const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")


static func all_sets() -> Array:
	var out: Array = []
	for lv in range(1, 6):
		out.append(level_set(lv))
	for lv in range(1, 6):
		out.append(practice_set(lv))
	for t in team_sets():
		out.append(t)
	for lv in range(1, 6):
		out.append({"group": "Level challenges", "title": "Level %d challenges" % lv, "level": lv,
			"note": challenges_note(lv), "code": challenges_program(lv)})
	out.append({"group": "Library", "title": "make_dish(int dish)", "level": 5,
		"note": "Paste into a Library slot (L). Every staff program can then call make_dish(order);",
		"code": make_dish()})
	out.append({"group": "Library", "title": "fetch_cook_plate(int item, int station)", "level": 5,
		"note": "Paste into a Library slot (L). Fetches one ingredient, cooks it there and plates it.",
		"code": FETCH_COOK_PLATE})
	for dish in Kitchen.DISHES:
		var d: Dictionary = Kitchen.DISHES[dish]
		out.append({"group": "Café dishes" if d.has("cafe") else "Dishes",
			"title": d.title, "level": d.level,
			"note": "Makes and serves one %s. Needs Restaurant Level %d%s." % [d.title, d.level, (" and Café set %d" % d.cafe) if d.has("cafe") else ""],
			"code": "void main() {\n%s}" % dish_steps(dish, "    ")})
	return out


## Straight-line steps that make and serve one dish.
static func dish_steps(dish: String, indent: String) -> String:
	var out := ""
	var recipe: Dictionary = Kitchen.DISHES[dish].recipe
	for ing in recipe:
		for n in recipe[ing]:
			out += indent + "go_to(%s); pick_up(%s);\n" % [fetch_station(ing), ing]
			if ing in Kitchen.NEEDS_COOKING:
				out += indent + "go_to(%s); cook();\n" % Kitchen.cook_stations(ing)[0]
			out += indent + "go_to(ASSEMBLY); plate();\n"
	out += indent + "assemble(%s);\n" % dish
	out += indent + "serve();\n"
	return out


## Where to pick up an ingredient (the FRIDGE when it has it).
static func fetch_station(ing: String) -> String:
	if ing in Kitchen.STORAGE.FRIDGE:
		return "FRIDGE"
	for st in Kitchen.STORAGE:
		if ing in Kitchen.STORAGE[st]:
			return st
	return "FRIDGE"


static func _switch_over(menu: Array, indent: String) -> String:
	var out := indent + "switch (order) {\n"
	for dish in menu:
		out += indent + "    case %s:\n" % dish
		out += dish_steps(dish, indent + "        ")
		out += indent + "        break;\n"
	out += indent + "    default:\n"
	out += indent + "        printf(\"Can't make %s yet\\n\", order);\n"
	out += indent + "}\n"
	return out


## The best program for a restaurant level, using only what that level teaches.
static func level_set(lv: int) -> Dictionary:
	var menu: Array = Kitchen.menu(lv, 0)
	var code := ""
	var note := ""
	match lv:
		1:
			note = "Level 1 (no decisions or loops yet): set Today's Special to Eggsilog, then press Run once per customer. Also completes all four Level 1 challenges."
			code = level1_challenges("EGGSILOG")
		2:
			note = "Level 2 (if / switch): reads one order and makes it. Press Run once per customer."
			code = "void main() {\n    int order = take_order();\n%s}" % _switch_over(menu, "    ")
		3:
			note = "Level 3 (loops): serves every order all day with while (1) and switch."
			code = "void main() {\n    while (1) {\n        if (has_order()) {\n            int order = take_order();\n%s        } else {\n            wait(1);\n        }\n    }\n}" % _switch_over(menu, "            ")
		4:
			note = "Level 4 (arrays): one loop makes ANY dish with recipe() and cook_station(), including Café items."
			code = generic_arrays()
		5:
			note = "Level 5 (functions): the array program as a reusable make_dish() function."
			code = make_dish() + "\n\nvoid main() {\n    while (1) {\n        if (has_order()) {\n            make_dish(take_order());\n        } else {\n            wait(1);\n        }\n    }\n}"
	return {"group": "Best program per level", "title": "Level %d" % lv, "level": lv, "note": note, "code": code}


## A waiter and a cook working together through the ticket queue (Level 3+).
static func team_sets() -> Array:
	var menu: Array = Kitchen.menu(3, 0)
	var waiter := "// Waiter: takes every order and posts a ticket on the counter.\nvoid main() {\n    while (1) {\n        if (has_order()) {\n            int order = take_order();\n            go_to(SERVING_COUNTER);\n            post_order(order);\n        } else {\n            wait(1);\n        }\n    }\n}"
	var cook := "// Cook: makes the oldest ticket on the counter (first in, first out).\nvoid main() {\n    while (1) {\n        int order = check_counter();\n        if (order == NOTHING) {\n            wait(1);\n        } else {\n%s        }\n    }\n}" % _switch_over(menu, "            ")
	var cook4 := "// Cook (arrays): makes ANY ticket with recipe() and cook_station().\nvoid main() {\n    int items[8];\n    while (1) {\n        int order = check_counter();\n        if (order == NOTHING) {\n            wait(1);\n        } else {\n%s        }\n    }\n}" % _array_steps("order", "            ")
	return [
		{"group": "Waiter + cook", "title": "Waiter (take + post orders)", "level": 3,
			"note": "Give this to the waiter (e.g. John). Customers' orders become tickets on the SERVING_COUNTER.", "code": waiter},
		{"group": "Waiter + cook", "title": "Cook (check_counter + switch)", "level": 3,
			"note": "Give this to the cook (e.g. Jane) while someone runs the Waiter program.", "code": cook},
		{"group": "Waiter + cook", "title": "Cook with arrays", "level": 4,
			"note": "Level 4 cook: one loop makes any ticket, Café items included.", "code": cook4},
	]


## Makes and serves one dish and finishes every Level 1 challenge (int + %d,
## float + %.2f, char + %c, and the receipt line after serve()).
static func level1_challenges(dish: String) -> String:
	var title: String = Kitchen.DISHES[dish].title
	var price: int = Kitchen.DISHES[dish].price
	var head := "// Level 1 challenges: receipt, talk to the customer, two in a row\nvoid main() {\n    int served = 0;\n    float price = %d.00;\n    char size = 'L';\n    int dish = %s;\n\n" % [price, dish]
	var out := head
	for n in 2:
		out += dish_steps(dish, "    ")
		out += "    served++;\n"
	out += "    printf(\"Order #%%d  %s x1  %%.2f  size %%c\\n\", served, price, size);\n" % title
	out += "    // printf also makes the staff member talk (thought bubble)\n"
	out += "    printf(\"Hi! Here's your %s, for a price of %.2f. Enjoy!\\n\", dish, price);\n"
	out += "    float total = price * served;\n"
	out += "    printf(\"Total: %.2f\\n\", total);\n}"
	return out


static func challenges_note(lv: int) -> String:
	match lv:
		1: return "Finishes all three Level 1 challenges in one Run (needs 2 orders) (Today's Special: Eggsilog)."
		2: return "Two customers: take_order(), if / else if / else with ||, and a switch with default (all three Level 2 challenges)."
		3: return "Cook program: a for loop over 3 tickets (Busy shift, for loop, Waiter + cook). Give the Waiter program to another staff member."
		4: return "Any dish with recipe() + sizeof. 'One loop, any dish' completes once two different dishes are served."
		_: return "Put make_dish() in a Library slot first (Code Sets › Library). Uses your own functions, a return value and the Library."


static func challenges_program(lv: int) -> String:
	match lv:
		1:
			return level1_challenges("EGGSILOG")
		2:
			var block := ("    order = take_order();\n    if (order == NOTHING) {\n        printf(\"Nobody is waiting\\n\");\n"
				+ "    } else if (order == EGGSILOG || order == HOTSILOG) {\n" + _switch_over(Kitchen.menu(2, 0), "        ")
				+ "    } else {\n" + _switch_over(Kitchen.menu(2, 0), "        ") + "    }\n")
			return "// Level 2 challenges: if / else if / else, switch with default, && / ||, 2 customers\nvoid main() {\n    int order = NOTHING;\n" + block + block + "}"
		3:
			return ("// Level 3 challenges (cook): serve 3 tickets with a for loop\nvoid main() {\n    for (int i = 0; i < 3; i++) {\n"
				+ "        int order = check_counter();\n        while (order == NOTHING) {\n            wait(1);\n            order = check_counter();\n        }\n"
				+ _switch_over(Kitchen.menu(3, 0), "        ") + "    }\n}")
		4:
			return generic_arrays().replace("    int items[8];\n", "    int items[8];\n    int room = sizeof(items) / sizeof(items[0]);\n    printf(\"Room for %d ingredients\\n\", room);\n")
		_:
			return ("// Level 5 challenges (needs make_dish() in a Library slot)\nint price_of(int dish) {\n    if (dish == EGGSILOG) {\n        return 30;\n    }\n    return 50;\n}\n\n"
				+ "void main() {\n    while (1) {\n        if (has_order()) {\n            int order = take_order();\n            make_dish(order);\n"
				+ "            printf(\"About %d coins\\n\", price_of(order));\n        } else {\n            wait(1);\n        }\n    }\n}")


## Full solutions to the lesson practice tasks.
static func practice_set(lv: int) -> Dictionary:
	var code := ""
	var title := ""
	match lv:
		1:
			title = "Lesson 1: the four Level 1 challenges"
			code = level1_challenges("HOTSILOG")
		2:
			title = "Lesson 2: switch on take_order()"
			code = "void main() {\n    int order = take_order();\n%s}" % _switch_over(["EGGSILOG", "HOTSILOG", "TOCILOG"], "    ")
		3:
			title = "Lesson 3: serve all day"
			code = "void main() {\n    while (1) {\n        if (has_order()) {\n            int order = take_order();\n%s        } else {\n            wait(1);\n        }\n    }\n}" % _switch_over(["EGGSILOG", "HAMBURGER"], "            ")
		4:
			title = "Lesson 4: any dish with arrays"
			code = generic_arrays()
		5:
			title = "Lesson 5: make_dish()"
			code = make_dish() + "\n\nvoid main() {\n    while (1) {\n        if (has_order()) {\n            make_dish(take_order());\n        } else {\n            wait(1);\n        }\n    }\n}"
	return {"group": "Lesson practice solutions", "title": title, "level": lv,
		"note": "Solution to the practice page of Lesson %d." % lv, "code": code}


## Which ingredients the FRIDGE doesn't have, and where to get them instead.
static func _not_in_fridge() -> Dictionary:
	var out := {}
	for dish in Kitchen.DISHES:
		for ing in Kitchen.DISHES[dish].recipe:
			if not ing in Kitchen.STORAGE.FRIDGE and not out.has(ing):
				out[ing] = fetch_station(ing)
	return out


## The go_to() for items[i]: the FRIDGE, or else-if branches for the rest.
static func _fetch_lines(var_name: String, indent: String) -> String:
	var others := _not_in_fridge()
	if others.is_empty():
		return indent + "go_to(FRIDGE);\n"
	var out := ""
	var first := true
	for ing in others:
		out += indent + ("if" if first else "} else if") + " (%s == %s) {\n" % [var_name, ing]
		out += indent + "    go_to(%s);\n" % others[ing]
		first = false
	out += indent + "} else {\n" + indent + "    go_to(FRIDGE);\n" + indent + "}\n"
	return out


## One loop that makes the dish whose ingredient list recipe() fills in.
static func _array_steps(dish_var: String, indent: String) -> String:
	var i2 := indent + "    "
	return (indent + "int n = recipe(%s, items);\n" % dish_var
		+ indent + "for (int i = 0; i < n; i++) {\n"
		+ _fetch_lines("items[i]", i2)
		+ i2 + "pick_up(items[i]);\n"
		+ i2 + "int where = cook_station(items[i]);\n"
		+ i2 + "if (where != NOTHING) {\n"
		+ i2 + "    go_to(where);\n"
		+ i2 + "    cook();\n"
		+ i2 + "}\n"
		+ i2 + "go_to(ASSEMBLY);\n"
		+ i2 + "plate();\n"
		+ indent + "}\n"
		+ indent + "assemble(%s);\n" % dish_var
		+ indent + "serve();\n")


static func generic_arrays() -> String:
	return ("void main() {\n    int items[8];\n    while (1) {\n        if (has_order()) {\n"
		+ "            int order = take_order();\n"
		+ _array_steps("order", "            ")
		+ "        } else {\n            wait(1);\n        }\n    }\n}")


static func make_dish() -> String:
	return ("// Makes and serves any dish (needs Restaurant Level 4 for recipe()).\nvoid make_dish(int dish) {\n    int items[8];\n"
		+ _array_steps("dish", "    ") + "}")


const FETCH_COOK_PLATE := """// Fetches an ingredient, cooks it at a station (NOTHING = fresh) and plates it.
void fetch_cook_plate(int item, int station) {
    go_to(FRIDGE);
    pick_up(item);
    if (station != NOTHING) {
        go_to(station);
        cook();
    }
    go_to(ASSEMBLY);
    plate();
}"""

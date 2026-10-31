extends RefCounted
## Level challenges (the Challenge Board): small programming tasks the game checks
## automatically while a staff program runs. Each restaurant level has challenges
## that make the player USE that level's C concept; the next restaurant upgrade
## waits until they're done (along with the level's goals, level_goals.gd). Every challenge pays coins AND EXP.
##
## A staff member keeps a trace of the current Run (staff.gd run_trace):
##   served   dishes served so far          dishes   {DISH: true} served
##   tickets  tickets taken with check_counter()
##   printfs  [{"items": [{conv, type, var, changed}], "served_before": n}]
##   stats    the interpreter's counters (c_interpreter.gd `stats`):
##            if_else, switch, switch_default, loop, for, index, sizeof, array,
##            array2d, user_call, user_call_args, user_return, library_call,
##            fn:<kitchen function>

## level -> [{id, title, task, how, coins, exp}]   (exp = EXP points)
const GOALS := {
	1: [
		{"id": "receipt", "title": "Print a receipt", "coins": 100, "exp": 80,
			"task": "After serve(), print ONE line that uses an int (%d), a float (%.2f) and a char (%c) variable.",
			"how": "printf(\"Order #%d  Eggsilog x1  %.2f  size %c\\n\", served, price, size);"},
		{"id": "talk", "title": "Talk to the customer", "coins": 60, "exp": 60,
			"task": "After serve(), make your staff SAY a line with printf: a dish variable with %s and a float price with %.2f.",
			"how": "int dish = EGGSILOG;  ...serve();  printf(\"Here's your %s, for %.2f\\n\", dish, price);"},
		{"id": "two", "title": "Two in a row", "coins": 80, "exp": 80,
			"task": "Serve 2 dishes in ONE Run, then print the total coins you calculated with + or *.",
			"how": "...serve(); ...serve();  int total = price * 2;  printf(\"Total: %d\\n\", total);"},
	],
	2: [
		{"id": "decide", "title": "Decide the order", "coins": 80, "exp": 80,
			"task": "take_order(), then pick what to cook with an if / else if / else chain, and serve it.",
			"how": "int order = take_order();  if (order == EGGSILOG) { ... } else if (order == HOTSILOG) { ... } else { ... }"},
		{"id": "switch", "title": "Switch on the order", "coins": 80, "exp": 80,
			"task": "Use a switch with case labels AND a default, and serve the dish.",
			"how": "switch (order) { case EGGSILOG: ... break; default: printf(\"?\\n\"); }"},
		{"id": "combo", "title": "Smart combo", "coins": 100, "exp": 100,
			"task": "Serve 2 customers in ONE Run, using && or || in a condition.",
			"how": "if (order == EGGSILOG || order == HOTSILOG) { ...silog steps... }"},
	],
	3: [
		{"id": "three", "title": "Busy shift", "coins": 80, "exp": 80,
			"task": "Serve 3 dishes in ONE Run (you'll need a loop).",
			"how": "while (1) { if (has_order()) { ... serve(); } else { wait(1); } }"},
		{"id": "for", "title": "Count with a for loop", "coins": 80, "exp": 80,
			"task": "Run a for loop at least twice in a program that serves a dish.",
			"how": "for (int i = 0; i < 2; i++) { ...fetch and plate an EGG... }"},
		{"id": "team", "title": "Waiter + cook", "coins": 100, "exp": 150,
			"task": "A cook takes a ticket with check_counter() and serves it (a waiter posts it with post_order()).",
			"how": "int order = check_counter();  if (order != NOTHING) { ...  serve(); }"},
	],
	4: [
		{"id": "recipe", "title": "Recipe in an array", "coins": 100, "exp": 80,
			"task": "Fill an array with recipe() and loop over it to make and serve a dish.",
			"how": "int items[8];  int n = recipe(order, items);  for (...) { pick_up(items[i]); ... }"},
		{"id": "anydish", "title": "One loop, any dish", "coins": 120, "exp": 150,
			"task": "Serve 2 DIFFERENT dishes in one Run with the same recipe() loop.",
			"how": "while (1) { ... int n = recipe(order, items); for (...) { ... } serve(); }"},
		{"id": "sizeof", "title": "Measure with sizeof", "coins": 100, "exp": 80,
			"task": "Use sizeof to find an array's length in a program that serves a dish.",
			"how": "int n = sizeof(items) / sizeof(items[0]);"},
	],
	5: [
		{"id": "func", "title": "Your own function", "coins": 120, "exp": 150,
			"task": "Write a function with a parameter and call it twice in a Run that serves a dish.",
			"how": "void fetch(int item) { go_to(FRIDGE); pick_up(item); ... }   fetch(RICE); fetch(EGG);"},
		{"id": "return", "title": "Return a value", "coins": 120, "exp": 150,
			"task": "Call a function that returns a value (int, float...) in a Run that serves a dish.",
			"how": "int price_of(int dish) { if (dish == EGGSILOG) { return 30; } return 40; }"},
		{"id": "library", "title": "Use your Library", "coins": 150, "exp": 150,
			"task": "Call a function saved in your Library (L) from a staff program that serves a dish.",
			"how": "make_dish(take_order());   // make_dish() lives in a Library slot"},
	],
}


static func for_level(level: int) -> Array:
	return GOALS.get(level, [])


static func find(level: int, id: String) -> Dictionary:
	for g in for_level(level):
		if g.id == id:
			return g
	return {}


static func _n(trace: Dictionary, key: String) -> int:
	return int(trace.get("stats", {}).get(key, 0))


## Which of this level's challenges the trace completes.
static func met(level: int, trace: Dictionary) -> Array:
	var out: Array = []
	var served := int(trace.get("served", 0))
	if served < 1:
		return out
	match level:
		1:
			for p in trace.get("printfs", []):
				var has_d := false
				var has_f := false
				var has_c := false
				var has_s := false
				for it in p.items:
					if not it.var:
						continue
					if it.conv in ["d", "i"] and it.type == "int":
						has_d = true
					elif it.conv == "f" and it.type in ["float", "double"]:
						has_f = true
					elif it.conv == "c" and it.type == "char":
						has_c = true
					elif it.conv == "s" and it.type == "int":
						has_s = true
				var after := int(p.served_before)
				if has_d and has_f and has_c and after >= 1 and not "receipt" in out:
					out.append("receipt")
				if has_s and has_f and after >= 1 and not "talk" in out:
					out.append("talk")
				if after >= 2 and (has_d or has_f) and _n(trace, "math") >= 1 and not "two" in out:
					out.append("two")
		2:
			var took := _n(trace, "fn:take_order") + _n(trace, "fn:next_order") >= 1
			if took and _n(trace, "else_if") >= 1:
				out.append("decide")
			if _n(trace, "switch") >= 1 and _n(trace, "switch_default") >= 1:
				out.append("switch")
			if served >= 2 and _n(trace, "logic") >= 1:
				out.append("combo")
		3:
			if served >= 3:
				out.append("three")
			if _n(trace, "for") >= 2:
				out.append("for")
			if int(trace.get("tickets", 0)) >= 1:
				out.append("team")
		4:
			if _n(trace, "fn:recipe") >= 1 and _n(trace, "index") >= 1:
				out.append("recipe")
			if _n(trace, "fn:recipe") >= 2 and trace.get("dishes", {}).size() >= 2:
				out.append("anydish")
			if _n(trace, "sizeof") >= 1:
				out.append("sizeof")
		5:
			if _n(trace, "user_call_args") >= 2:
				out.append("func")
			if _n(trace, "user_return") >= 1:
				out.append("return")
			if _n(trace, "library_call") >= 1:
				out.append("library")
	return out



# --- Mastery quests (optional, harder; bonus coins and EXP) ------------------------

const MASTERY := {
	1: [
		{"id": "triple", "title": "Breakfast rush", "coins": 120, "exp": 100,
			"task": "Serve 3 dishes in ONE Run (no loops yet: plan every step!).",
			"how": "Write the steps for 3 dishes one after another, then press Run once."},
		{"id": "hotsilog_pair", "title": "Hotsilog combo", "coins": 140, "exp": 110,
			"task": "Serve 2 Hotsilog (3 ingredients each) in ONE Run and print a receipt line after each.",
			"how": "...assemble(HOTSILOG); serve(); printf(\"#%d Hotsilog\\n\", served); ... (twice)"},
		{"id": "menu_card", "title": "Menu card", "coins": 100, "exp": 90,
			"task": "After serving, print a 3-line menu card that uses %s, %d, %.2f and %c somewhere.",
			"how": "printf(\"%s\\n\", dish); printf(\"Qty %d  Size %c\\n\", qty, size); printf(\"%.2f\\n\", price);"},
	],
	2: [
		{"id": "variety", "title": "Full menu", "coins": 150, "exp": 120,
			"task": "Serve 3 DIFFERENT dishes in ONE Run, deciding each one with take_order().",
			"how": "Three take_order() blocks, each with a switch or if / else if."},
		{"id": "quality", "title": "Quality check", "coins": 140, "exp": 120,
			"task": "Check is_burnt() before plating and serve 2 dishes in ONE Run.",
			"how": "cook(); if (is_burnt()) { go_to(TRASH); trash(); } else { go_to(ASSEMBLY); plate(); }"},
		{"id": "price_tag", "title": "Price with ? :", "coins": 120, "exp": 100,
			"task": "Pick a price with the short-hand if (? :) and print it after serving.",
			"how": "float price = (order == HOTSILOG) ? 40.0 : 30.0;  printf(\"%.2f\\n\", price);"},
	],
	3: [
		{"id": "shift", "title": "Whole shift", "coins": 200, "exp": 150,
			"task": "Serve 6 dishes in ONE Run with a loop.",
			"how": "while (1) { int order = take_order(); ... serve(); }"},
		{"id": "do_rush", "title": "Do-while rush", "coins": 180, "exp": 140,
			"task": "Serve 4 dishes in ONE Run using a do / while loop.",
			"how": "int served = 0;  do { ...make and serve... served++; } while (served < 4);"},
		{"id": "stock_watch", "title": "Stock watch", "coins": 180, "exp": 140,
			"task": "Use stock() and break to stop the loop when an ingredient runs low, after serving 2.",
			"how": "while (1) { if (stock(EGG) < 1) { break; } ... serve(); }"},
	],
	4: [
		{"id": "queue", "title": "Ticket master", "coins": 250, "exp": 180,
			"task": "Read the tickets with orders() and serve 4 dishes in ONE Run.",
			"how": "int list[8];  int n = orders(list);  for (int i = 0; i < n; i++) { ... }"},
		{"id": "grid_menu", "title": "Menu grid", "coins": 220, "exp": 170,
			"task": "Keep the menu in a 2D array and serve 3 dishes in ONE Run.",
			"how": "int menu[2][2] = {{EGGSILOG, HOTSILOG}, {HAMBURGER, TOCILOG}};"},
		{"id": "any_three", "title": "Any dish, any time", "coins": 240, "exp": 180,
			"task": "Serve 3 DIFFERENT dishes with ONE recipe() loop that uses sizeof.",
			"how": "int items[8]; int n = recipe(order, items); for (int i = 0; i < n; i++) { ... }"},
	],
	5: [
		{"id": "head_chef", "title": "Head chef", "coins": 300, "exp": 250,
			"task": "Serve 4 DIFFERENT dishes in ONE Run using a function from your Library.",
			"how": "while (1) { make_dish(take_order()); }   // make_dish() lives in your Library"},
		{"id": "bookkeeper", "title": "Bookkeeper", "coins": 280, "exp": 220,
			"task": "Serve 3 dishes and get each price from your own function that uses return.",
			"how": "int price_of(int dish) { ... return 30; }   total += price_of(order);"},
		{"id": "kitchen_team", "title": "Kitchen team", "coins": 320, "exp": 260,
			"task": "Serve 5 dishes in ONE Run calling Library functions at least 3 times.",
			"how": "for (...) { make_dish(take_order()); }"},
	],
}


static func mastery_for(level: int) -> Array:
	return MASTERY.get(level, [])


static func find_mastery(level: int, id: String) -> Dictionary:
	for g in mastery_for(level):
		if g.id == id:
			return g
	return {}


## Which of this level's Mastery quests the trace completes.
static func met_mastery(level: int, trace: Dictionary) -> Array:
	var out: Array = []
	var served := int(trace.get("served", 0))
	var dishes: Dictionary = trace.get("dishes", {})
	var kinds: int = dishes.size()
	var printfs: Array = trace.get("printfs", [])
	var took := _n(trace, "fn:take_order") + _n(trace, "fn:next_order")
	match level:
		1:
			if served >= 3:
				out.append("triple")
			var after_serves := {}
			for p in printfs:
				if int(p.served_before) >= 1:
					after_serves[int(p.served_before)] = true
			if dishes.has("HOTSILOG") and served >= 2 and after_serves.has(1) and after_serves.has(2):
				out.append("hotsilog_pair")
			var convs := {}
			var lines := 0
			for p in printfs:
				if int(p.served_before) >= 1:
					lines += 1
					for it in p.items:
						convs[it.conv] = true
			if lines >= 3 and convs.has("s") and convs.has("f") and convs.has("c") and (convs.has("d") or convs.has("i")):
				out.append("menu_card")
		2:
			if kinds >= 3 and took >= 3:
				out.append("variety")
			if _n(trace, "fn:is_burnt") >= 1 and served >= 2:
				out.append("quality")
			if _n(trace, "ternary") >= 1 and served >= 1:
				for p in printfs:
					if int(p.served_before) >= 1:
						out.append("price_tag")
						break
		3:
			if served >= 6 and _n(trace, "loop") >= 1:
				out.append("shift")
			if served >= 4 and _n(trace, "do_while") >= 1:
				out.append("do_rush")
			if served >= 2 and _n(trace, "fn:stock") >= 1 and _n(trace, "break") >= 1:
				out.append("stock_watch")
		4:
			if served >= 4 and _n(trace, "fn:orders") >= 1:
				out.append("queue")
			if served >= 3 and _n(trace, "array2d") >= 1:
				out.append("grid_menu")
			if kinds >= 3 and _n(trace, "fn:recipe") >= 3 and _n(trace, "sizeof") >= 1:
				out.append("any_three")
		5:
			if kinds >= 4 and _n(trace, "library_call") >= 1:
				out.append("head_chef")
			if served >= 3 and _n(trace, "user_return") >= 3:
				out.append("bookkeeper")
			if served >= 5 and _n(trace, "library_call") >= 3:
				out.append("kitchen_team")
	return out

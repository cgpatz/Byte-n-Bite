extends RefCounted
## Level goals (the Challenge Board): small programming tasks the game checks
## automatically while a staff program runs. Each restaurant level has goals
## that make the player USE that level's C concept; the next restaurant upgrade
## waits until they're done. Every goal pays coins AND EXP.
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
		{"id": "count", "title": "Count your sales", "coins": 40, "exp": 40,
			"task": "Serve a dish, add 1 to an int variable, and print it with %d.",
			"how": "int served = 0;  ...serve();  served++;  printf(\"Served: %d\\n\", served);"},
		{"id": "price", "title": "Price tag", "coins": 40, "exp": 40,
			"task": "Serve a dish and print a float price with %.2f.",
			"how": "float price = 30.50;  printf(\"Price: %.2f\\n\", price);"},
		{"id": "size", "title": "Size code", "coins": 40, "exp": 40,
			"task": "Serve a dish and print a char with %c.",
			"how": "char size = 'L';  printf(\"Size: %c\\n\", size);"},
		{"id": "receipt", "title": "Print a receipt", "coins": 100, "exp": 80,
			"task": "After serve(), print ONE line that uses an int (%d), a float (%.2f) and a char (%c) variable.",
			"how": "printf(\"Order #%d  Egsilog x1  %.2f  size %c\\n\", served, price, size);"},
	],
	2: [
		{"id": "take", "title": "Take an order", "coins": 60, "exp": 60,
			"task": "Use take_order() to ask a customer, then make and serve what they ordered.",
			"how": "int order = take_order();  ...make it...  serve();"},
		{"id": "ifelse", "title": "Decide with if / else", "coins": 60, "exp": 60,
			"task": "Use an if with an else to choose what to cook, and serve the dish.",
			"how": "if (order == EGSILOG) { ... } else { ... }"},
		{"id": "switch", "title": "Switch on the order", "coins": 80, "exp": 80,
			"task": "Use a switch with case labels AND a default, and serve the dish.",
			"how": "switch (order) { case EGSILOG: ... break; default: printf(\"?\\n\"); }"},
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
			"how": "int price_of(int dish) { if (dish == EGSILOG) { return 30; } return 40; }"},
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


## Which of this level's goals the trace completes.
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
				for it in p.items:
					if not it.var:
						continue
					if it.conv in ["d", "i"] and it.type == "int":
						has_d = true
						if it.changed and not "count" in out:
							out.append("count")
					elif it.conv == "f" and it.type in ["float", "double"]:
						has_f = true
						if not "price" in out:
							out.append("price")
					elif it.conv == "c" and it.type == "char":
						has_c = true
						if not "size" in out:
							out.append("size")
				if has_d and has_f and has_c and int(p.served_before) >= 1 and not "receipt" in out:
					out.append("receipt")
		2:
			if _n(trace, "fn:take_order") + _n(trace, "fn:next_order") >= 1:
				out.append("take")
			if _n(trace, "if_else") >= 1:
				out.append("ifelse")
			if _n(trace, "switch") >= 1 and _n(trace, "switch_default") >= 1:
				out.append("switch")
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

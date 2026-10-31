extends RefCounted
## Chef Miso's hands-on C quests: one per C topic, grouped by restaurant level
## (the same order as the lessons). After a level's walkthrough, Chef Miso
## asks the player to USE each new idea in a staff member's real program. The
## gameplay guide (scenes/ui/guide/gameplay_guide.gd) checks the program while
## it runs (the interpreter's counters and printf records) and moves on only
## when it works.
##
## Quest: {"topic", "say" (BBCode), "example" (C code shown in the box),
##         "do" (the quest line; {who} = the staff member), "check" (id handled by met() below)}

const QUESTS := {
	1: [
		{"topic": "Output with printf", "check": "printf",
			"say": "Your first C line! [b]printf[/b] prints text, and the staff member says it out loud. Put the words in double quotes and end with [b]\\n[/b] for a new line. Try greeting yourself by name!",
			"example": "printf(\"Good morning!\\n\");",
			"do": "Make {who} greet YOU: [b]printf[/b] a line with your name, then press [b]Run[/b]."},
		{"topic": "Kitchen commands", "check": "kitchen",
			"say": "Staff work through [b]function calls[/b]: [b]go_to[/b] a station, [b]pick_up[/b] an ingredient, [b]cook()[/b] it. Rice cooks only at the [b]RICE_COOKER[/b].",
			"example": "go_to(FRIDGE);\npick_up(RICE);\ngo_to(RICE_COOKER);\ncook();",
			"do": "Make {who} [b]go_to[/b] the FRIDGE, [b]pick_up[/b] an ingredient and [b]cook()[/b] it."},
		{"topic": "int variables and %d", "check": "int",
			"say": "A [b]variable[/b] stores a value. [b]int[/b] holds whole numbers; print it with [b]%d[/b] and put the variable after the quotes.",
			"example": "int eggs = 3;\nprintf(\"Eggs: %d\\n\", eggs);",
			"do": "Make an [b]int[/b] variable and print it with [b]%d[/b]."},
		{"topic": "float and %.2f", "check": "float",
			"say": "[b]float[/b] holds decimals, like prices. [b]%.2f[/b] prints it with 2 decimals.",
			"example": "float price = 30.50;\nprintf(\"Price: %.2f\\n\", price);",
			"do": "Make a [b]float[/b] price and print it with [b]%.2f[/b]."},
		{"topic": "char and %c", "check": "char",
			"say": "[b]char[/b] holds ONE letter in single quotes. Print it with [b]%c[/b].",
			"example": "char size = 'L';\nprintf(\"Size: %c\\n\", size);",
			"do": "Make a [b]char[/b] and print it with [b]%c[/b]."},
		{"topic": "Arithmetic", "check": "math",
			"say": "C does math with [b]+ - * /[/b] and [b]%[/b] (remainder). Use it right inside printf or store the result.",
			"example": "int total = 30 * 2 + 40;\nprintf(\"Total: %d\\n\", total);",
			"do": "Use [b]+ - * /[/b] or [b]%[/b] to calculate something and print it."},
		{"topic": "++ and +=", "check": "incdec",
			"say": "Keep score with shortcuts: [b]served++;[/b] adds 1 and [b]coins += 30;[/b] adds 30.",
			"example": "int served = 0;\nserved++;\nprintf(\"Served: %d\\n\", served);",
			"do": "Change a variable with [b]++[/b], [b]--[/b] or [b]+=[/b] and print it."},
	],
	2: [
		{"topic": "Comparing values", "check": "compare",
			"say": "[b]== != < > <= >=[/b] compare two values and give 1 (true) or 0 (false). [b]==[/b] compares; one [b]=[/b] stores.",
			"example": "int eggs = 3;\nprintf(\"%d\\n\", eggs > 2);",
			"do": "Compare two values with [b]==[/b], [b]<[/b], [b]>[/b]... and run it."},
		{"topic": "if", "check": "if",
			"say": "[b]if[/b] runs its block only when the condition is true.",
			"example": "int order = take_order();\nif (order == EGGSILOG) {\n    printf(\"Eggsilog!\\n\");\n}",
			"do": "Write an [b]if[/b] statement and run it."},
		{"topic": "if / else", "check": "else",
			"say": "[b]else[/b] runs when the condition is false, so exactly one of the two blocks runs.",
			"example": "if (holding() == NOTHING) {\n    printf(\"Free hands\\n\");\n} else {\n    printf(\"Busy\\n\");\n}",
			"do": "Write an [b]if[/b] with an [b]else[/b] and run it."},
		{"topic": "else if", "check": "elseif",
			"say": "[b]else if[/b] checks another condition. The first true one wins.",
			"example": "int order = take_order();\nif (order == EGGSILOG) {\n    printf(\"E\\n\");\n} else if (order == HOTSILOG) {\n    printf(\"H\\n\");\n} else {\n    printf(\"?\\n\");\n}",
			"do": "Write an [b]if / else if / else[/b] chain and run it."},
		{"topic": "&& and ||", "check": "logic",
			"say": "Join conditions: [b]&&[/b] (and) needs both true, [b]||[/b] (or) needs one.",
			"example": "int order = take_order();\nif (order == EGGSILOG || order == HOTSILOG) {\n    printf(\"Silog!\\n\");\n}",
			"do": "Use [b]&&[/b] or [b]||[/b] in a condition and run it."},
		{"topic": "switch", "check": "switch",
			"say": "[b]switch[/b] matches one value against [b]case[/b] labels. End each case with [b]break;[/b] and add a [b]default:[/b].",
			"example": "int order = take_order();\nswitch (order) {\n    case EGGSILOG:\n        printf(\"E\\n\");\n        break;\n    default:\n        printf(\"?\\n\");\n}",
			"do": "Write a [b]switch[/b] with a [b]case[/b] and a [b]default[/b] and run it."},
	],
	3: [
		{"topic": "while", "check": "while",
			"say": "[b]while[/b] repeats its block as long as the condition is true. Change something inside so it ends!",
			"example": "int i = 0;\nwhile (i < 3) {\n    printf(\"Round %d\\n\", i);\n    i++;\n}",
			"do": "Write a [b]while[/b] loop that runs at least once."},
		{"topic": "do / while", "check": "do_while",
			"say": "[b]do / while[/b] runs the block first, then checks, so it always runs at least once.",
			"example": "int i = 0;\ndo {\n    i++;\n} while (i < 3);\nprintf(\"%d\\n\", i);",
			"do": "Write a [b]do / while[/b] loop and run it."},
		{"topic": "for", "check": "for",
			"say": "[b]for[/b] keeps start, condition and step together: perfect for counting.",
			"example": "for (int i = 0; i < 3; i++) {\n    printf(\"Plate %d\\n\", i);\n}",
			"do": "Write a [b]for[/b] loop and run it."},
		{"topic": "Nested loops", "check": "nested",
			"say": "A loop inside a loop: the inner loop runs fully for every round of the outer one.",
			"example": "for (int t = 0; t < 2; t++) {\n    for (int s = 0; s < 3; s++) {\n        printf(\"%d-%d\\n\", t, s);\n    }\n}",
			"do": "Put a loop inside another loop and run it."},
		{"topic": "break and continue", "check": "break_continue",
			"say": "[b]break[/b] leaves a loop early; [b]continue[/b] skips to the next round.",
			"example": "for (int i = 0; i < 10; i++) {\n    if (i == 3) {\n        break;\n    }\n    printf(\"%d\\n\", i);\n}",
			"do": "Use [b]break[/b] or [b]continue[/b] inside a loop and run it."},
	],
	4: [
		{"topic": "Arrays", "check": "array",
			"say": "An [b]array[/b] keeps many values in one variable. Use [b]list[i][/b] to read one; the first index is [b]0[/b].",
			"example": "int dishes[] = {EGGSILOG, HOTSILOG};\nprintf(\"%s\\n\", dishes[0]);",
			"do": "Make an [b]array[/b] and read an item with [b][ ][/b]."},
		{"topic": "Looping through an array", "check": "array_loop",
			"say": "A [b]for[/b] loop with [b]i[/b] as the index visits every item.",
			"example": "int prices[] = {30, 40, 45};\nfor (int i = 0; i < 3; i++) {\n    printf(\"%d\\n\", prices[i]);\n}",
			"do": "Loop through an array with a [b]for[/b] loop."},
		{"topic": "sizeof", "check": "sizeof",
			"say": "[b]sizeof(list) / sizeof(list[0])[/b] tells how many items an array has.",
			"example": "int prices[] = {30, 40, 45};\nint n = sizeof(prices) / sizeof(prices[0]);\nprintf(\"%d items\\n\", n);",
			"do": "Use [b]sizeof[/b] to count an array's items."},
		{"topic": "recipe()", "check": "recipe",
			"say": "[b]recipe(DISH, items)[/b] fills an array with a dish's ingredients and returns how many.",
			"example": "int items[8];\nint n = recipe(HAMBURGER, items);\nprintf(\"%d ingredients\\n\", n);",
			"do": "Call [b]recipe()[/b] to fill an array."},
		{"topic": "2D arrays", "check": "array2d",
			"say": "A [b]2D array[/b] has rows and columns: [b]grid[row][col][/b].",
			"example": "int menu[2][2] = {{EGGSILOG, HOTSILOG}, {TOCILOG, HAMBURGER}};\nprintf(\"%s\\n\", menu[1][0]);",
			"do": "Make a [b]2D array[/b] and read one cell."},
	],
	5: [
		{"topic": "Your own function", "check": "func",
			"say": "Write steps once in a [b]function[/b], then call it by name from main().",
			"example": "void greet() {\n    printf(\"Welcome!\\n\");\n}\n\nvoid main() {\n    greet();\n}",
			"do": "Write a function and call it from [b]main()[/b]."},
		{"topic": "Parameters", "check": "params",
			"say": "[b]Parameters[/b] let a function work on different values: [b]void cook_one(int item)[/b].",
			"example": "void cook_one(int item) {\n    go_to(FRIDGE);\n    pick_up(item);\n}\n\nvoid main() {\n    cook_one(EGG);\n}",
			"do": "Call your own function with an [b]argument[/b]."},
		{"topic": "Return values", "check": "return",
			"say": "A function can [b]return[/b] a value back to whoever called it.",
			"example": "int price_of(int dish) {\n    if (dish == EGGSILOG) {\n        return 30;\n    }\n    return 40;\n}\n\nvoid main() {\n    printf(\"%d\\n\", price_of(EGGSILOG));\n}",
			"do": "Call a function that uses [b]return[/b] to give back a value."},
		{"topic": "Your Library", "check": "library",
			"say": "Functions saved in your [b]Library (L)[/b] (with [b]Use[/b] ticked) can be called by every staff member.",
			"example": "void main() {\n    fetch_and_cook(EGG);   // lives in a Library slot\n}",
			"do": "Call a function from your [b]Library[/b] in a staff program."},
	],
}


static func for_level(level: int) -> Array:
	return QUESTS.get(level, [])


static func _n(trace: Dictionary, key: String) -> int:
	return int(trace.get("stats", {}).get(key, 0))


## Does this run trace (staff.gd run_trace) complete the quest check?
static func met(check: String, trace: Dictionary) -> bool:
	var printfs: Array = trace.get("printfs", [])
	match check:
		"printf":
			# Friendly twist: the line must include the player's name.
			var all := ""
			for p in printfs:
				all += String(p.get("text", ""))
			return all.to_lower().contains(_player_name().to_lower())
		"kitchen":
			return _n(trace, "fn:go_to") + _n(trace, "fn:move_to") >= 1 and _n(trace, "fn:pick_up") >= 1 and _n(trace, "fn:cook") >= 1
		"int", "float", "char":
			for p in printfs:
				for it in p.items:
					if not it.var:
						continue
					if check == "int" and it.conv in ["d", "i"] and it.type == "int":
						return true
					if check == "float" and it.conv == "f" and it.type in ["float", "double"]:
						return true
					if check == "char" and it.conv == "c" and it.type == "char":
						return true
			return false
		"math":
			return _n(trace, "math") >= 1 and not printfs.is_empty()
		"incdec":
			return _n(trace, "incdec") + _n(trace, "compound") >= 1 and not printfs.is_empty()
		"compare":
			return _n(trace, "compare") >= 1
		"if":
			return _n(trace, "if") >= 1
		"else":
			return _n(trace, "if_else") >= 1
		"elseif":
			return _n(trace, "else_if") >= 1
		"logic":
			return _n(trace, "logic") >= 1
		"switch":
			return _n(trace, "switch") >= 1 and _n(trace, "switch_default") >= 1
		"while":
			return _n(trace, "while") >= 1
		"do_while":
			return _n(trace, "do_while") >= 1
		"for":
			return _n(trace, "for") >= 1
		"nested":
			return _n(trace, "nested") >= 1
		"break_continue":
			return _n(trace, "break") + _n(trace, "continue") >= 1
		"array":
			return _n(trace, "array") >= 1 and _n(trace, "index") >= 1
		"array_loop":
			return _n(trace, "array") >= 1 and _n(trace, "for") >= 2 and _n(trace, "index") >= 2
		"sizeof":
			return _n(trace, "sizeof") >= 1
		"recipe":
			return _n(trace, "fn:recipe") >= 1
		"array2d":
			return _n(trace, "array2d") >= 1 and _n(trace, "index") >= 1
		"func":
			return _n(trace, "user_call") >= 1
		"params":
			return _n(trace, "user_call_args") >= 1
		"return":
			return _n(trace, "user_return") >= 1
		"library":
			return _n(trace, "library_call") >= 1
	return false



static func _player_name() -> String:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	var n: String = gs.manager_name if gs else "Manager"
	return n if n.strip_edges() != "" else "Manager"


## Beginner-friendly feedback after a Run that didn't finish the quest yet:
## what is still missing, in plain words.
static func why_not(check: String, trace: Dictionary) -> String:
	var printfs: Array = trace.get("printfs", [])
	match check:
		"printf":
			if printfs.is_empty():
				return "I didn't see any printf run. Write it inside main() { } and end the line with ;"
			return "Nice printf! Now put your name in the text, like printf(\"Hi, %s!\\n\");" % _player_name()
		"kitchen":
			var miss: Array = []
			if _n(trace, "fn:go_to") + _n(trace, "fn:move_to") == 0:
				miss.append("go_to(FRIDGE);")
			if _n(trace, "fn:pick_up") == 0:
				miss.append("pick_up(RICE);")
			if _n(trace, "fn:cook") == 0:
				miss.append("go_to(RICE_COOKER); cook();")
			return "Almost! Still missing: " + "  ".join(miss)
		"int", "float", "char":
			var spec: String = {"int": "%d", "float": "%.2f", "char": "%c"}[check]
			if printfs.is_empty():
				return "Make the variable, then print it with printf and %s." % spec
			return "Put the VARIABLE after the quotes, like printf(\"%s\\n\", myVariable); (a %s variable with %s)." % [spec, check, spec]
		"math":
			return "Calculate with + - * / or %% (like 30 * 2), and printf the result."
		"incdec":
			return "Change a variable with ++, -- or += (like served++;), then printf it."
		"compare":
			return "Compare two values with == != < > <= or >= (like eggs > 2)."
		"if":
			return "Write if (condition) { ... } and press Run."
		"else":
			return "Add an else { ... } right after your if block."
		"elseif":
			return "Between if and else, add: else if (another condition) { ... }"
		"logic":
			return "Join two conditions with && (and) or || (or) inside an if."
		"switch":
			if _n(trace, "switch") > 0:
				return "Good switch! Add a default: label too."
			return "Write switch (value) { case ...: ... break; default: ... }"
		"while":
			return "Write while (condition) { ... } and make sure the condition is true at the start."
		"do_while":
			return "Write do { ... } while (condition);  (note the ; at the end)"
		"for":
			return "Write for (int i = 0; i < 3; i++) { ... }"
		"nested":
			return "Put a second loop INSIDE the { } of your first loop."
		"break_continue":
			return "Inside a loop, use break; to stop it (or continue; to skip a round)."
		"array":
			return "Make an array like int a[] = {1, 2, 3}; and read one item with a[0]."
		"array_loop":
			return "Use a for loop and read list[i] inside it."
		"sizeof":
			return "Use sizeof(list) / sizeof(list[0]) to count the items."
		"recipe":
			return "Call recipe(DISH, items) with an int array, like int items[8];"
		"array2d":
			return "Make a 2D array like int g[2][2] and read g[1][0]."
		"func":
			return "Write a function above main() and CALL it inside main(), like greet();"
		"params":
			return "Give your function a parameter (int item) and call it with a value: cook_one(EGG);"
		"return":
			return "Make a function that ends with return value; and call it."
		"library":
			return "Tick Use on a Library slot (L) and call its function in main()."
	return "Not quite yet: check the example in your Quest Log."

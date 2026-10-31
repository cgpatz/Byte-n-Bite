extends Node
## Interpreter tests. Open tests/InterpreterTests.tscn and press F6 (Run Current
## Scene). Results print to the Output panel; the window closes when done.

const CInterpreter := preload("res://systems/c_interpreter/c_interpreter.gd")


## Stand-in for a staff member: records kitchen calls instead of walking.
class FakeHost:
	extends RefCounted
	var staff_name := "Jane"
	var level := 1
	var tree: SceneTree
	var calls: Array = []
	var held := 0

	func get_tree() -> SceneTree:
		return tree

	func restaurant_level() -> int:
		return level

	func run_builtin(name: String, args: Array, _line: int) -> Dictionary:
		calls.append(name + ("(%s)" % ", ".join(args.map(func(a): return str(a))) if args.size() else "()"))
		await tree.process_frame
		match name:
			"pick_up":
				held = args[0]
			"holding":
				return {"value": held}
			"move_to":
				if args[0] == 999:
					return {"error": "There is no such station."}
		return {"value": 0}


var _passed := 0
var _failed := 0


func _ready() -> void:
	await _run_all()
	print("\n==== Interpreter tests: %d passed, %d failed ====" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Runs source; checks printed output (and optionally the error text).
func check(title: String, src: String, want_out: String, want_error := "", level := 1, want_calls := [], library = "") -> void:
	var host := FakeHost.new()
	host.tree = get_tree()
	host.level = level
	var interp := CInterpreter.new()
	interp.host = host
	var out := [""]
	interp.output.connect(func(t): out[0] += t)
	if interp.compile(src, library):
		await interp.run()
	var err: String = interp.error.get("msg", "")
	var ok: bool = out[0] == want_out
	if want_error == "":
		ok = ok and err == ""
	else:
		ok = ok and err.contains(want_error)
	if not want_calls.is_empty():
		ok = ok and host.calls == want_calls
	if ok:
		_passed += 1
		print("PASS  ", title)
	else:
		_failed += 1
		print("FAIL  ", title)
		print("      output: ", JSON.stringify(out[0]), "  wanted: ", JSON.stringify(want_out))
		print("      error:  ", interp.error, "  wanted: ", want_error)
		if not want_calls.is_empty():
			print("      calls:  ", host.calls)


func _run_all() -> void:
	await check("hello", '#include <stdio.h>\nint main() { printf("Hello, kitchen!\\n"); return 0; }', "Hello, kitchen!\n")
	await check("arithmetic + precedence", 'void main(){ int a = 2 + 3 * 4; printf("%d %d %d\\n", a, (2+3)*4, 17 % 5); }', "14 20 2\n")
	await check("int division truncates", 'void main(){ printf("%d %d\\n", 7/2, -7/2); }', "3 -3\n")
	await check("float math", 'void main(){ float price = 2.5; double t = price * 3; printf("%.2f %f\\n", t, 1.0/4); }', "7.50 0.250000\n")
	await check("int var truncates float", 'void main(){ int x = 9.99; printf("%d\\n", x); }', "9\n")
	await check("char and cast", "void main(){ char c = 'A'; c = c + 2; printf(\"%c %d %d\\n\", c, c, (int) 3.7); }", "C 67 3\n")
	await check("compound assign, ++/--", 'void main(){ int n = 5; n += 3; n *= 2; n--; int m = n++; printf("%d %d %d\\n", n, m, ++n); }', "16 15 17\n")
	await check("if / else if / else", 'void main(){ int s = 75; if (s >= 90) printf("A"); else if (s >= 70) printf("B"); else printf("C"); printf("\\n"); }', "B\n")
	await check("logic + ternary", 'void main(){ int a = 3; bool ok = a > 1 && a < 5 || 0; printf("%d %d %d\\n", ok, !ok, a > 2 ? 10 : 20); }', "1 0 10\n")
	await check("while", 'void main(){ int i = 0; while (i < 3) { printf("%d", i); i++; } printf("\\n"); }', "012\n")
	await check("do-while runs once", 'void main(){ int i = 10; do { printf("x"); } while (i < 5); printf("\\n"); }', "x\n")
	await check("for + break/continue", 'void main(){ for (int i = 0; i < 10; i++) { if (i == 5) break; if (i % 2 == 0) continue; printf("%d", i); } printf("\\n"); }', "13\n")
	await check("nested loops", 'void main(){ for (int r = 1; r <= 2; r++) { for (int c = 1; c <= 3; c++) printf("%d", r * c); printf(" "); } }', "123 246 ")
	await check("functions + recursion", 'int fact(int n) { if (n <= 1) return 1; return n * fact(n - 1); }\nvoid greet(void) { printf("hi "); }\nvoid main(){ greet(); printf("%d\\n", fact(5)); }', "hi 120\n")
	await check("prototype then definition", 'int twice(int x);\nvoid main(){ printf("%d\\n", twice(21)); }\nint twice(int x){ return x * 2; }', "42\n")
	await check("globals + scopes", 'int total = 10;\nvoid add(int n){ total += n; }\nvoid main(){ add(5); int total2 = total; { int x = 1; total2 += x; } printf("%d %d\\n", total, total2); }', "15 16\n")
	await check("printf width + %s kitchen name", 'void main(){ printf("[%5d][%-3d][%s]\\n", 42, 7, GRILL); }', "[   42][7  ][GRILL]\n")
	await check("kitchen calls in order", 'void main(){ move_to(FRIDGE); pick_up(RICE); if (holding() == RICE) { move_to(GRILL); cook(); } assemble(EGGSILOG); }', "", "", 1, ["move_to(1)", "pick_up(101)", "holding()", "move_to(4)", "cook()", "assemble(201)"])
	await check("dish names print", 'void main(){ printf("%s %s\\n", EGGSILOG, SIGNATURE_BOWL); }', "EGGSILOG SIGNATURE_BOWL\n")
	# --- Library (shared functions) ---
	await check("library function", 'void main(){ printf("%d\\n", twice(21)); }', "42\n", "", 1, [], "int twice(int x) { return x * 2; }")
	await check("program overrides library", 'int twice(int x){ return 0; }\nvoid main(){ printf("%d\\n", twice(21)); }', "0\n", "", 1, [], "int twice(int x) { return x * 2; }")
	await check("library error is reported", 'void main(){ }', "", "Missing ';'", 1, [], "void a() { int x = 1 }")
	var slots := [{"name": "Math", "code": "int twice(int x) { return x * 2; }", "enabled": true},
		{"name": "Off", "code": "int twice(int x) { return 0; }", "enabled": false},
		{"name": "More", "code": "int thrice(int x) { return x * 3; }", "enabled": true}]
	await check("library slots combine (off slot ignored)", 'void main(){ printf("%d %d\\n", twice(2), thrice(2)); }', "4 6\n", "", 1, [], slots)
	slots[1].enabled = true
	await check("same function in two slots", 'void main(){ }', "", "in two Library slots", 1, [], slots)
	await check("library can't have main", 'void main(){ }', "", "can't have a main()", 1, [], "void main() { }")
	# --- Friendly errors ---
	await check("missing semicolon", 'void main(){ int x = 1\n printf("%d", x); }', "", "Missing ';' at the end of line 1")
	await check("typo suggestion", "void main(){ cok(); }", "", "Did you mean cook()?")
	await check("unknown variable suggestion", "void main(){ int count = 1; printf(\"%d\", cuont); }", "", "Did you mean count?")
	await check("level-locked function", "void main(){ trash(); }", "", "unlocks at Restaurant Level 2 (Small Diner)")
	await check("unlocked at level 2", "void main(){ trash(); }", "", "", 2)
	await check("recipe() fills an array", 'void main(){ int items[8]; int n = recipe(DOUBLE_CHEESEBURGER, items); printf("%d %s %s %s", n, items[0], items[2], items[7]); }', "7 BUN PATTY NOTHING", "", 4)
	await check("recipe() array too small", 'void main(){ int items[2]; recipe(HAMBURGER, items); }', "", "needs 4 ingredients", 4)
	await check("cook_station()", 'void main(){ printf("%s %s", cook_station(CHICKEN), cook_station(LETTUCE)); }', "FRYER NOTHING", "", 4)
	# --- switch ---
	await check("switch picks a case", 'void main(){ int d = 2; switch (d) { case 1: printf("one"); break; case 2: printf("two"); break; default: printf("?"); } printf("\\n"); }', "two\n")
	await check("switch default", 'void main(){ switch (9) { case 1: printf("one"); break; default: printf("other"); } }', "other")
	await check("switch falls through without break", 'void main(){ switch (1) { case 1: printf("a"); case 2: printf("b"); break; case 3: printf("c"); } }', "ab")
	await check("switch on kitchen names", 'void main(){ int o = HOTSILOG; switch (o) { case EGGSILOG: case HOTSILOG: printf("silog"); break; default: printf("no"); } }', "silog")
	await check("switch inside loop: continue", 'void main(){ for (int i = 0; i < 3; i++) { switch (i) { case 1: continue; default: printf("%d", i); } } }', "02")
	await check("case outside switch", "void main(){ case 1: ; }", "", "only works inside a switch")
	await check("case needs colon", "void main(){ switch (1) { case 1 printf(\"x\"); } }", "", "needs a colon")
	await check("wrong arg count", "void main(){ move_to(); }", "", "Write it like: move_to(STATION)")
	await check("pointer rejected", "void main(){ int *p; }", "", "Pointers")
	# --- Arrays (1D and 2D) ---
	await check("array declare + index", 'void main(){ int a[3]; a[0] = 5; a[2] = a[0] * 2; printf("%d %d %d\\n", a[0], a[1], a[2]); }', "5 0 10\n")
	await check("array init list + loop", 'void main(){ int a[] = {3, 1, 4}; int t = 0; for (int i = 0; i < 3; i++) { t += a[i]; } printf("%d\\n", t); }', "8\n")
	await check("partial init fills zeros", 'void main(){ int a[4] = {7}; printf("%d%d%d%d", a[0], a[1], a[2], a[3]); }', "7000")
	await check("array ++ and +=", 'void main(){ int s[2] = {0, 0}; s[1]++; s[1] += 5; ++s[0]; printf("%d %d", s[0], s[1]); }', "1 6")
	await check("sizeof length idiom", 'void main(){ int a[] = {1, 2, 3, 4, 5}; int n = sizeof(a) / sizeof(a[0]); printf("%d %d %d", n, sizeof(int), sizeof(char)); }', "5 4 1")
	await check("2D array", 'void main(){ int g[2][3] = {{1, 2, 3}, {4, 5, 6}}; int t = 0; for (int r = 0; r < 2; r++) { for (int c = 0; c < 3; c++) { t += g[r][c]; } } g[1][2] = 9; printf("%d %d", t, g[1][2]); }', "21 9")
	await check("array of kitchen names", 'void main(){ int r[] = {RICE, EGG}; printf("%s %s", r[0], r[1]); }', "RICE EGG")
	await check("array passed to function", 'int sum(int a[], int n){ int t = 0; for (int i = 0; i < n; i++) t += a[i]; return t; }\nvoid fill(int a[]){ a[0] = 99; }\nvoid main(){ int x[] = {1, 2, 3}; fill(x); printf("%d", sum(x, 3)); }', "104")
	await check("2D row passed as 1D", 'int first(int row[]){ return row[0]; }\nvoid main(){ int g[2][2] = {{1, 2}, {3, 4}}; printf("%d", first(g[1])); }', "3")
	await check("index out of range", 'void main(){ int m[] = {1, 2, 3}; for (int i = 0; i <= 3; i++) { printf("%d", m[i]); } }', "123", "m[3] doesn't exist. m has 3 items, numbered 0 to 2")
	await check("2D row out of range", 'void main(){ int g[2][2]; g[2][0] = 1; }', "", "has rows 0 to 1")
	await check("too many initializers", 'void main(){ int a[2] = {1, 2, 3}; }', "", "has room for 2 items")
	await check("whole array in math", 'void main(){ int a[2]; int b = a + 1; }', "", "whole array")
	await check("index on non-array", 'void main(){ int x = 1; x[0] = 2; }', "", "not an array")
	await check("orders() with an empty counter", "void main(){ int list[5]; int n = orders(list); printf(\"%d %d\", n, list[0] == NOTHING); }", "0 1", "", 4)
	await check("orders() locked before Level 4", "void main(){ int list[5]; orders(list); }", "", "unlocks at Restaurant Level 4", 3)
	await check("post_order() locked at Level 2", "void main(){ post_order(EGGSILOG); }", "", "unlocks at Restaurant Level 3", 2)
	# Level challenges checker (systems/challenges/level_challenges.gd).
	var LG = preload("res://systems/challenges/level_challenges.gd")
	var tr := {"served": 1, "printfs": [{"served_before": 1, "items": [
		{"conv": "d", "type": "int", "var": true, "changed": true},
		{"conv": "f", "type": "float", "var": true, "changed": false},
		{"conv": "c", "type": "char", "var": true, "changed": false}]}]}
	var got: Array = LG.met(1, tr)
	got.sort()
	_report_bool(got == ["count", "price", "receipt", "size"], "challenges: one receipt line meets all four (%s)" % [got])
	tr.printfs[0].served_before = 0
	_report_bool(not "receipt" in LG.met(1, tr), "challenges: receipt only counts after serve()")
	tr.printfs[0].items[0].changed = false
	_report_bool(not "count" in LG.met(1, tr), "challenges: count needs an int that changed")
	tr.served = 0
	_report_bool(LG.met(1, tr).is_empty(), "challenges: nothing counts without serving a dish")
	await check("3D rejected", 'void main(){ int a[2][2][2]; }', "", "1 or 2 dimensions")
	await check("struct rejected", "struct Order { int id; };", "", "'struct' isn't used")
	await check("division by zero", "void main(){ int z = 0; printf(\"%d\", 5 / z); }", "", "Division by zero")
	await check("no main", "int helper(){ return 1; }", "", "needs a main()")
	await check("undeclared assign", "void main(){ x = 5; }", "", "hasn't been declared")
	await check("can't change kitchen name", "void main(){ GRILL = 2; }", "", "can't be changed")
	await check("unclosed block", "void main(){ int a = 1;", "", "never closed")
	await check("builtin error passes through", "void main(){ move_to(999); }", "", "There is no such station.")
	await check("infinite loop detected", "void main(){ int i = 0; while (1) { i++; } }", "", "loop that never ends")
	# Every example in the Recipe Book's Kitchen Functions pages must compile.
	var bad: Array = []
	var codes: Array = []
	for l in preload("res://data/help/lessons.gd").LESSONS:
		for pg in l.pages:
			if pg.code != "":
				codes.append({"id": "%s: %s" % [l.title, pg.title], "example": pg.code})
		codes.append({"id": l.title + " practice", "example": l.practice.code})
	for e in preload("res://data/help/c_reference.gd").entries() + codes:
		var host := FakeHost.new()
		host.tree = get_tree()
		host.level = 5
		var interp := CInterpreter.new()
		interp.host = host
		# Examples may call make_dish() from the Library (Lesson 5).
		if not interp.compile(e.example, preload("res://data/help/code_sets.gd").make_dish()):
			bad.append("%s: %s" % [e.id, interp.error.get("msg", "")])
	if bad.is_empty():
		_passed += 1
		print("PASS  help + lesson examples compile")
	else:
		_failed += 1
		print("FAIL  help examples compile: ", bad)
	# Every admin Code Set must compile at the level it is listed for.
	bad = []
	var sets: Array = preload("res://data/help/code_sets.gd").all_sets()
	for cs in sets:
		var host := FakeHost.new()
		host.tree = get_tree()
		host.level = cs.level
		var interp := CInterpreter.new()
		interp.host = host
		var src: String = cs.code if cs.group != "Library" else cs.code + "\nvoid main() { }"
		var lib: String = preload("res://data/help/code_sets.gd").make_dish() if cs.group == "Level challenges" and cs.level == 5 else ""
		if not interp.compile(src, lib):
			bad.append("%s / %s: %s" % [cs.group, cs.title, interp.error.get("msg", "")])
	if bad.is_empty() and sets.size() > 30:
		_passed += 1
		print("PASS  all %d admin code sets compile" % sets.size())
	else:
		_failed += 1
		print("FAIL  code sets compile: ", bad)
	await check("runaway recursion", "int f(int n){ return f(n + 1); }\nvoid main(){ f(0); }", "", "keep calling itself")


func _report_bool(ok: bool, title: String) -> void:
	if ok:
		_passed += 1
		print("PASS  ", title)
	else:
		_failed += 1
		print("FAIL  ", title)

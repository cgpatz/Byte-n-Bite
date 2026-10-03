extends RefCounted
## Byte n' Bite C interpreter — step 3: runs the syntax tree.
## A tree-walking interpreter that runs as a coroutine (await), so kitchen
## actions like go_to() can take real game time while the code "waits".
##
## Usage:
##   var interp := CInterpreter.new()   # preload("c_interpreter.gd")
##   interp.host = staff                # see HOST below
##   if interp.compile(source): await interp.run()
##   if not interp.error.is_empty(): print(interp.error)   # {"line", "msg"}
##
## HOST must provide:
##   func run_builtin(name: String, args: Array, line: int) -> Dictionary  (may await)
##       returns {"value": v} or {"error": "message"}
##   func get_tree() -> SceneTree
##   func restaurant_level() -> int
##   var staff_name: String

signal output(text: String)
signal line_changed(line: int)

const Lexer := preload("res://systems/c_interpreter/c_lexer.gd")
const Parser := preload("res://systems/c_interpreter/c_parser.gd")
const Builtins := preload("res://systems/c_interpreter/c_builtins.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")

enum Flow { NORMAL, BREAK, CONTINUE, RETURN, ABORT }

## Give the game a frame every this many steps, so long loops don't freeze it.
const YIELD_EVERY := 2000
## Steps allowed without any kitchen action before we call it an endless loop.
const MAX_STEPS_WITHOUT_ACTION := 100000
const MAX_CALL_DEPTH := 200
const MAX_OUTPUT_CHARS := 20000
## Library code lines are numbered from here (line 3 of the Library = 100003).
const LIBRARY_LINE_OFFSET := 100000
## Each Library slot gets its own block of line numbers.
const LIBRARY_SLOT_STRIDE := 10000


## For a reported line: {"slot": index or -1 for the staff program, "line": line in that code}.
static func library_line_info(line: int) -> Dictionary:
	if line < LIBRARY_LINE_OFFSET:
		return {"slot": -1, "line": line}
	var rel := line - LIBRARY_LINE_OFFSET
	return {"slot": floori(rel / float(LIBRARY_SLOT_STRIDE)), "line": rel % LIBRARY_SLOT_STRIDE}

var host: Object
## First problem found: {"line": int, "msg": String}. Empty = fine.
var error := {}
var stopped := false
var running := false

var constants: Dictionary = Kitchen.constants()
var _program := {}
var _functions := {}
var _globals := {}
## Call stack: each frame is an Array of scopes (Dictionary name -> {"type","v"}).
var _frames: Array = []
var _ret_value = 0
var _steps := 0
var _since_yield := 0
var _output_chars := 0
## What this run has used, for level goals (systems/goals/level_goals.gd):
## "if_else", "switch", "switch_default", "loop", "for", "index", "sizeof",
## "array2d", "user_call", "user_call_args", "user_return", "library_call",
## and "fn:<kitchen function>" counts.
var stats := {}
var _library_names := {}


func _tick(key: String, n := 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n


# --- Public -------------------------------------------------------------------------

## Reads and checks the program. Returns false (and sets error) on a mistake.
## `library` = the player's shared functions (the Library): a String, or an Array
## of slots [{"name", "code", "enabled"}]. Lines in slot i are reported as
## LIBRARY_LINE_OFFSET + i * LIBRARY_SLOT_STRIDE + line (see library_line_info()).
func compile(source: String, library = "") -> bool:
	error = {}
	var slots: Array = library if library is Array else [{"name": "Library", "code": str(library), "enabled": true}]
	var lib := {"globals": [], "functions": {}}
	var owner := {}  # function name -> slot name
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if not slot.get("enabled", true) or str(slot.get("code", "")).strip_edges() == "":
			continue
		var part := _parse(slot.code, LIBRARY_LINE_OFFSET + i * LIBRARY_SLOT_STRIDE)
		if not error.is_empty():
			return false
		if part.functions.has("main"):
			_fail("The Library can't have a main() function. Put main() in the staff program.", part.functions.main.line)
			return false
		for fname in part.functions:
			if lib.functions.has(fname):
				_fail("%s() is in two Library slots (\"%s\" and \"%s\"). Rename one, or switch one slot off." % [fname, owner[fname], slot.get("name", "")], part.functions[fname].line)
				return false
			lib.functions[fname] = part.functions[fname]
			owner[fname] = slot.get("name", "")
		lib.globals.append_array(part.globals)
	_program = _parse(source, 0)
	if not error.is_empty():
		return false
	# Library functions first; a staff program may replace one with its own version.
	_library_names = {}
	for fname in lib.functions:
		if not _program.functions.has(fname):
			_library_names[fname] = true
	var merged: Dictionary = lib.functions.duplicate()
	merged.merge(_program.functions, true)
	_program.functions = merged
	_program.globals = lib.globals + _program.globals
	_functions = _program.functions
	if not _functions.has("main"):
		_fail("Every program needs a main() function, like:  void main() { ... }", 1)
		return false
	for fname in _functions:
		if Builtins.FUNCS.has(fname) or fname in Builtins.C_FUNCS:
			_fail("%s() is already a kitchen function. Pick another name." % fname, _functions[fname].line)
			return false
	return true


## Checks Library code on its own (for the Library screen). Returns {} or {"line", "msg"}.
func check_library(library: String) -> Dictionary:
	error = {}
	var lib := _parse(library, 0)
	if error.is_empty() and lib.functions.has("main"):
		_fail("The Library can't have a main() function. Put main() in the staff program.", lib.functions.main.line)
	if error.is_empty():
		for fname in lib.functions:
			if Builtins.FUNCS.has(fname) or fname in Builtins.C_FUNCS:
				_fail("%s() is already a kitchen function. Pick another name." % fname, lib.functions[fname].line)
				break
	return error


func _parse(source: String, line_offset: int) -> Dictionary:
	var lexer := Lexer.new()
	var tokens := lexer.tokenize(source)
	if not lexer.errors.is_empty():
		error = lexer.errors[0].duplicate()
		error.line += line_offset
		return {"globals": [], "functions": {}}
	if line_offset != 0:
		for t in tokens:
			t.line += line_offset
	var parser := Parser.new()
	var result := parser.parse(tokens)
	if not parser.error.is_empty():
		error = parser.error
		return {"globals": [], "functions": {}}
	return result


## Runs main(). Await it. Returns true when the program finished without errors.
func run() -> bool:
	error = {}
	stats.clear()
	stopped = false
	running = true
	_globals = {}
	_frames = []
	_steps = 0
	_since_yield = 0
	_output_chars = 0
	for d in _program.globals:
		await _exec(d)
		if _halted():
			break
	if not _halted():
		await _call_user("main", [], _functions.main.line)
	running = false
	return error.is_empty() and not stopped


## Asks the running program to stop at the next step.
func stop() -> void:
	stopped = true


# --- Helpers ------------------------------------------------------------------------

func _halted() -> bool:
	return stopped or not error.is_empty()


func _fail(msg: String, line: int) -> void:
	if error.is_empty():
		error = {"line": line, "msg": msg}


func _who() -> String:
	return host.staff_name if host and "staff_name" in host else "The staff member"


func _level() -> int:
	return host.restaurant_level() if host and host.has_method("restaurant_level") else 1


## Called once per statement: highlights the line, counts steps, yields a frame now and then.
func _step(line: int) -> void:
	line_changed.emit(line)
	_steps += 1
	_since_yield += 1
	if _steps > MAX_STEPS_WITHOUT_ACTION:
		_fail("%s has been running code for a long time without doing any kitchen work. Is there a loop that never ends?" % _who(), line)
		return
	if _since_yield >= YIELD_EVERY:
		_since_yield = 0
		if host:
			await host.get_tree().process_frame


func _coerce(type: String, v):
	if v is String:
		return v
	match type:
		"int":
			return int(v)
		"char":
			return int(v) & 0xFF if int(v) >= 0 else int(v)
		"bool":
			return 1 if v != 0 else 0
		"float":
			return float(v)
	return v


func _truthy(v) -> bool:
	if v is String:
		return true
	return v != 0


func _scope_with(name: String) -> Variant:
	if not _frames.is_empty():
		var frame: Array = _frames[-1]
		for i in range(frame.size() - 1, -1, -1):
			if frame[i].has(name):
				return frame[i]
	if _globals.has(name):
		return _globals
	return null


func _all_names() -> Array:
	var names: Array = constants.keys() + _functions.keys() + Builtins.FUNCS.keys() + Builtins.C_FUNCS
	names.append_array(_globals.keys())
	if not _frames.is_empty():
		for s in _frames[-1]:
			names.append_array(s.keys())
	return names


## Closest known name to a misspelled one, or "".
func _suggest(name: String, pool: Array) -> String:
	var best := ""
	var best_d := 99
	for cand in pool:
		var d := _distance(name.to_lower(), String(cand).to_lower())
		if d < best_d:
			best_d = d
			best = cand
	var limit := 1 if name.length() <= 3 else (2 if name.length() <= 6 else 3)
	return best if best_d <= limit else ""


static func _distance(a: String, b: String) -> int:
	var prev: Array = range(b.length() + 1)
	for i in a.length():
		var cur: Array = [i + 1]
		for j in b.length():
			var cost := 0 if a[i] == b[j] else 1
			cur.append(mini(mini(cur[j] + 1, prev[j + 1] + 1), prev[j] + cost))
		prev = cur
	return prev[b.length()]


# --- Statements ------------------------------------------------------------------------

func _exec(n: Dictionary) -> int:
	if _halted():
		return Flow.ABORT
	match n.k:
		"block":
			_frames[-1].append({})
			var flow := Flow.NORMAL
			for s in n.body:
				flow = await _exec(s)
				if flow != Flow.NORMAL:
					break
			_frames[-1].pop_back()
			return flow
		"empty":
			return Flow.NORMAL
		"decl":
			await _step(n.line)
			var scope: Dictionary = _globals if _frames.is_empty() else _frames[-1][-1]
			for v in n.vars:
				if scope.has(v.name):
					_fail("'%s' is already declared here. Remove the type to change it: %s = ...;" % [v.name, v.name], n.line)
					return Flow.ABORT
				if constants.has(v.name):
					_fail("'%s' is a kitchen name. Pick a different variable name." % v.name, n.line)
					return Flow.ABORT
				if not v.get("dims", []).is_empty():
					var arr = await _make_array(n.type, v, n.line)
					if _halted():
						return Flow.ABORT
					scope[v.name] = {"type": n.type, "v": arr}
					continue
				var value = 0
				if v.init != null:
					value = await _eval(v.init)
					if _halted():
						return Flow.ABORT
					if value is String:
						_fail("Text in quotes can't be stored in a %s. Use printf to show text." % n.type, n.line)
						return Flow.ABORT
					if value is Array:
						_fail("%s is a single %s, so it can't hold a whole array. Use one item, like list[0]." % [v.name, n.type], n.line)
						return Flow.ABORT
				scope[v.name] = {"type": n.type, "v": _coerce(n.type, value)}
			return Flow.NORMAL
		"expr":
			await _step(n.line)
			await _eval(n.e)
			return Flow.ABORT if _halted() else Flow.NORMAL
		"if":
			await _step(n.line)
			var c = await _eval(n.cond)
			if _halted():
				return Flow.ABORT
			if n.else_s != null:
				_tick("if_else")
			if _truthy(c):
				return await _exec(n.then_s)
			elif n.else_s != null:
				return await _exec(n.else_s)
			return Flow.NORMAL
		"while":
			while true:
				await _step(n.line)
				var c = await _eval(n.cond)
				if _halted():
					return Flow.ABORT
				if not _truthy(c):
					break
				_tick("loop")
				var flow: int = await _exec(n.body)
				if flow == Flow.BREAK:
					break
				if flow == Flow.RETURN or flow == Flow.ABORT:
					return flow
			return Flow.NORMAL
		"do":
			while true:
				_tick("loop")
				var flow: int = await _exec(n.body)
				if flow == Flow.BREAK:
					break
				if flow == Flow.RETURN or flow == Flow.ABORT:
					return flow
				await _step(n.line)
				var c = await _eval(n.cond)
				if _halted():
					return Flow.ABORT
				if not _truthy(c):
					break
			return Flow.NORMAL
		"for":
			_frames[-1].append({})
			var result := Flow.NORMAL
			if n.init != null:
				await _exec(n.init)
			while not _halted():
				await _step(n.line)
				if n.cond != null:
					var c = await _eval(n.cond)
					if _halted() or not _truthy(c):
						break
				_tick("loop")
				_tick("for")
				var flow: int = await _exec(n.body)
				if flow == Flow.BREAK:
					break
				if flow == Flow.RETURN or flow == Flow.ABORT:
					result = flow
					break
				if n.step != null:
					await _eval(n.step)
			_frames[-1].pop_back()
			return Flow.ABORT if _halted() else result
		"return":
			await _step(n.line)
			_ret_value = 0
			if n.value != null:
				_ret_value = await _eval(n.value)
			return Flow.ABORT if _halted() else Flow.RETURN
		"switch":
			await _step(n.line)
			var v = await _eval(n.value)
			if _halted():
				return Flow.ABORT
			_tick("switch")
			if n.default >= 0:
				_tick("switch_default")
			var start: int = n.default
			for c in n.cases:
				var cv = await _eval(c.value)
				if _halted():
					return Flow.ABORT
				if cv == v or (cv is float or v is float) and float(cv) == float(v):
					start = c.at
					break
			if start < 0:
				return Flow.NORMAL
			_frames[-1].append({})
			var result := Flow.NORMAL
			# Runs from the matching case down ("falls through") until a break.
			for i in range(start, n.body.size()):
				var flow: int = await _exec(n.body[i])
				if flow == Flow.BREAK:
					break
				if flow != Flow.NORMAL:
					result = flow
					break
			_frames[-1].pop_back()
			return result
		"break":
			return Flow.BREAK
		"continue":
			return Flow.CONTINUE
	_fail("Internal: unknown statement '%s'." % n.k, n.get("line", 0))
	return Flow.ABORT


# --- Expressions ---------------------------------------------------------------------

func _eval(n: Dictionary):
	if _halted():
		return 0
	match n.k:
		"num":
			return n.v
		"str":
			return n.v
		"var":
			var scope = _scope_with(n.name)
			if scope != null:
				return scope[n.name].v
			if constants.has(n.name):
				return constants[n.name]
			if _functions.has(n.name) or Builtins.FUNCS.has(n.name):
				_fail("%s is a function. Call it with brackets: %s()" % [n.name, n.name], n.line)
				return 0
			_unknown_name(n.name, n.line)
			return 0
		"assign":
			var scope = _scope_with(n.name)
			if scope == null:
				if constants.has(n.name):
					_fail("%s is a kitchen name and can't be changed." % n.name, n.line)
				else:
					_fail("'%s' hasn't been declared. Add a line like  int %s = 0;  first." % [n.name, n.name], n.line)
				return 0
			var value = await _eval(n.value)
			if _halted():
				return 0
			if value is String:
				_fail("Text in quotes can't be stored in a variable. Use printf to show text.", n.line)
				return 0
			var cell: Dictionary = scope[n.name]
			if cell.v is Array:
				_fail("%s is an array, so it can't be set with %s all at once. Set one item at a time, like %s[0] = ...;" % [n.name, n.op, n.name], n.line)
				return 0
			if value is Array:
				_fail("%s holds one value, not a whole array. Use one item, like list[0]." % n.name, n.line)
				return 0
			if n.op != "=":
				value = _binop(n.op.substr(0, 1), cell.v, value, n.line)
				if _halted():
					return 0
			cell.v = _coerce(cell.type, value)
			cell.changed = true
			return cell.v
		"incdec":
			var scope = _scope_with(n.name)
			if scope == null:
				_fail("'%s' hasn't been declared yet." % n.name, n.line)
				return 0
			var cell: Dictionary = scope[n.name]
			if cell.v is Array:
				_fail("%s is an array. Use %s on one item, like %s[0]%s" % [n.name, n.op, n.name, n.op], n.line)
				return 0
			var old = cell.v
			cell.v = _coerce(cell.type, old + (1 if n.op == "++" else -1))
			cell.changed = true
			return cell.v if n.prefix else old
		"un":
			var a = await _eval(n.a)
			if a is String:
				_fail("Text can't be used with '%s'." % n.op, n.line)
				return 0
			match n.op:
				"-":
					return -a
				"!":
					return 0 if _truthy(a) else 1
			return a
		"bin":
			var a = await _eval(n.a)
			if _halted():
				return 0
			if n.op == "&&":
				if not _truthy(a):
					return 0
				var b = await _eval(n.b)
				return 1 if _truthy(b) else 0
			if n.op == "||":
				if _truthy(a):
					return 1
				var b = await _eval(n.b)
				return 1 if _truthy(b) else 0
			var b = await _eval(n.b)
			if _halted():
				return 0
			return _binop(n.op, a, b, n.line)
		"ternary":
			var c = await _eval(n.cond)
			if _truthy(c):
				return await _eval(n.a)
			return await _eval(n.b)
		"cast":
			var a = await _eval(n.a)
			if a is String:
				_fail("Text can't be cast to %s." % n.type, n.line)
				return 0
			return _coerce(n.type, a)
		"call":
			return await _call(n)
		"index":
			var ref = await _index_ref(n)
			if ref.is_empty():
				return 0
			_tick("index")
			return ref.arr[ref.i]
		"assign_index":
			var ref = await _index_ref(n.target)
			if ref.is_empty():
				return 0
			var value = await _eval(n.value)
			if _halted():
				return 0
			if value is String or value is Array:
				_fail("%s holds single %s values. Put one number in it, like %s = 5;" % [ref.label, ref.type, ref.label], n.line)
				return 0
			if ref.arr[ref.i] is Array:
				_fail("%s is a whole row of a 2D array. Add a second [ ], like %s[0] = ...;" % [ref.label, ref.label], n.line)
				return 0
			if n.op != "=":
				value = _binop(n.op.substr(0, 1), ref.arr[ref.i], value, n.line)
				if _halted():
					return 0
			ref.arr[ref.i] = _coerce(ref.type, value)
			return ref.arr[ref.i]
		"incdec_index":
			var ref = await _index_ref(n.target)
			if ref.is_empty():
				return 0
			var old = ref.arr[ref.i]
			if old is Array:
				_fail("%s is a whole row. Add a second [ ] to pick one item." % ref.label, n.line)
				return 0
			ref.arr[ref.i] = _coerce(ref.type, old + (1 if n.op == "++" else -1))
			return ref.arr[ref.i] if n.prefix else old
		"sizeof":
			_tick("sizeof")
			if n.has("type"):
				return SIZES.get(n.type, 4)
			var target: Dictionary = n.e
			var v = await _eval(target)
			if _halted():
				return 0
			var t := _root_type(target)
			return _count_items(v) * SIZES.get(t, 4)
		"list":
			_fail("A { } list can only be used when creating an array.", n.line)
			return 0
	_fail("Internal: unknown expression '%s'." % n.get("k", "?"), n.get("line", 0))
	return 0


# --- Arrays ---------------------------------------------------------------------------

const MAX_ARRAY := 200
const SIZES := {"int": 4, "float": 4, "double": 8, "char": 1, "bool": 1, "long": 8, "short": 2}


## Builds a new array (nested for 2D) for a declaration like int a[2][3] = {...};
func _make_array(type: String, v: Dictionary, line: int):
	_tick("array2d" if v.dims.size() == 2 else "array")
	var dims: Array = []
	for d in v.dims:
		if d == null:
			dims.append(-1)
			continue
		var size = await _eval(d)
		if _halted():
			return []
		if size is String or size is Array or int(size) != size:
			_fail("The size of %s must be a whole number, like %s[3]." % [v.name, v.name], line)
			return []
		if int(size) <= 0:
			_fail("%s needs a size of at least 1, but got %d." % [v.name, int(size)], line)
			return []
		dims.append(int(size))
	var init = v.init
	if dims[0] == -1:
		dims[0] = init.items.size()
		if dims[0] == 0:
			_fail("%s[] = { } is empty. Put at least one value in the list." % v.name, line)
			return []
	var total := 1
	for d in dims:
		total *= d
	if total > MAX_ARRAY:
		_fail("%s is too big (%d items). Arrays in the kitchen hold up to %d items." % [v.name, total, MAX_ARRAY], line)
		return []
	var zero = 0.0 if type == "float" else 0
	var arr: Array = []
	for i in dims[0]:
		if dims.size() == 2:
			var row: Array = []
			row.resize(dims[1])
			row.fill(zero)
			arr.append(row)
		else:
			arr.append(zero)
	if init == null:
		return arr
	if init.items.size() > dims[0]:
		_fail("%s has room for %d %s but the list has %d." % [v.name, dims[0], "rows" if dims.size() == 2 else "items", init.items.size()], line)
		return []
	for i in init.items.size():
		var item: Dictionary = init.items[i]
		if dims.size() == 2:
			if item.k != "list":
				_fail("Each row of %s needs its own { }, like { {1, 2}, {3, 4} }." % v.name, line)
				return []
			if item.items.size() > dims[1]:
				_fail("Row %d of %s has room for %d items but the list has %d." % [i, v.name, dims[1], item.items.size()], line)
				return []
			for j in item.items.size():
				var val = await _eval(item.items[j])
				if _halted() or not _check_item(val, v.name, line):
					return []
				arr[i][j] = _coerce(type, val)
		else:
			if item.k == "list":
				_fail("%s is a 1D array, so its list can't contain another { } list." % v.name, line)
				return []
			var val = await _eval(item)
			if _halted() or not _check_item(val, v.name, line):
				return []
			arr[i] = _coerce(type, val)
	return arr


func _check_item(val, name: String, line: int) -> bool:
	if val is String or val is Array:
		_fail("%s can only hold numbers and kitchen names, not text or arrays." % name, line)
		return false
	return true


## Finds the array cell for a[i] or a[i][j]: {arr, i, type, label}, or {} on error.
func _index_ref(n: Dictionary) -> Dictionary:
	var base = null
	var label := ""
	var root := _root_name(n)
	var scope = _scope_with(root)
	if scope == null:
		if constants.has(root):
			_fail("%s is a kitchen name, not an array, so it can't use [ ]." % root, n.line)
		else:
			_unknown_name(root, n.line)
		return {}
	var cell: Dictionary = scope[root]
	if not (cell.v is Array):
		_fail("%s is a single %s, not an array, so it can't use [ ]." % [root, cell.type], n.line)
		return {}
	var depth := 0
	if n.base.k == "index":
		var outer := await _index_ref(n.base)
		if outer.is_empty():
			return {}
		base = outer.arr[outer.i]
		label = outer.label
		depth = 1
		if not (base is Array):
			_fail("%s is a 1D array, so it takes one [ ], not two." % root, n.line)
			return {}
	else:
		base = cell.v
		label = root
	var idx = await _eval(n.index)
	if _halted():
		return {}
	if idx is String or idx is Array or (idx is float and idx != floor(idx)):
		_fail("The number inside [ ] must be a whole number, like %s[0]." % root, n.line)
		return {}
	var i := int(idx)
	if i < 0 or i >= base.size():
		var what := "item"
		if depth == 0 and base.size() > 0 and base[0] is Array:
			what = "row"
		elif depth == 1:
			what = "column"
		if base.size() == 1:
			_fail("%s[%d] doesn't exist. %s has only %s 0." % [label, i, label if depth == 0 else "This row", what], n.line)
		elif what == "item":
			_fail("%s[%d] doesn't exist. %s has %d items, numbered 0 to %d. Check your loop: did you mean < %d instead of <= ?" % [label, i, label, base.size(), base.size() - 1, base.size()], n.line)
		else:
			_fail("%s[%d] doesn't exist: %s has %ss 0 to %d. Check the loop that counts the %ss." % [label, i, root, what, base.size() - 1, what], n.line)
		return {}
	return {"arr": base, "i": i, "type": cell.type, "label": "%s[%d]" % [label, i]}


## recipe(DISH, items): fills items with the dish's ingredients (one entry per
## piece, e.g. PATTY twice for a Double Cheeseburger) and returns how many.
func _builtin_recipe(args: Array, line: int) -> int:
	var dish = args[0]
	if dish is Array or dish is String or not Kitchen.is_dish(int(dish)):
		var nm := Kitchen.name_of(int(dish)) if not (dish is Array or dish is String) else ""
		_fail("recipe() needs a dish like EGSILOG first, but got %s." % (nm if nm != "" else str(dish)), line)
		return 0
	var arr = args[1]
	if not (arr is Array):
		_fail("recipe() needs an array second, like:  int items[8];  recipe(EGSILOG, items);", line)
		return 0
	if arr.size() > 0 and arr[0] is Array:
		_fail("recipe() fills a 1D array. Pass one row, like grid[0], or use int items[8];", line)
		return 0
	var dname := Kitchen.name_of(int(dish))
	var list: Array = []
	var r: Dictionary = Kitchen.DISHES[dname].recipe
	for ing in r:
		for k in r[ing]:
			list.append(Kitchen.id_of(ing))
	if list.size() > arr.size():
		_fail("The array has room for %d items, but %s needs %d ingredients. Make it bigger, like int items[8];" % [arr.size(), dname, list.size()], line)
		return 0
	for i in list.size():
		arr[i] = list[i]
	for i in range(list.size(), arr.size()):
		arr[i] = Kitchen.NOTHING
	return list.size()


## orders(list): copies the dishes on the counter's tickets (oldest first) into
## list, fills the rest with NOTHING, and returns how many it copied.
func _builtin_orders(args: Array, line: int) -> int:
	var arr = args[0]
	if not (arr is Array):
		_fail("orders() needs an array, like:  int list[10];  int n = orders(list);", line)
		return 0
	if arr.size() > 0 and arr[0] is Array:
		_fail("orders() fills a 1D array, like int list[10];", line)
		return 0
	var tickets: Array = host.counter_tickets() if host != null and host.has_method("counter_tickets") else []
	var n := mini(tickets.size(), arr.size())
	for i in n:
		arr[i] = Kitchen.id_of(tickets[i])
	for i in range(n, arr.size()):
		arr[i] = Kitchen.NOTHING
	return n


## cook_station(INGREDIENT): the station that cooks it here, or NOTHING if fresh.
func _builtin_cook_station(args: Array, line: int) -> int:
	var v = args[0]
	if v is Array or v is String or not Kitchen.is_item(int(v)):
		_fail("cook_station() needs an ingredient like EGG.", line)
		return 0
	var ing := Kitchen.name_of(int(v))
	if not ing in Kitchen.NEEDS_COOKING:
		return Kitchen.NOTHING
	if host != null and host.has_method("cook_station_for"):
		return host.cook_station_for(ing)
	var st: Array = Kitchen.cook_stations(ing)
	return Kitchen.id_of(st[0]) if not st.is_empty() else Kitchen.NOTHING


func _root_name(n: Dictionary) -> String:
	while n.k == "index":
		n = n.base
	return n.get("name", "")


func _root_type(n: Dictionary) -> String:
	var root := _root_name(n) if n.k == "index" or n.k == "var" else ""
	var scope = _scope_with(root) if root != "" else null
	return scope[root].type if scope != null else "int"


func _count_items(v) -> int:
	if v is Array:
		var c := 0
		for x in v:
			c += _count_items(x)
		return c
	return 1


func _unknown_name(name: String, line: int) -> void:
	var s := _suggest(name, _all_names())
	var msg := "%s doesn't know what '%s' is." % [_who(), name]
	if s != "":
		msg += " Did you mean %s?" % s
	else:
		msg += " Declare it first, like  int %s = 0;" % name
	_fail(msg, line)


func _binop(op: String, a, b, line: int):
	if a is Array or b is Array:
		_fail("A whole array can't be used with '%s'. Use one item, like list[0] %s 1." % [op, op], line)
		return 0
	if a is String or b is String:
		_fail("Text in quotes can't be used with '%s'." % op, line)
		return 0
	var is_float: bool = a is float or b is float
	match op:
		"+":
			return a + b
		"-":
			return a - b
		"*":
			return a * b
		"/":
			if b == 0:
				_fail("Division by zero! You can't divide by 0.", line)
				return 0
			if is_float:
				return float(a) / float(b)
			return a / b  # int division truncates, like C
		"%":
			if is_float:
				_fail("'%' only works with whole numbers (int), not float.", line)
				return 0
			if b == 0:
				_fail("Modulo by zero! You can't use % 0.", line)
				return 0
			return a % b
		"==":
			return 1 if a == b else 0
		"!=":
			return 1 if a != b else 0
		"<":
			return 1 if a < b else 0
		"<=":
			return 1 if a <= b else 0
		">":
			return 1 if a > b else 0
		">=":
			return 1 if a >= b else 0
	_fail("Unknown operator '%s'." % op, line)
	return 0


# --- Calls ------------------------------------------------------------------------------

func _call(n: Dictionary):
	var name: String = n.name
	if name == "printf":
		return await _printf(n)
	var args: Array = []
	for a in n.args:
		var v = await _eval(a)
		if _halted():
			return 0
		args.append(v)
	if _functions.has(name):
		return await _call_user(name, args, n.line)
	if Builtins.FUNCS.has(name):
		return await _call_builtin(name, args, n.line)
	if _scope_with(name) != null or constants.has(name):
		_fail("'%s' is not a function, so it can't be called with ()." % name, n.line)
		return 0
	var pool: Array = _functions.keys() + Builtins.unlocked(_level()) + Builtins.C_FUNCS
	var s := _suggest(name, pool)
	if s == "":
		s = _suggest(name, Builtins.FUNCS.keys())
	var msg := "%s doesn't know how to %s()." % [_who(), name]
	if s != "":
		msg += " Did you mean %s()?" % s
	_fail(msg, n.line)
	return 0


func _call_user(name: String, args: Array, line: int):
	var fn: Dictionary = _functions[name]
	if name != "main":
		_tick("user_call")
		if not fn.params.is_empty():
			_tick("user_call_args")
		if fn.ret != "void":
			_tick("user_return")
		if _library_names.has(name):
			_tick("library_call")
	if args.size() != fn.params.size():
		_fail("%s() needs %d value(s) but got %d." % [name, fn.params.size(), args.size()], line)
		return 0
	if _frames.size() >= MAX_CALL_DEPTH:
		_fail("Too many calls inside calls. Does %s() keep calling itself forever?" % name, line)
		return 0
	var scope := {}
	for i in args.size():
		var p: Dictionary = fn.params[i]
		if args[i] is String:
			_fail("Text in quotes can't be passed to %s()." % name, line)
			return 0
		var want := int(p.get("array", 0))
		if want > 0:
			if not (args[i] is Array):
				_fail("%s() needs an array for %s, like %s(my_list). Pass the array's name without [ ]." % [name, p.name, name], line)
				return 0
			var is_2d: bool = args[i].size() > 0 and args[i][0] is Array
			if want == 2 and not is_2d:
				_fail("%s() needs a 2D array for %s[][]." % [name, p.name], line)
				return 0
			if want == 1 and is_2d:
				_fail("%s() needs a 1D array for %s[], but got a 2D array. Pass one row, like grid[0]." % [name, p.name], line)
				return 0
			scope[p.name] = {"type": p.type, "v": args[i]}  # shared, like C arrays
			continue
		if args[i] is Array:
			_fail("%s() expects one value for %s, but got a whole array. Pass one item, like list[0], or declare the parameter as %s %s[]." % [name, p.name, p.type, p.name], line)
			return 0
		scope[p.name] = {"type": p.type, "v": _coerce(p.type, args[i])}
	_frames.append([scope])
	_ret_value = 0
	var flow: int = await _exec(fn.body)
	_frames.pop_back()
	if flow == Flow.ABORT:
		return 0
	var r = _ret_value if flow == Flow.RETURN else 0
	_ret_value = 0
	if fn.ret == "void":
		return 0
	return _coerce(fn.ret, r)


func _call_builtin(name: String, args: Array, line: int):
	var info: Dictionary = Builtins.FUNCS[name]
	if info.level > _level():
		_fail("%s() unlocks at Restaurant Level %d (%s)." % [name, info.level, Builtins.level_name(info.level)], line)
		return 0
	if args.size() != info.args:
		_fail("%s needs %d value(s) in the brackets, but got %d. Write it like: %s" % [name + "()", info.args, args.size(), info.sig], line)
		return 0
	_tick("fn:" + name)
	if name == "recipe":
		return _builtin_recipe(args, line)
	if name == "cook_station":
		return _builtin_cook_station(args, line)
	if name == "orders":
		return _builtin_orders(args, line)
	for a in args:
		if a is String:
			_fail("%s() takes a name like GRILL or a number, not text in quotes." % name, line)
			return 0
		if a is Array:
			_fail("%s() takes one value, not a whole array. Use one item, like list[i]." % name, line)
			return 0
	if host == null:
		return 0
	var r: Dictionary = await host.run_builtin(name, args, line)
	_steps = 0  # real kitchen work happened
	_since_yield = 0
	if stopped:
		return 0
	if r.has("error"):
		_fail(r.error, line)
		return 0
	return r.get("value", 0)


func _printf(n: Dictionary):
	if n.args.is_empty():
		_fail("printf needs text, like  printf(\"Hello\\n\");", n.line)
		return 0
	var fmt = await _eval(n.args[0])
	if not (fmt is String):
		_fail("printf's first value must be text in quotes, like  printf(\"%%d\\n\", x);", n.line)
		return 0
	var values: Array = []
	var sources: Array = []  # for level goals: did each value come from a variable?
	for i in range(1, n.args.size()):
		values.append(await _eval(n.args[i]))
		if _halted():
			return 0
		var a: Dictionary = n.args[i]
		var cell = null
		if a.k == "var":
			var sc = _scope_with(a.name)
			if sc != null:
				cell = sc[a.name]
		sources.append(cell)
	var items: Array = []
	var out := ""
	var vi := 0
	var i := 0
	while i < fmt.length():
		var c: String = fmt[i]
		if c != "%":
			out += c
			i += 1
			continue
		i += 1
		if i < fmt.length() and fmt[i] == "%":
			out += "%"
			i += 1
			continue
		# %[-][width][.precision](d|i|f|c|s)
		var spec := "%"
		while i < fmt.length() and (fmt[i] in "-0123456789."):
			spec += fmt[i]
			i += 1
		if i < fmt.length() and fmt[i] == "l":
			i += 1  # %ld / %lf
		if i >= fmt.length():
			_fail("printf format ends with an unfinished '%'.", n.line)
			return 0
		var conv: String = fmt[i]
		i += 1
		if not (conv in ["d", "i", "f", "c", "s", "u", "x"]):
			_fail("printf doesn't understand %%%s. Use %%d, %%f, %%c or %%s." % conv, n.line)
			return 0
		if vi >= values.size():
			_fail("printf has more % codes than values. Add a value for each %.", n.line)
			return 0
		var v = values[vi]
		var src = sources[vi]
		items.append({"conv": "i" if conv == "u" else conv,
			"type": src.type if src != null else ("float" if v is float else ("str" if v is String else "int")),
			"var": src != null, "changed": src != null and src.get("changed", false)})
		vi += 1
		if v is Array:
			_fail("printf can't print a whole array. Print one item at a time in a loop, like list[i].", n.line)
			return 0
		match conv:
			"d", "i", "u":
				if v is String:
					_fail("%d needs a number, but got text. Use %s for text.", n.line)
					return 0
				out += (spec + "d") % int(v)
			"x":
				out += (spec + "x") % int(v)
			"f":
				if v is String:
					_fail("%f needs a number, but got text.", n.line)
					return 0
				if not "." in spec:
					spec += ".6"
				out += (spec + "f") % float(v)
			"c":
				out += (spec + "s") % (v if v is String else String.chr(int(v)))
			"s":
				if v is String:
					out += (spec + "s") % v
				else:
					var nm := Kitchen.name_of(int(v))
					out += (spec + "s") % (nm if nm != "" else str(v))
	if vi < values.size():
		_fail("printf got more values than % codes.", n.line)
		return 0
	_output_chars += out.length()
	if _output_chars > MAX_OUTPUT_CHARS:
		_fail("Too much printing! Is printf inside a loop that never ends?", n.line)
		return 0
	output.emit(out)
	if host != null and host.has_method("note_printf"):
		host.note_printf(items, out)
	return out.length()

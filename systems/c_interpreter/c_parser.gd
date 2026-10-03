extends RefCounted
## Byte n' Bite C interpreter — step 2: turns tokens into a syntax tree (AST).
## Recursive descent over the supported C subset. Anything outside the subset
## (pointers, structs...) stops with a friendly message. Arrays have 1 or 2
## dimensions: int a[3]; int b[] = {1, 2}; int grid[2][3] = {{...}, {...}};
##
## Result of parse(): {"globals": [decl nodes], "functions": {name: fn}}
## fn = {"name", "ret", "params": [{"type","name","array": dims or 0}], "body": block, "line"}
## Every node is a Dictionary with "k" (kind) and "line".

const TYPE_WORDS := ["int", "float", "double", "char", "bool", "void", "const", "unsigned", "long", "short", "static"]
const ASSIGN_OPS := ["=", "+=", "-=", "*=", "/=", "%="]
const LEVELS := [
	["||"], ["&&"], ["==", "!="], ["<", "<=", ">", ">="], ["+", "-"], ["*", "/", "%"],
]

## Set on the first problem: {"line": int, "msg": String}. Empty when fine.
var error := {}

var _toks: Array = []
var _pos := 0


func parse(tokens: Array) -> Dictionary:
	_toks = tokens
	_pos = 0
	error = {}
	var globals: Array = []
	var functions := {}
	while _peek().type != "eof":
		var line: int = _peek().line
		var type := _parse_type()
		if type == "":
			if error.is_empty():
				_fail("Expected a type like int or void here, but found '%s'." % _peek().value)
			break
		var name := _expect_ident("a name")
		if name == "":
			break
		if _is_op("("):
			var fn := _parse_function(type, name, line)
			if fn.is_empty():
				continue  # prototype or error
			if functions.has(name):
				_fail("The function %s() is defined twice." % name, line)
				break
			functions[name] = fn
		else:
			globals.append(_parse_declarators(type, name, line))
	return {"globals": globals, "functions": functions}


# --- Token helpers ------------------------------------------------------------------

func _peek(offset := 0) -> Dictionary:
	if not error.is_empty():
		return {"type": "eof", "value": "", "line": _toks[-1].line if _toks.size() else 1}
	return _toks[mini(_pos + offset, _toks.size() - 1)]


func _next() -> Dictionary:
	var t := _peek()
	if _pos < _toks.size() - 1:
		_pos += 1
	return t


func _prev_line() -> int:
	return _toks[maxi(_pos - 1, 0)].line


func _is_op(v: String, offset := 0) -> bool:
	var t := _peek(offset)
	return t.type == "op" and t.value == v


func _is_kw(v: String, offset := 0) -> bool:
	var t := _peek(offset)
	return t.type == "kw" and t.value == v


func _accept_op(v: String) -> bool:
	if _is_op(v):
		_next()
		return true
	return false


func _expect_op(v: String, what := "") -> bool:
	if _accept_op(v):
		return true
	var found := _describe(_peek())
	if what == "":
		_fail("Expected '%s' but found %s." % [v, found])
	else:
		_fail("Expected '%s' %s, but found %s." % [v, what, found])
	return false


func _expect_semi() -> bool:
	if _accept_op(";"):
		return true
	_fail("Missing ';' at the end of line %d." % _prev_line(), _prev_line())
	return false


func _expect_ident(what: String) -> String:
	var t := _peek()
	if t.type == "ident":
		_next()
		return t.value
	if t.type == "kw":
		_fail("'%s' is a C keyword, so it can't be used as %s." % [t.value, what])
	else:
		_fail("Expected %s here, but found %s." % [what, _describe(t)])
	return ""


func _describe(t: Dictionary) -> String:
	match t.type:
		"eof":
			return "the end of the program"
		"string":
			return "text \"%s\"" % t.value
		_:
			return "'%s'" % str(t.value)


func _fail(msg: String, line := -1) -> void:
	if not error.is_empty():
		return
	error = {"line": line if line > 0 else int(_toks[mini(_pos, _toks.size() - 1)].line), "msg": msg}


# --- Types and declarations -----------------------------------------------------

func _starts_type(offset := 0) -> bool:
	var t := _peek(offset)
	return t.type == "kw" and (t.value in TYPE_WORDS or t.value in ["struct", "union", "enum", "typedef"])


## Reads a type. Returns "int" | "float" | "char" | "bool" | "void", or "" on error.
func _parse_type() -> String:
	var t := _peek()
	if t.type != "kw":
		return ""
	if t.value in ["struct", "union", "enum", "typedef"]:
		_fail("'%s' isn't used in Byte n' Bite. Stick to int, float, char and bool." % t.value)
		return ""
	var base := ""
	var seen_word := false
	while _peek().type == "kw" and _peek().value in TYPE_WORDS:
		var w: String = _next().value
		seen_word = true
		match w:
			"const", "static", "unsigned":
				pass
			"short", "long":
				if base == "":
					base = "int"
			"double":
				base = "float"
			_:
				base = w
	if not seen_word:
		return ""
	if base == "":
		base = "int"  # plain "unsigned" / "const" means int
	if _is_op("*"):
		_fail("Pointers ('*') aren't part of Byte n' Bite's C. Use a plain variable instead.")
		return ""
	return base


func _parse_function(ret: String, name: String, line: int) -> Dictionary:
	_expect_op("(")
	var params: Array = []
	if _is_kw("void") and _is_op(")", 1):
		_next()
	elif not _is_op(")"):
		while error.is_empty():
			var ptype := _parse_type()
			if ptype == "":
				_fail("Each parameter needs a type, like (int count).")
				return {}
			if ptype == "void":
				_fail("A parameter can't be void.")
				return {}
			var pname := _expect_ident("a parameter name")
			var pdims := 0
			while _accept_op("["):
				pdims += 1
				if not _is_op("]"):
					_parse_assign()  # the size is optional for parameters
				_expect_op("]", "to close the [ ] of %s" % pname)
			if pdims > 2:
				_fail("Arrays in Byte n' Bite have 1 or 2 dimensions, like items[] or grid[][3].")
				return {}
			params.append({"type": ptype, "name": pname, "array": pdims})
			if not _accept_op(","):
				break
	if not _expect_op(")", "to close the parameter list"):
		return {}
	if _accept_op(";"):
		return {}  # prototype: the real definition comes later
	if not _is_op("{"):
		_fail("Expected '{' to start the body of %s()." % name)
		return {}
	var body := _parse_block()
	return {"name": name, "ret": ret, "params": params, "body": body, "line": line}


## "int a = 1, b;" after the type and first name were read.
func _parse_declarators(type: String, first_name: String, line: int) -> Dictionary:
	if type == "void":
		_fail("A variable can't be void. Did you mean int?", line)
		return {}
	var vars: Array = []
	var name := first_name
	while error.is_empty():
		var dims: Array = []
		while _accept_op("["):
			if _is_op("]"):
				dims.append(null)  # size comes from the { } list
			else:
				dims.append(_parse_assign())
			_expect_op("]", "to close the array size of %s" % name)
		if dims.size() > 2:
			_fail("Arrays in Byte n' Bite have 1 or 2 dimensions, like a[3] or grid[2][3].")
			return {}
		for i in range(1, dims.size()):
			if dims[i] == null:
				_fail("Only the first size of %s can be left empty, like %s[][3]." % [name, name])
				return {}
		var init = null
		if _accept_op("="):
			if _is_op("{"):
				if dims.is_empty():
					_fail("A { } list can only fill an array. Did you mean  int %s[] = {...};  ?" % name)
					return {}
				init = _parse_init_list()
			else:
				init = _parse_assign()
				if not dims.is_empty():
					_fail("An array is filled with a list in { }, like  int %s[] = {1, 2, 3};" % name)
					return {}
		elif not dims.is_empty() and dims[0] == null:
			_fail("%s[] needs a size or a { } list, like  int %s[3];" % [name, name])
			return {}
		vars.append({"name": name, "init": init, "dims": dims})
		if not _accept_op(","):
			break
		name = _expect_ident("a variable name")
	_expect_semi()
	return {"k": "decl", "type": type, "vars": vars, "line": line}


## { 1, 2, 3 } or { {1, 2}, {3, 4} }
func _parse_init_list() -> Dictionary:
	var line: int = _next().line  # {
	var items: Array = []
	while error.is_empty() and not _is_op("}"):
		if _is_op("{"):
			items.append(_parse_init_list())
		else:
			items.append(_parse_assign())
		if not _accept_op(","):
			break
	_expect_op("}", "to close the { } list")
	return {"k": "list", "items": items, "line": line}


# --- Statements --------------------------------------------------------------------

func _parse_block() -> Dictionary:
	var line: int = _peek().line
	_expect_op("{")
	var body: Array = []
	while error.is_empty() and not _is_op("}"):
		if _peek().type == "eof":
			_fail("A '{' block is never closed. Add a '}'.", line)
			break
		body.append(_parse_statement())
	_accept_op("}")
	return {"k": "block", "body": body, "line": line}


func _parse_statement() -> Dictionary:
	var t := _peek()
	var line: int = t.line
	if t.type == "op":
		match t.value:
			"{":
				return _parse_block()
			";":
				_next()
				return {"k": "empty", "line": line}
	if t.type == "kw":
		match t.value:
			"if":
				_next()
				_expect_op("(", "after if")
				var cond := _parse_expr()
				_expect_op(")", "to close the if condition")
				var then_s := _parse_statement()
				var else_s = null
				if _is_kw("else"):
					_next()
					else_s = _parse_statement()
				return {"k": "if", "cond": cond, "then_s": then_s, "else_s": else_s, "line": line}
			"while":
				_next()
				_expect_op("(", "after while")
				var cond := _parse_expr()
				_expect_op(")", "to close the while condition")
				return {"k": "while", "cond": cond, "body": _parse_statement(), "line": line}
			"do":
				_next()
				var body := _parse_statement()
				if not _is_kw("while"):
					_fail("A do { } block must end with while (condition);")
					return {}
				_next()
				_expect_op("(", "after while")
				var cond := _parse_expr()
				_expect_op(")", "to close the while condition")
				_expect_semi()
				return {"k": "do", "cond": cond, "body": body, "line": line}
			"for":
				return _parse_for()
			"return":
				_next()
				var value = null
				if not _is_op(";"):
					value = _parse_expr()
				_expect_semi()
				return {"k": "return", "value": value, "line": line}
			"break", "continue":
				_next()
				_expect_semi()
				return {"k": t.value, "line": line}
			"switch":
				return _parse_switch()
			"case", "default":
				_fail("'%s' only works inside a switch ( ) { } block." % t.value)
				return {}
			"goto":
				_fail("goto isn't allowed in Byte n' Bite. Use loops and if statements.")
				return {}
			"else":
				_fail("This 'else' has no matching 'if' before it.")
				return {}
	if _starts_type():
		var type := _parse_type()
		if type == "":
			return {}
		var name := _expect_ident("a variable name")
		if _is_op("("):
			_fail("Functions must be written outside main(), not inside another function.")
			return {}
		return _parse_declarators(type, name, line)
	var e := _parse_expr()
	_expect_semi()
	return {"k": "expr", "e": e, "line": line}


## switch (value) { case A: ... break; default: ... }
## -> {"k": "switch", "value", "cases": [{"value", "at"}], "default": index or -1, "body": [statements]}
func _parse_switch() -> Dictionary:
	var line: int = _next().line
	_expect_op("(", "after switch")
	var value := _parse_expr()
	_expect_op(")", "to close the switch value")
	if not _expect_op("{", "to start the switch block"):
		return {}
	var cases: Array = []
	var default_at := -1
	var body: Array = []
	while error.is_empty() and not _is_op("}"):
		if _peek().type == "eof":
			_fail("A switch block is never closed. Add a '}'.", line)
			return {}
		if _is_kw("case"):
			var cline: int = _next().line
			var cv := _parse_expr()
			if not _accept_op(":"):
				_fail("Each case needs a colon, like:  case EGSILOG:", cline)
				return {}
			cases.append({"value": cv, "at": body.size(), "line": cline})
		elif _is_kw("default"):
			_next()
			if not _accept_op(":"):
				_fail("default needs a colon:  default:")
				return {}
			if default_at >= 0:
				_fail("A switch can only have one default.")
				return {}
			default_at = body.size()
		else:
			if cases.is_empty() and default_at < 0:
				_fail("Code in a switch must come after a 'case VALUE:' or 'default:' label.")
				return {}
			body.append(_parse_statement())
	_expect_op("}")
	if cases.is_empty() and default_at < 0:
		_fail("This switch has no case labels. Add  case VALUE:  lines.", line)
	return {"k": "switch", "value": value, "cases": cases, "default": default_at, "body": body, "line": line}


func _parse_for() -> Dictionary:
	var line: int = _next().line
	_expect_op("(", "after for")
	var init = null
	if _accept_op(";"):
		pass
	elif _starts_type():
		var type := _parse_type()
		var name := _expect_ident("a variable name")
		init = _parse_declarators(type, name, line)  # eats the ';'
	else:
		init = {"k": "expr", "e": _parse_expr(), "line": line}
		_expect_semi()
	var cond = null
	if not _is_op(";"):
		cond = _parse_expr()
	_expect_semi()
	var step = null
	if not _is_op(")"):
		step = _parse_expr()
	_expect_op(")", "to close the for loop header")
	var body := _parse_statement()
	return {"k": "for", "init": init, "cond": cond, "step": step, "body": body, "line": line}


# --- Expressions ----------------------------------------------------------------------

func _parse_expr() -> Dictionary:
	var e := _parse_assign()
	if _is_op(","):
		_fail("The comma operator isn't supported. Split this into separate statements.")
	return e


func _parse_assign() -> Dictionary:
	var left := _parse_ternary()
	var t := _peek()
	if t.type == "op" and t.value in ASSIGN_OPS:
		_next()
		if left.get("k") == "index":
			var rv := _parse_assign()
			return {"k": "assign_index", "op": t.value, "target": left, "value": rv, "line": t.line}
		if left.get("k") != "var":
			_fail("The left side of '%s' must be a variable name." % t.value, t.line)
			return {}
		var right := _parse_assign()
		return {"k": "assign", "op": t.value, "name": left.name, "value": right, "line": t.line}
	return left


func _parse_ternary() -> Dictionary:
	var cond := _parse_binary(0)
	if _is_op("?"):
		var line: int = _next().line
		var a := _parse_assign()
		_expect_op(":", "in the ? : expression")
		var b := _parse_ternary()
		return {"k": "ternary", "cond": cond, "a": a, "b": b, "line": line}
	return cond


func _parse_binary(level: int) -> Dictionary:
	if level >= LEVELS.size():
		return _parse_unary()
	var left := _parse_binary(level + 1)
	while error.is_empty():
		var t := _peek()
		if t.type != "op":
			break
		if t.value in LEVELS[level]:
			_next()
			var right := _parse_binary(level + 1)
			left = {"k": "bin", "op": t.value, "a": left, "b": right, "line": t.line}
		elif t.value in ["&", "|", "^", "<<", ">>"] and level == 0:
			var hint := " Did you mean '&&'?" if t.value == "&" else (" Did you mean '||'?" if t.value == "|" else "")
			_fail("Bitwise operator '%s' isn't supported yet.%s" % [t.value, hint])
			break
		else:
			break
	return left


func _parse_unary() -> Dictionary:
	var t := _peek()
	if t.type == "op":
		match t.value:
			"-", "+", "!":
				_next()
				return {"k": "un", "op": t.value, "a": _parse_unary(), "line": t.line}
			"++", "--":
				_next()
				var target := _parse_unary()
				if target.get("k") == "index":
					return {"k": "incdec_index", "op": t.value, "prefix": true, "target": target, "line": t.line}
				if target.get("k") != "var":
					_fail("'%s' only works on a variable." % t.value, t.line)
					return {}
				return {"k": "incdec", "op": t.value, "prefix": true, "name": target.name, "line": t.line}
			"&", "*":
				_fail("Pointers ('%s') aren't part of Byte n' Bite's C." % t.value)
				return {}
			"~":
				_fail("Bitwise operator '~' isn't supported yet.")
				return {}
			"(":
				# A cast like (int) x, or just parentheses.
				if _starts_type(1):
					_next()
					var type := _parse_type()
					_expect_op(")", "to close the cast")
					return {"k": "cast", "type": type, "a": _parse_unary(), "line": t.line}
	if _is_kw("sizeof"):
		var sline: int = _next().line
		if not _expect_op("(", "after sizeof"):
			return {}
		if _starts_type():
			var word: String = _peek().value
			_parse_type()
			_expect_op(")", "to close sizeof( )")
			return {"k": "sizeof", "type": word, "line": sline}
		var se := _parse_expr()
		_expect_op(")", "to close sizeof( )")
		return {"k": "sizeof", "e": se, "line": sline}
	return _parse_postfix()


func _parse_postfix() -> Dictionary:
	var e := _parse_primary()
	while error.is_empty():
		var t := _peek()
		if t.type != "op":
			break
		if t.value in ["++", "--"]:
			_next()
			if e.get("k") == "index":
				e = {"k": "incdec_index", "op": t.value, "prefix": false, "target": e, "line": t.line}
				continue
			if e.get("k") != "var":
				_fail("'%s' only works on a variable." % t.value, t.line)
				break
			e = {"k": "incdec", "op": t.value, "prefix": false, "name": e.name, "line": t.line}
		elif t.value == "[":
			_next()
			if e.get("k") != "var" and e.get("k") != "index":
				_fail("Only an array name can be followed by [ ], like items[0].", t.line)
				break
			var idx := _parse_expr()
			_expect_op("]", "to close the [ ]")
			e = {"k": "index", "base": e, "index": idx, "line": t.line}
		elif t.value == "." or t.value == "->":
			_fail("Structs ('%s') aren't part of Byte n' Bite's C." % t.value)
			break
		else:
			break
	return e


func _parse_primary() -> Dictionary:
	var t := _peek()
	match t.type:
		"int", "float", "char":
			_next()
			return {"k": "num", "type": t.type, "v": t.value, "line": t.line}
		"string":
			_next()
			var s: String = t.value
			while _peek().type == "string":  # "a" "b" joins like in C
				s += _next().value
			return {"k": "str", "v": s, "line": t.line}
		"kw":
			if t.value == "true" or t.value == "false":
				_next()
				return {"k": "num", "type": "bool", "v": 1 if t.value == "true" else 0, "line": t.line}
			_fail("Unexpected keyword '%s' here." % t.value)
			return {}
		"ident":
			_next()
			if _accept_op("("):
				var args: Array = []
				if not _is_op(")"):
					while error.is_empty():
						args.append(_parse_assign())
						if not _accept_op(","):
							break
				_expect_op(")", "to close the call to %s()" % t.value)
				return {"k": "call", "name": t.value, "args": args, "line": t.line}
			return {"k": "var", "name": t.value, "line": t.line}
		"op":
			if t.value == "(":
				_next()
				var e := _parse_expr()
				_expect_op(")")
				return e
	_fail("Expected a value here, but found %s." % _describe(t))
	return {}

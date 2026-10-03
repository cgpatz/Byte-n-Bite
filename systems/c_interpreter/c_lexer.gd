extends RefCounted
## Byte n' Bite C interpreter — step 1: turns source text into tokens.
## Token = {"type": "int"|"float"|"char"|"string"|"ident"|"kw"|"op"|"eof", "value": ..., "line": int}

const KEYWORDS := [
	"int", "float", "double", "char", "bool", "void",
	"if", "else", "while", "for", "do", "return", "break", "continue",
	"true", "false", "const", "unsigned", "long", "short",
	"struct", "union", "enum", "typedef", "sizeof", "switch", "case", "default", "goto", "static",
]
const OPS2 := ["++", "--", "+=", "-=", "*=", "/=", "%=", "==", "!=", "<=", ">=", "&&", "||", "->", "<<", ">>"]
const OPS1 := "+-*/%<>=!(){}[];,&.?:|^~"
const DIGITS := "0123456789"

## Problems found while reading: [{"line": int, "msg": String}]
var errors: Array = []


func tokenize(src: String) -> Array:
	errors.clear()
	var toks: Array = []
	var i := 0
	var line := 1
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == "\n":
			line += 1
			i += 1
		elif c == " " or c == "\t" or c == "\r":
			i += 1
		elif c == "#":
			# Preprocessor lines like #include <stdio.h> are allowed and ignored.
			while i < n and src[i] != "\n":
				i += 1
		elif c == "/" and i + 1 < n and src[i + 1] == "/":
			while i < n and src[i] != "\n":
				i += 1
		elif c == "/" and i + 1 < n and src[i + 1] == "*":
			var start_line := line
			i += 2
			while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
				if src[i] == "\n":
					line += 1
				i += 1
			if i >= n:
				errors.append({"line": start_line, "msg": "This /* comment is never closed with */."})
				break
			i += 2
		elif c in DIGITS or (c == "." and i + 1 < n and src[i + 1] in DIGITS):
			var s := i
			var is_float := false
			while i < n and (src[i] in DIGITS or src[i] == "."):
				if src[i] == ".":
					is_float = true
				i += 1
			var text := src.substr(s, i - s)
			if i < n and (src[i] == "f" or src[i] == "F"):
				is_float = true
				i += 1
			if is_float:
				toks.append(_tok("float", text.to_float(), line))
			else:
				toks.append(_tok("int", text.to_int(), line))
		elif _is_ident_char(c):
			var s := i
			while i < n and (_is_ident_char(src[i]) or src[i] in DIGITS):
				i += 1
			var word := src.substr(s, i - s)
			toks.append(_tok("kw" if word in KEYWORDS else "ident", word, line))
		elif c == "\"":
			i += 1
			var out := ""
			while i < n and src[i] != "\"" and src[i] != "\n":
				if src[i] == "\\" and i + 1 < n:
					out += _escape(src[i + 1])
					i += 2
				else:
					out += src[i]
					i += 1
			if i < n and src[i] == "\"":
				i += 1
			else:
				errors.append({"line": line, "msg": "This text in \" quotes is never closed. Add a \" at the end."})
			toks.append(_tok("string", out, line))
		elif c == "'":
			i += 1
			var ch := ""
			if i < n and src[i] == "\\" and i + 1 < n:
				ch = _escape(src[i + 1])
				i += 2
			elif i < n:
				ch = src[i]
				i += 1
			if i < n and src[i] == "'":
				i += 1
			else:
				errors.append({"line": line, "msg": "A character must be one letter in single quotes, like 'A'."})
			toks.append(_tok("char", ch.unicode_at(0) if ch != "" else 0, line))
		else:
			var two := src.substr(i, 2)
			if two in OPS2:
				toks.append(_tok("op", two, line))
				i += 2
			elif c in OPS1:
				toks.append(_tok("op", c, line))
				i += 1
			else:
				errors.append({"line": line, "msg": "The character '%s' isn't part of C." % c})
				i += 1
	toks.append(_tok("eof", "", line))
	return toks


func _tok(type: String, value, line: int) -> Dictionary:
	return {"type": type, "value": value, "line": line}


func _is_ident_char(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"


func _escape(c: String) -> String:
	match c:
		"n":
			return "\n"
		"t":
			return "\t"
		"0":
			return ""
		_:
			return c  # \\ \" \' and anything else

extends RefCounted
## "Explain my code": turns one line of the player's C into plain English, shown
## when the mouse rests on that line in the code editor. Pattern-based and
## friendly rather than complete: it covers the C that Byte n' Bite teaches.

const Builtins := preload("res://systems/c_interpreter/c_builtins.gd")

const KITCHEN := {
	"go_to": "{who} walks to the {a}.",
	"move_to": "{who} walks to the {a}.",
	"pick_up": "{who} takes one {a} (stand at the FRIDGE or where it's stored).",
	"cook": "{who} cooks what they're holding at this station.",
	"plate": "{who} puts the food they hold on the plate (at the ASSEMBLY).",
	"assemble": "{who} turns the plate into a {a}.",
	"serve": "{who} carries the dish to the customer who ordered it.",
	"wait": "{who} waits {a} second(s).",
	"holding": "Gives back what {who} is holding (NOTHING if the hands are empty).",
	"take_order": "{who} asks the next customer what they want; gives back the dish.",
	"next_order": "Gives back the next dish someone ordered.",
	"has_order": "Gives back 1 (true) if a customer is waiting for an order.",
	"is_burnt": "Gives back 1 (true) if the food {who} holds is burnt.",
	"trash": "{who} throws away what they hold (at the TRASH).",
	"post_order": "{who} pins a {a} ticket on the counter for the cook.",
	"check_counter": "Gives back the next ticket on the counter (NOTHING if none).",
	"stock": "Gives back how many {a} are left in the kitchen.",
	"doneness": "Gives back how cooked the food is.",
	"flip": "{who} flips the food on the grill.",
	"recipe": "Fills the array with {a}'s ingredients and gives back how many there are.",
	"orders": "Copies the waiting tickets into the array and gives back how many.",
	"cook_station": "Gives back the station that cooks {a}.",
}
const OPS := {"==": "is equal to", "!=": "is not equal to", "<=": "is at most", ">=": "is at least",
	"<": "is less than", ">": "is greater than", "&&": "AND", "||": "OR"}


static func explain(line: String, who := "The staff member") -> String:
	var t := line.strip_edges()
	var comment := ""
	var ci := t.find("//")
	if ci == 0:
		return "A comment: a note for people. The computer skips it."
	if ci > 0 and not t.substr(0, ci).contains("\""):
		comment = "  (The part after // is a note the computer skips.)"
		t = t.substr(0, ci).strip_edges()
	if t == "" or t == "{":
		return ""
	if t.begins_with("}"):
		var rest := t.substr(1).strip_edges()
		if rest.begins_with("else"):
			return explain(rest, who)
		if rest.begins_with("while"):
			return "Ends the do block, then repeats it while %s." % _cond(_inside(rest))
		return "Ends the block that started with the matching {."
	var r := RegEx.new()
	# main / function definitions
	r.compile("^(void|int|float|double|char|bool)\\s+([A-Za-z_]\\w*)\\s*\\(([^)]*)\\)\\s*\\{?$")
	var m := r.search(t)
	if m:
		if m.get_string(2) == "main":
			return "The program starts here: main() runs first, top to bottom."
		var params := m.get_string(3).strip_edges()
		var gives := "gives nothing back" if m.get_string(1) == "void" else "gives back %s %s" % ["an" if m.get_string(1) == "int" else "a", m.get_string(1)]
		return "Makes your own function %s()%s; it %s. Call it later by writing %s(...);" % [
			m.get_string(2), "" if params == "" or params == "void" else " that takes " + params, gives, m.get_string(2)]
	if t.begins_with("if") or t.begins_with("else if"):
		var c := _cond(_inside(t))
		return ("Otherwise, checks: " if t.begins_with("else") else "Checks: ") + "is it true that %s? If yes, runs the lines inside { }." % c
	if t.begins_with("else"):
		return "Otherwise (when the if above was false), runs these lines."
	if t.begins_with("while"):
		if _inside(t) == "1":
			return "Repeats the lines inside { } forever (until a break)."
		return "Repeats the lines inside { } as long as %s." % _cond(_inside(t))
	if t.begins_with("do"):
		return "Runs the lines inside { } once, then repeats while the condition at the end is true."
	if t.begins_with("for"):
		var parts := _inside(t).split(";")
		if parts.size() == 3:
			return "Repeats the block: first %s; keeps going while %s; after each round, %s." % [
				_stmt(parts[0]), _cond(parts[1]), _stmt(parts[2])]
		return "A for loop: repeats the lines inside { }."
	if t.begins_with("switch"):
		return "Looks at %s and jumps to the matching case below." % _inside(t)
	if t.begins_with("case"):
		return "If the switch value is %s, start here." % t.substr(4).trim_suffix(":").strip_edges()
	if t.begins_with("default"):
		return "If no case matched, start here."
	if t.begins_with("break"):
		return "Stops here and jumps out of the loop or switch."
	if t.begins_with("continue"):
		return "Skips the rest of this round and starts the next round of the loop."
	if t.begins_with("return"):
		var v := t.substr(6).trim_suffix(";").strip_edges()
		return "Ends the function%s." % ("" if v == "" else " and gives back " + v)
	if t.begins_with("printf"):
		var q := RegEx.new()
		q.compile("\"(.*)\"")
		var qm := q.search(t)
		var text := qm.get_string(1).replace("\\n", "") if qm else ""
		var extra := ""
		if text.contains("%"):
			extra = " The %d %f %c %s spots are filled with the values after the quotes, in order."
		return "Prints \"%s\" in the Output box, and %s says it in a bubble.%s%s" % [text, who, extra, comment]
	# kitchen function calls
	r.compile("^([a-z_]+)\\s*\\((.*)\\)\\s*;?$")
	m = r.search(t)
	if m and KITCHEN.has(m.get_string(1)):
		return String(KITCHEN[m.get_string(1)]).replace("{who}", who).replace("{a}", m.get_string(2).strip_edges()) + comment
	if m:
		return "Runs your function %s()%s." % [m.get_string(1), "" if m.get_string(2).strip_edges() == "" else " with " + m.get_string(2).strip_edges()] + comment
	return _sentence(_stmt(t.trim_suffix(";"))) + comment


static func _sentence(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) + "."


static func _inside(t: String) -> String:
	var a := t.find("(")
	var b := t.rfind(")")
	return t.substr(a + 1, b - a - 1).strip_edges() if a >= 0 and b > a else t


static func _cond(c: String) -> String:
	var out := " " + c.strip_edges() + " "
	for op in ["==", "!=", "<=", ">=", "&&", "||", "<", ">"]:
		out = out.replace(" %s " % op, " %s " % OPS[op])
	out = out.strip_edges()
	if out == "1":
		return "always (forever, until break)"
	return out


## Declarations, assignments, ++ / -- in plain words.
static func _stmt(s: String) -> String:
	var t := s.strip_edges()
	var r := RegEx.new()
	r.compile("^(int|float|double|char|bool)\\s+([A-Za-z_]\\w*)\\s*(\\[[^\\]]*\\])*\\s*(=\\s*(.+))?$")
	var m := r.search(t)
	if m:
		var kind: String = {"int": "whole-number", "float": "decimal", "double": "decimal", "char": "one-letter", "bool": "true/false"}[m.get_string(1)]
		if m.get_string(3) != "":
			return "make an array of %s values named %s%s" % [kind, m.get_string(2), (" filled with " + m.get_string(5)) if m.get_string(5) != "" else ""]
		if m.get_string(5) != "":
			return "make a %s variable named %s and store %s in it" % [kind, m.get_string(2), m.get_string(5)]
		return "make a %s variable named %s" % [kind, m.get_string(2)]
	r.compile("^([A-Za-z_][\\w\\[\\]]*)\\s*(\\+\\+|--)$")
	m = r.search(t)
	if m:
		return "%s 1 %s %s" % ["add" if m.get_string(2) == "++" else "take", "to" if m.get_string(2) == "++" else "from", m.get_string(1)]
	r.compile("^([A-Za-z_][\\w\\[\\]]*)\\s*([+\\-*/%])=\\s*(.+)$")
	m = r.search(t)
	if m:
		var verbs := {"+": "add %s to %s", "-": "take %s away from %s", "*": "multiply %s by %s", "/": "divide %s by %s", "%": "keep the remainder of %s divided by %s"}
		var v: String = verbs[m.get_string(2)]
		if m.get_string(2) in ["*", "/", "%"]:
			return v % [m.get_string(1), m.get_string(3)]
		return v % [m.get_string(3), m.get_string(1)]
	r.compile("^([A-Za-z_][\\w\\[\\]]*)\\s*=\\s*(.+)$")
	m = r.search(t)
	if m:
		return "store %s in %s (the old value is replaced)" % [m.get_string(2), m.get_string(1)]
	return "run: " + t

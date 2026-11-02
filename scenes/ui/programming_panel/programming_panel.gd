extends Control
## Separate programming panel for one staff member (FR-04).
## Run hands the code to the staff member, who runs it with the C interpreter.
## It floats: drag the title bar to move it, drag the bottom-right corner to
## resize it, double-click the title bar to put it back. The Library drawer
## follows it. Where it was left is remembered (SettingsManager.code_window).

signal closed
## The Upgrade button was pressed (Game shows the confirm pop-up).
signal upgrade_requested(staff_name: String)

const Builtins := preload("res://systems/c_interpreter/c_builtins.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const PixelArt := preload("res://scenes/art/pixel_art.gd")
const ERROR_LINE_COLOR := Color(0.75, 0.2, 0.15, 0.45)
const EXEC_LINE_COLOR := Color(1.0, 0.8, 0.3, 0.22)

const C_KEYWORDS := [
	"int", "float", "double", "char", "bool", "void", "const",
	"if", "else", "for", "while", "do", "return", "break", "continue",
	"switch", "case", "default", "true", "false", "sizeof",
]
const C_UNSUPPORTED := ["struct", "malloc", "free", "typedef", "union", "goto"]

const CInterpreter := preload("res://systems/c_interpreter/c_interpreter.gd")

var staff: Staff = null
var _lib_panel: PanelContainer
var _lib_list: VBoxContainer
var _lib_toggle: Button
var _exec_line := -1
const MIN_SIZE := Vector2(600, 380)
const LIB_WIDTH := 420.0
const GRIP := 30.0
var _panel: PanelContainer
var _grip: Control
var _drag := ""          # "", "move" or "resize"
var _drag_from := Vector2.ZERO
var _rect_from := Rect2()
var _error_line := -1
var _upgrade: Button

@onready var title: Label = %Title
@onready var code_edit: CodeEdit = %CodeEdit
@onready var console: RichTextLabel = %Console
@onready var run_button: Button = %RunButton
@onready var stop_button: Button = %StopButton
@onready var close_button: Button = %CloseButton
@onready var hint: Label = $Panel/VBox/Hint


func _ready() -> void:
	hide()
	title.custom_minimum_size.x = 130  # "Jane · Lv 1" stays readable next to the buttons
	_setup_editor()
	PixelArt.button_icon(run_button, ["start_dark", "start"])
	run_button.pressed.connect(_on_run_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	_build_continue_button()
	close_button.pressed.connect(close)
	SettingsManager.changed.connect(_apply_font_size)
	code_edit.text_changed.connect(_on_code_changed)
	code_edit.gui_input.connect(_on_code_zoom_input)
	code_edit.code_completion_enabled = true
	code_edit.code_completion_requested.connect(_on_completion_requested)
	_build_snippet_bar()
	# Under the code: "Explain my code" (the line under the mouse or the caret,
	# in plain English) on the left, the zoom tip on the right.
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	code_edit.add_sibling(info_row)
	_explain_label = RichTextLabel.new()
	_explain_label.bbcode_enabled = true
	_explain_label.fit_content = true
	_explain_label.scroll_active = false
	_explain_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_explain_label.add_theme_font_size_override("normal_font_size", 14)
	_explain_label.add_theme_font_size_override("bold_font_size", 14)
	_explain_label.add_theme_color_override("default_color", Color(1, 0.9, 0.7))
	_explain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(_explain_label)
	var zoom_hint := Label.new()
	zoom_hint.text = "Zoom: Ctrl + wheel · Ctrl+0"
	zoom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zoom_hint.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	zoom_hint.add_theme_font_size_override("font_size", 12)
	zoom_hint.add_theme_color_override("font_color", Color(0.7, 0.6, 0.48))
	zoom_hint.add_theme_constant_override("outline_size", 0)
	zoom_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(zoom_hint)
	code_edit.caret_changed.connect(func(): _explain_line(code_edit.get_caret_line()))
	code_edit.mouse_exited.connect(func():
		_explained_line = -1
		_explain_line(code_edit.get_caret_line()))
	_explain_line(-1)
	_build_library_drawer()
	_setup_floating()
	_build_upgrade_button()
	_apply_opacity()


## "Upgrade" in the title row: buys this staff member's next level.
func _build_upgrade_button() -> void:
	_upgrade = Button.new()
	_upgrade.custom_minimum_size = Vector2(100, 40)
	_upgrade.add_theme_font_size_override("font_size", 17)
	_upgrade.focus_mode = Control.FOCUS_NONE
	_upgrade.tooltip_text = "Level up this staff member: faster walking and work, more coins per dish."
	_upgrade.pressed.connect(func():
		if staff:
			upgrade_requested.emit(staff.staff_name))
	close_button.get_parent().add_child(_upgrade)
	close_button.get_parent().move_child(_upgrade, close_button.get_index())
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	GameState.staff_upgraded.connect(func(_n, _l, _s): _update_title())


func _update_title() -> void:
	if staff == null:
		return
	var sp: String = GameState.staff_spec(staff.staff_name)
	var spec := (" " + sp) if sp != "" else ""
	title.text = "%s · Lv %d%s" % [staff.staff_name, GameState.staff_level(staff.staff_name), spec]
	_update_face()
	title.tooltip_text = "%s's program" % staff.staff_name
	var cost: int = GameState.staff_upgrade_cost(staff.staff_name)
	_upgrade.text = "Upgrade %d" % cost if cost > 0 else "Max Lv"
	_upgrade.disabled = cost <= 0


func _setup_editor() -> void:
	var mono: Font = preload("res://scenes/ui/common/ui_art.gd").mono()
	code_edit.add_theme_font_override("font", mono)
	_apply_font_size()

	var hl := CodeHighlighter.new()
	hl.number_color = Color(0.98, 0.72, 0.45)
	hl.symbol_color = Color(0.85, 0.8, 0.7)
	hl.function_color = Color(0.55, 0.8, 1.0)
	hl.member_variable_color = Color(0.92, 0.9, 0.85)
	for k in C_KEYWORDS:
		hl.add_keyword_color(k, Color(1.0, 0.6, 0.45))
	for k in C_UNSUPPORTED:
		hl.add_keyword_color(k, Color(1.0, 0.3, 0.3))
	hl.add_color_region("//", "", Color(0.5, 0.6, 0.45), true)
	hl.add_color_region("/*", "*/", Color(0.5, 0.6, 0.45))
	hl.add_color_region("\"", "\"", Color(0.95, 0.85, 0.5))
	hl.add_color_region("'", "'", Color(0.95, 0.85, 0.5))
	code_edit.syntax_highlighter = hl
	code_edit.placeholder_text = "// Empty program. Write your C code here, for example:\n\nvoid main() {\n    go_to(FRIDGE);\n    pick_up(RICE);\n}\n\n// Stuck? Open Lessons (T): it has every Kitchen Function too."
	code_edit.indent_size = 4
	code_edit.indent_use_spaces = true
	code_edit.gutters_draw_executing_lines = true


func _apply_font_size() -> void:
	code_edit.add_theme_font_size_override("font_size", SettingsManager.code_font_size)
	_apply_opacity()


## Settings > Code Editor Opacity: the window and code backgrounds become
## see-through so the kitchen shows behind; the text stays fully readable.
var _code_styles := {}


func _apply_opacity() -> void:
	var o := clampf(SettingsManager.code_opacity, 0.3, 1.0)
	if _panel:
		_panel.self_modulate.a = o
	if _lib_panel:
		_lib_panel.self_modulate.a = o
	for pair in [[code_edit, "normal"], [code_edit, "focus"], [console, "normal"]]:
		var c: Control = pair[0]
		var key: String = c.name + pair[1]
		if not _code_styles.has(key):
			var base := c.get_theme_stylebox(pair[1])
			if base is StyleBoxFlat:
				_code_styles[key] = base.duplicate()
				c.add_theme_stylebox_override(pair[1], _code_styles[key])
		var sb: StyleBoxFlat = _code_styles.get(key)
		if sb:
			sb.bg_color.a = o
	code_edit.add_theme_color_override("background_color", Color(0.1, 0.08, 0.07, 0.0 if o < 1.0 else 1.0))


## Code text size: Ctrl + mouse wheel (or Ctrl + = / Ctrl + - , Ctrl + 0 resets).
## Saved in Settings like the Code font size slider.
const CODE_SIZE_MIN := 10
const CODE_SIZE_MAX := 36
const CODE_SIZE_DEFAULT := 16
var _zoom_label: Label
var _zoom_tween: Tween


const Explainer := preload("res://data/help/code_explainer.gd")
var _explained_line := -1


## Explain my code: the line under the mouse (or the caret) in plain English,
## shown under the editor.
var _explain_label: RichTextLabel


func _explain_hover(pos: Vector2) -> void:
	var lc := code_edit.get_line_column_at_pos(Vector2i(pos), false)
	if lc.y == _explained_line:
		return
	_explained_line = lc.y
	_explain_line(lc.y)


func _explain_line(line: int) -> void:
	if _explain_label == null:
		return
	if line < 0 or line >= code_edit.get_line_count():
		_explain_label.text = "[color=#a8977c]Point at a line (or click in it) to read it in plain English.[/color]"
		return
	var who: String = staff.staff_name if staff else "The staff member"
	var e: String = Explainer.explain(code_edit.get_line(line), who)
	if e == "":
		_explain_label.text = "[color=#a8977c]Line %d: (empty or just a bracket)[/color]" % (line + 1)
	else:
		_explain_label.text = "[color=#c9b48f]Line %d:[/color] %s" % [line + 1, e.replace("[", "[lb]")]


func _on_code_zoom_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_explain_hover(e.position)
		return
	var step := 0
	if e is InputEventMouseButton and e.pressed and e.ctrl_pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = 1
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = -1
	elif e is InputEventKey and e.pressed and e.ctrl_pressed and not e.shift_pressed:
		match e.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				step = 1
			KEY_MINUS, KEY_KP_SUBTRACT:
				step = -1
			KEY_0, KEY_KP_0:
				_set_code_size(CODE_SIZE_DEFAULT)
				code_edit.accept_event()
				return
	if step == 0:
		return
	code_edit.accept_event()
	_set_code_size(SettingsManager.code_font_size + step)


func _set_code_size(v: int) -> void:
	v = clampi(v, CODE_SIZE_MIN, CODE_SIZE_MAX)
	if v != SettingsManager.code_font_size:
		SettingsManager.code_font_size = v
		SettingsManager.save_settings()
		SettingsManager.changed.emit()
	_show_zoom(v)


func _show_zoom(v: int) -> void:
	if _zoom_label == null:
		_zoom_label = Label.new()
		_zoom_label.add_theme_font_size_override("font_size", 16)
		_zoom_label.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.7)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		_zoom_label.add_theme_stylebox_override("normal", sb)
		_zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		code_edit.add_child(_zoom_label)
	_zoom_label.text = "Code size %d  (Ctrl+0 resets)" % v
	_zoom_label.reset_size()
	_zoom_label.position = Vector2(code_edit.size.x - _zoom_label.size.x - 24, 8)
	_zoom_label.modulate.a = 1.0
	_zoom_label.show()
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_interval(1.0)
	_zoom_tween.tween_property(_zoom_label, "modulate:a", 0.0, 0.4)


func open(for_staff: Staff) -> void:
	_disconnect_staff()
	_fill_snippet_bar()
	staff = for_staff
	staff.log_added.connect(_on_log_added)
	staff.running_changed.connect(_on_running_changed)
	staff.paused_changed.connect(_on_paused_changed)
	staff.line_changed.connect(_on_line_changed)
	staff.error_at.connect(_on_error_at)
	_update_title()
	code_edit.text = staff.program_source
	_clear_marks()
	_update_hint()
	console.clear()
	if staff.log_text == "":
		_log("[color=#b9a58a]Editing %s's program. Press Run to save and execute.[/color]" % staff.staff_name)
	else:
		console.append_text(staff.log_text)
	_on_running_changed(staff.is_running())
	_fill_library()
	_lib_toggle.button_pressed = false  # every time the editor opens, the Library starts closed
	show()
	_apply_rect(SettingsManager.code_window)
	code_edit.grab_focus()
	_close_tab()


func close() -> void:
	if staff:
		staff.program_source = code_edit.text
		GameState.staff_programs[staff.staff_name] = code_edit.text
	_clear_executing()
	_disconnect_staff()
	hide()
	if _pin:
		_pin.hide()
	if is_instance_valid(_fn_card):
		_fn_card.queue_free()
	closed.emit()


func _disconnect_staff() -> void:
	if staff == null:
		return
	for pair in [[staff.log_added, _on_log_added], [staff.running_changed, _on_running_changed],
			[staff.line_changed, _on_line_changed], [staff.error_at, _on_error_at],
			[staff.paused_changed, _on_paused_changed]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


func _update_hint() -> void:
	var names: Array = []
	for n in Builtins.unlocked(GameState.restaurant_level):
		names.append(n + "()")
	var lv: int = GameState.restaurant_level
	hint.text = "Functions: %s, printf()\nMenu: %s" % [", ".join(names), ", ".join(GameState.current_menu())]
	_update_fn_bar()


var continue_button: Button


## Run (start / restart from the top), Stop (freeze at the current line),
## Continue (resume from where it stopped).
func _build_continue_button() -> void:
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(150, 52)
	continue_button.add_theme_font_size_override("font_size", 22)
	continue_button.tooltip_text = "Continue the program from the line where it stopped"
	continue_button.disabled = true
	stop_button.add_sibling(continue_button)
	continue_button.pressed.connect(_on_continue_pressed)
	step_button = Button.new()
	step_button.name = "StepButton"
	step_button.text = "Step"
	step_button.custom_minimum_size = Vector2(130, 52)
	step_button.add_theme_font_size_override("font_size", 22)
	step_button.tooltip_text = "Run ONE line, then wait (watch the Variables box change)"
	continue_button.add_sibling(step_button)
	step_button.pressed.connect(func():
		if staff:
			if not staff.is_running():
				staff.program_source = code_edit.text
				_clear_marks()
			staff.step_program())
	_build_variables_box()
	run_button.tooltip_text = "Run the code from the top (restarts if already running)"
	stop_button.tooltip_text = "Stop the code at the current line"


func _on_run_pressed() -> void:
	if staff == null:
		return
	staff.program_source = code_edit.text
	_clear_marks()
	if staff.is_running():
		staff.restart_program()
	else:
		staff.run_program()  # runs in the background; the panel can be closed


func _on_stop_pressed() -> void:
	if staff and staff.is_running():
		staff.pause_program()


func _on_continue_pressed() -> void:
	if staff:
		staff.resume_program()


func _on_paused_changed(_p: bool) -> void:
	_refresh_buttons()


func _refresh_buttons() -> void:
	var running: bool = staff != null and staff.is_running()
	var paused: bool = running and staff.paused
	run_button.disabled = false
	stop_button.disabled = not running or paused
	if continue_button:
		continue_button.disabled = not paused
	if step_button:
		step_button.disabled = staff == null
	_refresh_variables()


# --- Variables box (beside Output): every variable's value, live -----------------

var step_button: Button
var _vars_label: RichTextLabel
var _vars_timer := 0.0
const KitchenRules := preload("res://systems/kitchen/kitchen_rules.gd")


func _build_variables_box() -> void:
	var parent: Control = console.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = console.size_flags_vertical
	parent.add_child(row)
	parent.move_child(row, console.get_index())
	console.reparent(row)
	console.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := PanelContainer.new()
	# Grows with the window (about a third of the row) so values aren't cut off.
	box.custom_minimum_size = Vector2(200, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = 0.55
	box.add_theme_stylebox_override("panel", console.get_theme_stylebox("normal"))
	row.add_child(box)
	_vars_label = RichTextLabel.new()
	_vars_label.bbcode_enabled = true
	_vars_label.scroll_active = true
	_vars_label.add_theme_font_override("normal_font", preload("res://scenes/ui/common/ui_art.gd").mono())
	_vars_label.add_theme_font_size_override("normal_font_size", 14)
	_vars_label.add_theme_font_size_override("bold_font_size", 14)
	_vars_label.add_theme_color_override("default_color", Color(0.92, 0.9, 0.85))
	_vars_label.tooltip_text = "Variables: what each box holds right now. Press Step to watch them change line by line."
	box.add_child(_vars_label)
	_refresh_variables()


func _process(delta: float) -> void:
	_update_tab(delta)
	_update_pin()
	if not visible or staff == null or not staff.is_running():
		return
	_vars_timer -= delta
	if _vars_timer <= 0.0:
		_vars_timer = 0.2
		_refresh_variables()


func _refresh_variables() -> void:
	if _vars_label == null:
		return
	var t := "[color=#c9b48f][b]Variables[/b][/color]\n"
	var vars: Array = staff.variables() if staff else []
	if vars.is_empty():
		t += "[color=#8f8270]None yet. Try: int eggs = 3;[/color]"
	for v in vars:
		t += "[color=#7fb4e8]%s[/color] [b]%s[/b] = [color=#ffd98a]%s[/color]\n" % [v.type, v.name, _fmt_value(v.v, v.type)]
	_vars_label.text = t.strip_edges()


func _fmt_value(v, type: String) -> String:
	if v is Array:
		var parts: Array = []
		for i in mini(v.size(), 8):
			parts.append(_fmt_value(v[i], type))
		return "{" + ", ".join(parts) + (", …" if v.size() > 8 else "") + "}"
	match type:
		"char":
			return "'%s'" % String.chr(int(v)) if v is int else str(v)
		"float", "double":
			return "%.2f" % float(v)
		"bool":
			return "true" if v else "false"
	if v is int and v >= 101:
		var nm: String = KitchenRules.name_of(v)
		if nm != "":
			return nm
	return str(v)


func _on_log_added(text: String) -> void:
	console.append_text(text)


func _on_running_changed(running: bool) -> void:
	_refresh_buttons()
	if not running:
		_clear_executing()


func _on_line_changed(line: int) -> void:
	var i := line - 1
	if i == _exec_line:
		return
	_clear_executing()
	if i >= 0 and i < code_edit.get_line_count():
		code_edit.set_line_as_executing(i, true)
		code_edit.set_line_background_color(i, EXEC_LINE_COLOR)
		_exec_line = i


func _on_error_at(line: int, _msg: String) -> void:
	var i := line - 1
	if i >= 0 and i < code_edit.get_line_count():
		code_edit.set_line_background_color(i, ERROR_LINE_COLOR)
		_error_line = i
		code_edit.set_caret_line(i)


func _on_code_changed() -> void:
	if _error_line >= 0:
		_clear_marks()
	_maybe_complete()


# --- Typing helpers: autocomplete and the snippet bar ----------------------------

const C_WORDS := ["int", "float", "char", "bool", "double", "void", "if", "else", "while", "do", "for",
	"switch", "case", "default", "break", "continue", "return", "true", "false", "sizeof", "printf"]
var _snippet_bar: HFlowContainer


## Suggest names after 2 letters of a word (Tab or Enter picks one).
func _maybe_complete() -> void:
	var line := code_edit.get_line(code_edit.get_caret_line())
	var col := code_edit.get_caret_column()
	var i := col
	while i > 0 and (line[i - 1] == "_" or line[i - 1].is_valid_identifier() or line[i - 1].is_valid_int()):
		i -= 1
	var word := line.substr(i, col - i)
	if word.length() >= 2 and not line.substr(0, i).contains("//") and line.substr(0, i).count("\"") % 2 == 0:
		code_edit.request_code_completion()


func _on_completion_requested() -> void:
	var lv: int = GameState.restaurant_level
	for n in Builtins.unlocked(lv):
		code_edit.add_code_completion_option(CodeEdit.KIND_FUNCTION, n + "()", n + "(", Color(0.55, 0.8, 1.0))
	code_edit.add_code_completion_option(CodeEdit.KIND_FUNCTION, "printf()", "printf(", Color(0.55, 0.8, 1.0))
	# Kitchen names: stations, plus the dishes on today's menu and their ingredients.
	var names := {"NOTHING": true}
	for st in KitchenRules.STATIONS:
		names[st] = true
	for d in KitchenRules.menu(lv, GameState.cafe_step):
		names[d] = true
		for ing in KitchenRules.DISHES[d].recipe:
			names[ing] = true
	for k in names:
		code_edit.add_code_completion_option(CodeEdit.KIND_CONSTANT, k, k, Color(1.0, 0.82, 0.5))
	for w in C_WORDS:
		code_edit.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, w, w, Color(1.0, 0.55, 0.6))
	var r := RegEx.new()
	r.compile("\\b(?:int|float|char|bool|double|void)\\s+([A-Za-z_]\\w*)")
	var seen := {}
	for m in r.search_all(code_edit.text):
		var name := m.get_string(1)
		if not seen.has(name) and name != "main":
			seen[name] = true
			code_edit.add_code_completion_option(CodeEdit.KIND_VARIABLE, name, name, Color(0.85, 0.95, 0.75))
	code_edit.update_code_completion_options(false)


## Buttons above the code that insert a ready-made piece of C at the cursor.
## New ones appear as the restaurant level teaches them.
func _build_snippet_bar() -> void:
	_snippet_bar = HFlowContainer.new()
	_snippet_bar.add_theme_constant_override("h_separation", 6)
	_snippet_bar.add_theme_constant_override("v_separation", 4)
	var parent: Control = code_edit.get_parent()
	parent.add_child(_snippet_bar)
	parent.move_child(_snippet_bar, code_edit.get_index())
	_fill_snippet_bar()


func _snippets() -> Array:
	var lv: int = GameState.restaurant_level
	var out: Array = [
		["main", "void main() {\n    \n}\n", "The start of every program"],
		["printf", "printf(\"Hello!\\n\");", "Print a line (the staff member says it)"],
		["variable", "int count = 0;", "Make a variable that stores a number"],
		["cook steps", "go_to(FRIDGE);\npick_up(EGG);\ngo_to(GRILL);\ncook();\ngo_to(ASSEMBLY);\nplate();", "Fetch, cook and plate one ingredient"],
	]
	if lv >= 2:
		out.append(["if", "if (order == EGGSILOG) {\n    \n}", "Do something only when a condition is true"])
		out.append(["if / else", "if (order == EGGSILOG) {\n    \n} else {\n    \n}", "Choose between two blocks"])
		out.append(["switch", "switch (order) {\n    case EGGSILOG:\n        \n        break;\n    default:\n        break;\n}", "Match one value against cases"])
	if lv >= 3:
		out.append(["while", "while (has_order()) {\n    \n}", "Repeat while a condition is true"])
		out.append(["for", "for (int i = 0; i < 3; i++) {\n    \n}", "Repeat a set number of times"])
	if lv >= 4:
		out.append(["array", "int items[8];\nint n = recipe(order, items);", "Many values in one variable"])
	if lv >= 5:
		out.append(["function", "void fetch(int item) {\n    go_to(FRIDGE);\n    pick_up(item);\n}\n", "Write steps once, use them many times"])
	return out


func _fill_snippet_bar() -> void:
	if _snippet_bar == null:
		return
	for c in _snippet_bar.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = "Insert:"
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.79, 0.7, 0.56))
	_snippet_bar.add_child(l)
	for sn in _snippets():
		var b := Button.new()
		b.text = sn[0]
		b.tooltip_text = sn[2]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_constant_override("outline_size", 0)
		for st_name in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.36, 0.22, 0.12) if st_name == "normal" else Color(0.5, 0.32, 0.17)
			sb.border_color = Color(0.62, 0.42, 0.22)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(4)
			sb.content_margin_left = 8
			sb.content_margin_right = 8
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
			b.add_theme_stylebox_override(st_name, sb)
		b.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
		b.pressed.connect(_insert_snippet.bind(sn[1]))
		_snippet_bar.add_child(b)


func _insert_snippet(code: String) -> void:
	var line := code_edit.get_line(code_edit.get_caret_line())
	var indent := ""
	for ch in line:
		if ch == " " or ch == "\t":
			indent += ch
		else:
			break
	if line.strip_edges() != "":
		code_edit.insert_text_at_caret("\n" + indent)
	code_edit.insert_text_at_caret(code.replace("\n", "\n" + indent))
	code_edit.grab_focus()


func _clear_executing() -> void:
	if _exec_line >= 0 and _exec_line < code_edit.get_line_count():
		code_edit.set_line_as_executing(_exec_line, false)
		if _exec_line != _error_line:
			code_edit.set_line_background_color(_exec_line, Color(0, 0, 0, 0))
	_exec_line = -1


func _clear_marks() -> void:
	_clear_executing()
	if _error_line >= 0 and _error_line < code_edit.get_line_count():
		code_edit.set_line_background_color(_error_line, Color(0, 0, 0, 0))
	_error_line = -1


func _log(text: String) -> void:
	console.append_text(text + "\n")


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and is_topmost():
		get_viewport().set_input_as_handled()
		close()


# --- Floating window: move by the title bar, resize by the corner ----------------

func _setup_floating() -> void:
	_panel = $Panel
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_lib_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# If the content needs more room, grow down / right (never up off the screen).
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.grow_horizontal = Control.GROW_DIRECTION_END
	var head: HBoxContainer = $Panel/VBox/HeaderRow
	title.clip_text = true
	# Wrapped text measures its height at its current width: never let it start
	# at 1 px wide (one letter per line would make the window huge).
	hint.custom_minimum_size.x = 420
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.mouse_default_cursor_shape = Control.CURSOR_MOVE
	head.tooltip_text = "Drag to move · double-click to reset"
	head.gui_input.connect(_on_header_input)
	_grip = Control.new()
	_grip.size = Vector2(GRIP, GRIP)
	_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_grip.tooltip_text = "Drag to resize"
	_grip.draw.connect(_draw_grip)
	_grip.gui_input.connect(_on_grip_input)
	add_child(_grip)
	resized.connect(func(): if visible: _apply_rect(_current_rect()))
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _default_rect() -> Rect2:
	var vs := size
	return Rect2(vs.x - 824.0, 24.0, 800.0, minf(vs.y - 48.0, 860.0))


func _current_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)


## Places the window (kept on screen, at least MIN_SIZE) and the Library
## drawer beside it: on the left when there's room, otherwise on the right.
func _apply_rect(r: Rect2) -> void:
	var vs := size
	if r.size == Vector2.ZERO:
		r = _default_rect()
	r.size = r.size.clamp(MIN_SIZE, vs)
	# The title row needs a minimum width: keep the whole window on screen.
	r.size.x = minf(maxf(r.size.x, _panel.get_combined_minimum_size().x), vs.x)
	if r.end.x > vs.x and r.position.x > 0.0:
		r.position.x = maxf(0.0, vs.x - r.size.x)
	r.position.x = clampf(r.position.x, 120.0 - r.size.x, vs.x - 120.0)
	r.position.y = clampf(r.position.y, 0.0, vs.y - 60.0)
	_panel.position = r.position
	_panel.size = r.size
	# Wrapped labels measure their height from the old width: size again once
	# the new width has been laid out, so the window doesn't grow too tall.
	_panel.set_deferred("size", r.size)
	var lib_w := maxf(LIB_WIDTH, _lib_panel.get_combined_minimum_size().x)
	var lib_x := r.position.x - lib_w - 8.0
	if lib_x < 0.0:
		lib_x = minf(r.end.x + 8.0, vs.x - lib_w)
	_lib_panel.position = Vector2(lib_x, r.position.y)
	_lib_panel.size = Vector2(lib_w, r.size.y)
	_lib_panel.set_deferred("size", Vector2(lib_w, r.size.y))
	_grip.position = _panel.position + _panel.size - Vector2(GRIP, GRIP)
	_grip.queue_redraw()


func _on_header_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.double_click:
			_drag = ""
			SettingsManager.code_window = Rect2()
			SettingsManager.save_settings()
			_apply_rect(Rect2())
		elif e.pressed:
			_start_drag("move", e)
		else:
			_end_drag()
	elif e is InputEventMouseMotion and _drag == "move":
		var r := _rect_from
		r.position += e.global_position - _drag_from
		_apply_rect(r)


func _on_grip_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_start_drag("resize", e)
		else:
			_end_drag()
	elif e is InputEventMouseMotion and _drag == "resize":
		var r := _rect_from
		r.size += e.global_position - _drag_from
		_apply_rect(r)


## Marks this as a floating window (Esc closes only the front-most one).
func is_floating_window() -> bool:
	return true


func is_topmost() -> bool:
	var p := get_parent()
	for i in range(p.get_child_count() - 1, -1, -1):
		var c := p.get_child(i)
		if c is Control and c.visible and c.has_method("is_floating_window"):
			return c == self
	return false


func _on_focus_changed(c: Control) -> void:
	if visible and c != null and is_ancestor_of(c):
		move_to_front()


func _start_drag(kind: String, e: InputEvent) -> void:
	move_to_front()
	_drag = kind
	_drag_from = e.global_position
	_rect_from = _current_rect()


func _end_drag() -> void:
	if _drag == "":
		return
	_drag = ""
	SettingsManager.code_window = _current_rect()
	SettingsManager.save_settings()


## Three little diagonal lines in the corner, like a window resize grip.
func _draw_grip() -> void:
	var c := Color(0.95, 0.82, 0.6, 0.9)
	for i in 3:
		var d := 8.0 + i * 7.0
		_grip.draw_line(Vector2(GRIP - 4, GRIP - 4 - d), Vector2(GRIP - 4 - d, GRIP - 4), c, 2.0)


# --- Library drawer: saved Library slots, ready to use in this program -------------

func _build_library_drawer() -> void:
	_lib_toggle = Button.new()
	_lib_toggle.text = "Library"
	_lib_toggle.toggle_mode = true
	_lib_toggle.button_pressed = false  # the Library drawer starts closed
	_lib_toggle.custom_minimum_size = Vector2(0, 40)
	_lib_toggle.add_theme_font_size_override("font_size", 17)
	_lib_toggle.toggled.connect(func(on): _lib_panel.visible = on)
	var head: HBoxContainer = $Panel/VBox/HeaderRow
	head.add_child(_lib_toggle)
	head.move_child(_lib_toggle, close_button.get_index())
	_build_opacity_button(head)
	_build_hide_button(head)

	_lib_panel = PanelContainer.new()
	_lib_panel.theme_type_variation = &"WoodPanel"
	_lib_panel.anchor_left = 1.0
	_lib_panel.anchor_right = 1.0
	_lib_panel.anchor_bottom = 1.0
	_lib_panel.offset_left = -1392.0
	_lib_panel.offset_right = -856.0
	_lib_panel.offset_top = 24.0
	_lib_panel.offset_bottom = -24.0
	add_child(_lib_panel)
	_lib_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_lib_panel.add_child(box)
	var title_l := Label.new()
	title_l.text = "My Library"
	title_l.theme_type_variation = &"HeaderLabel"
	title_l.add_theme_font_size_override("font_size", 24)
	box.add_child(title_l)
	var help := Label.new()
	help.text = "Functions saved in your Library (L). Ticked slots can be called from this program. Insert adds a call where your cursor is."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 420
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(0.9, 0.82, 0.66))
	help.add_theme_constant_override("outline_size", 0)
	box.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_lib_list = VBoxContainer.new()
	_lib_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lib_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_lib_list)


func _fill_library() -> void:
	for c in _lib_list.get_children():
		c.queue_free()
	var mono: Font = preload("res://scenes/ui/common/ui_art.gd").mono()
	var shown := 0
	for i in GameState.library_slots.size():
		var slot: Dictionary = GameState.library_slots[i]
		if str(slot.code).strip_edges() == "":
			continue
		shown += 1
		var head := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = "%d · %s" % [i + 1, slot.name]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_font_size_override("font_size", 18)
		name_l.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
		name_l.clip_text = true
		head.add_child(name_l)
		var use := CheckBox.new()
		use.text = "Use"
		use.button_pressed = slot.enabled
		use.add_theme_font_size_override("font_size", 15)
		use.toggled.connect(func(on): slot.enabled = on)
		head.add_child(use)
		var copy := Button.new()
		copy.text = "Copy code"
		copy.tooltip_text = "Paste this whole slot into the program (your copy can be changed without touching the Library)."
		copy.custom_minimum_size = Vector2(0, 34)
		copy.add_theme_font_size_override("font_size", 14)
		copy.pressed.connect(_copy_slot_code.bind(i, use))
		head.add_child(copy)
		_lib_list.add_child(head)
		var interp := CInterpreter.new()
		var parsed: Dictionary = interp._parse(str(slot.code), 0)
		if not interp.error.is_empty():
			var err := Label.new()
			err.text = "  Has an error (line %d). Fix it in the Library (L)." % int(interp.error.get("line", 0))
			err.add_theme_font_size_override("font_size", 14)
			err.add_theme_color_override("font_color", Color(1, 0.55, 0.45))
			_lib_list.add_child(err)
			continue
		for fname in parsed.functions:
			var fn: Dictionary = parsed.functions[fname]
			var row := HBoxContainer.new()
			var sig := Label.new()
			var params: Array = []
			var args: Array = []
			for prm in fn.params:
				params.append("%s %s" % [prm.type, prm.name])
				args.append(prm.name)
			sig.text = "  %s %s(%s)" % [fn.ret, fname, ", ".join(params)]
			sig.add_theme_font_override("font", mono)
			sig.add_theme_font_size_override("font_size", 14)
			sig.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
			sig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sig.clip_text = true
			sig.tooltip_text = sig.text.strip_edges()
			sig.mouse_filter = Control.MOUSE_FILTER_PASS
			row.add_child(sig)
			var call := "%s(%s)%s" % [fname, ", ".join(args), ";" if fn.ret == "void" else ""]
			var ins := Button.new()
			ins.text = "Insert"
			ins.custom_minimum_size = Vector2(80, 34)
			ins.add_theme_font_size_override("font_size", 14)
			ins.pressed.connect(_insert_call.bind(call, i, use))
			row.add_child(ins)
			_lib_list.add_child(row)
		var sep := HSeparator.new()
		_lib_list.add_child(sep)
	if shown == 0:
		var none := Label.new()
		none.text = "Your Library is empty. Press L (outside this window) to write functions you can reuse."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_font_size_override("font_size", 15)
		_lib_list.add_child(none)


func _insert_call(call: String, slot_index: int, use: CheckBox) -> void:
	var slot: Dictionary = GameState.library_slots[slot_index]
	if not slot.enabled:
		use.button_pressed = true
		_log("[color=#ffd27a]Switched on Library slot \"%s\" so this program can call it.[/color]" % slot.name)
	code_edit.insert_text_at_caret(call)
	code_edit.grab_focus()


func _copy_slot_code(slot_index: int, _use: CheckBox) -> void:
	var slot: Dictionary = GameState.library_slots[slot_index]
	var code := "// Copied from Library slot \"%s\"\n%s\n\n" % [slot.name, str(slot.code).strip_edges()]
	code_edit.set_caret_line(0)
	code_edit.set_caret_column(0)
	code_edit.insert_text_at_caret(code)
	_log("[color=#ffd27a]Copied \"%s\" into this program. This copy is used instead of the Library version, so you can change it freely.[/color]" % slot.name)
	code_edit.grab_focus()


# --- Opacity control (beside the Library button) -----------------------------------

var _opacity_btn: Button
var _opacity_pop: PopupPanel
var _opacity_slider: HSlider


## "◐ 100%" button in the title row: opens a small slider that makes the editor
## (and Library drawer) see-through, 30%-100%, so the kitchen shows behind it.
## The value is saved with the other settings.
func _build_opacity_button(head: HBoxContainer) -> void:
	_opacity_btn = Button.new()
	_opacity_btn.custom_minimum_size = Vector2(0, 40)
	_opacity_btn.focus_mode = Control.FOCUS_NONE
	_opacity_btn.add_theme_font_size_override("font_size", 17)
	_opacity_btn.tooltip_text = "Editor opacity"
	head.add_child(_opacity_btn)
	head.move_child(_opacity_btn, _lib_toggle.get_index())
	_opacity_pop = PopupPanel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.11, 0.08, 0.98)
	sb.border_color = Color(0.93, 0.72, 0.38)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_opacity_pop.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_opacity_pop.add_child(v)
	var l := Label.new()
	l.text = "Editor opacity"
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
	v.add_child(l)
	_opacity_slider = HSlider.new()
	_opacity_slider.custom_minimum_size = Vector2(220, 28)
	_opacity_slider.min_value = 0.3
	_opacity_slider.max_value = 1.0
	_opacity_slider.step = 0.05
	_opacity_slider.value = SettingsManager.code_opacity
	v.add_child(_opacity_slider)
	_opacity_slider.value_changed.connect(func(val: float):
		SettingsManager.code_opacity = val
		_apply_opacity()
		_update_opacity_btn())
	_opacity_pop.popup_hide.connect(SettingsManager.save_settings)
	add_child(_opacity_pop)
	_opacity_btn.pressed.connect(func():
		_opacity_slider.value = SettingsManager.code_opacity
		var r := _opacity_btn.get_global_rect()
		_opacity_pop.popup(Rect2i(Vector2i(int(r.position.x), int(r.end.y) + 4), Vector2i(250, 0))))
	_update_opacity_btn()


func _update_opacity_btn() -> void:
	if _opacity_btn:
		_opacity_btn.text = "◐ %d%%" % roundi(SettingsManager.code_opacity * 100)


# --- Seeing what printf says while the editor is open ------------------------------
# 1. The camera keeps the running staff member beside the editor (game.gd).
# 2. If their thought bubble is still behind the editor, a copy is pinned at
#    the editor's edge.
# 3. "Hide": the editor folds into a tab on the right edge that shows the
#    program's status and last printf; click it to open the editor again.

## Screen rect of the editor window (for the camera).
func window_rect() -> Rect2:
	return _panel.get_global_rect() if _panel else Rect2()


var _pin: PanelContainer
var _pin_label: Label


func _speech_of(s: Node) -> Node2D:
	return s.get("_speech") if s and is_instance_valid(s) else null


func _update_pin() -> void:
	var sp := _speech_of(staff)
	var show_pin := visible and sp != null and sp.visible and String(sp.text) != ""
	var at := Vector2.ZERO
	if show_pin:
		at = sp.get_global_transform_with_canvas().origin
		# The bubble is drawn centred over the staff member: if any good part of
		# it is behind the editor, pin a copy at the editor's edge.
		var font := ThemeDB.fallback_font
		var bw := minf(font.get_string_size(String(sp.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 26.0, 326.0)
		var bub := Rect2(at.x - bw / 2.0, at.y - 60.0, bw, 50.0)
		var cut := bub.intersection(window_rect())
		show_pin = cut.get_area() > bub.get_area() * 0.2
	if not show_pin:
		if _pin:
			_pin.hide()
		return
	if _pin == null:
		_pin = PanelContainer.new()
		_pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.98, 0.92)
		sb.border_color = Color(0.24, 0.13, 0.07)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		sb.shadow_color = Color(0, 0, 0, 0.3)
		sb.shadow_size = 4
		_pin.add_theme_stylebox_override("panel", sb)
		_pin_label = Label.new()
		_pin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pin_label.custom_minimum_size = Vector2(220, 0)
		_pin_label.add_theme_font_size_override("font_size", 17)
		_pin_label.add_theme_color_override("font_color", Color(0.24, 0.13, 0.07))
		_pin.add_child(_pin_label)
		add_child(_pin)
	var text := "%s says: %s" % [staff.staff_name, sp.text]
	if _pin_label.text != text:
		_pin_label.text = text
		_pin.reset_size()
	_pin.show()
	var r := window_rect()
	var vs := get_viewport_rect().size
	var w := minf(_pin.get_combined_minimum_size().x, 340.0)
	_pin.size.x = w
	var x := r.position.x - w - 14.0 if r.position.x > w + 30.0 else r.end.x + 14.0
	_pin.position = Vector2(clampf(x, 8.0, vs.x - w - 8.0), clampf(at.y - 30.0, 90.0, vs.y - 140.0))


var _hide_btn: Button
var _tab: PanelContainer
var _tab_label: Label
var _tab_staff: Staff
var _tab_error := false
var _tab_timer := 0.0


func _build_hide_button(head: HBoxContainer) -> void:
	_hide_btn = Button.new()
	_hide_btn.text = "Hide"
	_hide_btn.custom_minimum_size = Vector2(0, 40)
	_hide_btn.focus_mode = Control.FOCUS_NONE
	_hide_btn.add_theme_font_size_override("font_size", 17)
	_hide_btn.tooltip_text = "Fold the editor into a tab on the right edge (the program keeps running). Click the tab to open it again."
	_hide_btn.pressed.connect(_hide_to_tab)
	head.add_child(_hide_btn)
	head.move_child(_hide_btn, close_button.get_index())


func _hide_to_tab() -> void:
	var s := staff
	close()
	if s:
		_show_tab(s)


func _show_tab(s: Staff) -> void:
	_close_tab()
	_tab_staff = s
	_tab_error = false
	if _tab == null:
		_tab = PanelContainer.new()
		_tab.mouse_filter = Control.MOUSE_FILTER_STOP
		_tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_tab.tooltip_text = "Click to open the code editor again"
		_tab_label = Label.new()
		_tab_label.add_theme_font_size_override("font_size", 18)
		_tab_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_tab_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_tab_label.custom_minimum_size = Vector2(300, 0)
		_tab.add_child(_tab_label)
		_tab.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _tab_staff:
				open(_tab_staff)
				move_to_front())
		get_parent().add_child(_tab)
	if not s.error_at.is_connected(_on_tab_error):
		s.error_at.connect(_on_tab_error)
	_style_tab()
	_refresh_tab()
	_tab.show()


func _close_tab() -> void:
	if _tab_staff and is_instance_valid(_tab_staff) and _tab_staff.error_at.is_connected(_on_tab_error):
		_tab_staff.error_at.disconnect(_on_tab_error)
	_tab_staff = null
	if _tab:
		_tab.hide()


func _on_tab_error(_line: int, _msg: String) -> void:
	_tab_error = true
	_style_tab()
	_refresh_tab()
	# Beginners ("new to C") get the editor back right away so they see the error.
	if not GameState.short_tour and _tab_staff:
		open.call_deferred(_tab_staff)


func _style_tab() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.12, 0.1, 0.95) if _tab_error else Color(0.2, 0.12, 0.08, 0.95)
	sb.border_color = Color(1, 0.55, 0.45) if _tab_error else Color(0.93, 0.72, 0.38)
	sb.set_border_width_all(3)
	sb.border_width_right = 0
	sb.corner_radius_top_left = 10
	sb.corner_radius_bottom_left = 10
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_tab.add_theme_stylebox_override("panel", sb)
	_tab_label.add_theme_color_override("font_color", Color(1, 0.92, 0.85) if _tab_error else Color(1, 0.88, 0.6))


func _refresh_tab() -> void:
	if _tab == null or _tab_staff == null or not is_instance_valid(_tab_staff):
		return
	var s := _tab_staff
	var state := "■ error" if _tab_error else ("▶" if s.is_running() else "■")
	var said := ""
	var sp := _speech_of(s)
	if sp and String(sp.text) != "":
		said = ": " + String(sp.text)
	_tab_label.text = "◂ %s %s%s" % [s.staff_name, state, said]
	var vs := get_viewport_rect().size
	_tab.reset_size()
	_tab.position = Vector2(vs.x - _tab.size.x, vs.y * 0.42)


func _update_tab(delta: float) -> void:
	if _tab == null or not _tab.visible:
		return
	_tab_timer -= delta
	if _tab_timer <= 0.0:
		_tab_timer = 0.25
		_refresh_tab()


# --- Clickable function list: click a function for what it does + example ------------

const CRef := preload("res://data/help/c_reference.gd")
var _fn_bar: RichTextLabel
var _fn_card: PanelContainer


func _update_fn_bar() -> void:
	if _fn_bar == null:
		_fn_bar = RichTextLabel.new()
		_fn_bar.bbcode_enabled = true
		_fn_bar.fit_content = true
		_fn_bar.scroll_active = false
		_fn_bar.add_theme_font_size_override("normal_font_size", 15)
		_fn_bar.add_theme_font_size_override("bold_font_size", 15)
		_fn_bar.add_theme_color_override("default_color", Color(0.9, 0.82, 0.66))
		_fn_bar.meta_underlined = true
		_fn_bar.meta_clicked.connect(func(m): _show_fn_card(String(m)))
		hint.add_sibling(_fn_bar)
		hint.hide()
	var links: Array = []
	for n in Builtins.unlocked(GameState.restaurant_level):
		links.append("[url=%s][color=#ffd27a]%s()[/color][/url]" % [n, n])
	links.append("[url=printf][color=#ffd27a]printf()[/color][/url]")
	_fn_bar.text = "Functions [color=#a8957a](click one for help)[/color]: %s\nMenu: %s" % [", ".join(links), ", ".join(GameState.current_menu())]


func _show_fn_card(id: String) -> void:
	var e: Dictionary = {}
	for x in CRef.entries():
		if x.id == id:
			e = x
			break
	if e.is_empty():
		return
	if is_instance_valid(_fn_card):
		_fn_card.queue_free()
	_fn_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.09, 0.07, 0.98)
	sb.border_color = Color(0.93, 0.72, 0.38)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 14)
	_fn_card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_fn_card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = String(e.get("syntax", e.title)).split("\n")[0]
	t.add_theme_font_override("font", preload("res://scenes/ui/common/ui_art.gd").mono())
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1, 0.82, 0.48))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var about := Label.new()
	about.text = e.about
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(420, 0)
	about.add_theme_font_size_override("font_size", 16)
	about.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	v.add_child(about)
	var ex := Label.new()
	ex.text = e.example
	ex.add_theme_font_override("font", preload("res://scenes/ui/common/ui_art.gd").mono())
	ex.add_theme_font_size_override("font_size", 14)
	ex.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	var exbox := PanelContainer.new()
	var eb := StyleBoxFlat.new()
	eb.bg_color = Color(0.06, 0.05, 0.07)
	for side in ["left", "right", "top", "bottom"]:
		eb.set("content_margin_" + side, 8)
	exbox.add_theme_stylebox_override("panel", eb)
	exbox.add_child(ex)
	v.add_child(exbox)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var ins := Button.new()
	ins.text = "Insert %s" % String(e.get("syntax", "")).split("\n")[0]
	ins.focus_mode = Control.FOCUS_NONE
	ins.add_theme_font_size_override("font_size", 16)
	ins.pressed.connect(func():
		_insert_snippet(String(e.get("syntax", "")).split("\n")[0])
		_fn_card.queue_free())
	row.add_child(ins)
	var close_b := Button.new()
	close_b.text = "Close"
	close_b.focus_mode = Control.FOCUS_NONE
	close_b.add_theme_font_size_override("font_size", 16)
	close_b.pressed.connect(func(): _fn_card.queue_free())
	row.add_child(close_b)
	add_child(_fn_card)
	# Next to the editor, at the height of the function list.
	await get_tree().process_frame
	if not is_instance_valid(_fn_card):
		return
	var r := window_rect()
	var w := _fn_card.size.x
	var x := r.position.x - w - 10.0 if r.position.x > w + 20.0 else r.end.x + 10.0
	_fn_card.position = Vector2(clampf(x, 8.0, size.x - w - 8.0), clampf(r.position.y + 60.0, 8.0, size.y - _fn_card.size.y - 8.0))


# --- Staff portrait in the title row (face from their walk sheet) ----------------

var _face_box: PanelContainer
var _face: TextureRect


func _update_face() -> void:
	if _face_box == null:
		_face_box = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.9, 0.78)
		sb.border_color = Color(0.93, 0.72, 0.38)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(8)
		for side in ["left", "right", "top", "bottom"]:
			sb.set("content_margin_" + side, 2)
		_face_box.add_theme_stylebox_override("panel", sb)
		_face_box.mouse_filter = Control.MOUSE_FILTER_PASS
		_face_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_face = TextureRect.new()
		_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_face.custom_minimum_size = Vector2(32, 48)
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face_box.add_child(_face)
		title.add_sibling(_face_box)
		title.get_parent().move_child(_face_box, title.get_index())
	var tex: Texture2D = PixelArt.character("character/staff", staff.staff_name)
	if tex == null:
		_face_box.hide()
		return
	# First frame of a walk sheet (standing, facing down), the whole character.
	var fw: float = PixelArt.FRAME_WIDTH if tex.resource_path.ends_with("_sheet.png") else tex.get_width()
	var fh: float = tex.get_height() / 4.0 if tex.resource_path.ends_with("_sheet.png") else tex.get_height()
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, fw, fh)
	_face.texture = at
	_face_box.tooltip_text = staff.staff_name
	_face_box.show()

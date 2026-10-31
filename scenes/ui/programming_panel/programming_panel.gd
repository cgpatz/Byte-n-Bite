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
const MIN_SIZE := Vector2(460, 380)
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
	_setup_editor()
	PixelArt.button_icon(run_button, ["start_dark", "start"])
	run_button.pressed.connect(_on_run_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	_build_continue_button()
	close_button.pressed.connect(close)
	SettingsManager.changed.connect(_apply_font_size)
	code_edit.text_changed.connect(_on_code_changed)
	code_edit.gui_input.connect(_on_code_zoom_input)
	var zoom_hint := Label.new()
	zoom_hint.text = "Zoom: Ctrl + mouse wheel  ·  Ctrl+0 resets"
	zoom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zoom_hint.add_theme_font_size_override("font_size", 12)
	zoom_hint.add_theme_color_override("font_color", Color(0.7, 0.6, 0.48))
	zoom_hint.add_theme_constant_override("outline_size", 0)
	zoom_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	code_edit.add_sibling(zoom_hint)
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
	title.tooltip_text = "%s's program" % staff.staff_name
	var cost: int = GameState.staff_upgrade_cost(staff.staff_name)
	_upgrade.text = "Upgrade %d" % cost if cost > 0 else "Max Lv"
	_upgrade.disabled = cost <= 0


func _setup_editor() -> void:
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
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


func _on_code_zoom_input(e: InputEvent) -> void:
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
	show()
	_apply_rect(SettingsManager.code_window)
	code_edit.grab_focus()


func close() -> void:
	if staff:
		staff.program_source = code_edit.text
		GameState.staff_programs[staff.staff_name] = code_edit.text
	_clear_executing()
	_disconnect_staff()
	hide()
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
	return Rect2(vs.x - 724.0, 24.0, 700.0, minf(vs.y - 48.0, 860.0))


func _current_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)


## Places the window (kept on screen, at least MIN_SIZE) and the Library
## drawer beside it: on the left when there's room, otherwise on the right.
func _apply_rect(r: Rect2) -> void:
	var vs := size
	if r.size == Vector2.ZERO:
		r = _default_rect()
	r.size = r.size.clamp(MIN_SIZE, vs)
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
	_lib_toggle.button_pressed = true
	_lib_toggle.custom_minimum_size = Vector2(110, 40)
	_lib_toggle.add_theme_font_size_override("font_size", 17)
	_lib_toggle.toggled.connect(func(on): _lib_panel.visible = on)
	var head: HBoxContainer = $Panel/VBox/HeaderRow
	head.add_child(_lib_toggle)
	head.move_child(_lib_toggle, close_button.get_index())

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
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "DejaVu Sans Mono", "Courier New", "monospace"])
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

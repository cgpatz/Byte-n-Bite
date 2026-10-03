extends Control
## "Buy this?" pop-up for in-world upgrades: the manager walks to an upgrade
## spot (Upgrade Board, an empty table spot, a table, the Café door or menu
## board), presses E, and this asks before spending coins.
## E / Enter = buy, Esc = cancel.

signal closed

var _title: Label
var _body: Label
var _cost: Label
var _yes: Button
var _no: Button
var _on_yes: Callable
## Pick-one mode (ask_choice): one button per option instead of Buy.
var _choices: HBoxContainer
var _on_pick: Callable


func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.01, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WoodPanel"
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 22)
	_body.add_theme_color_override("font_color", Color(0.95, 0.88, 0.74))
	_body.add_theme_constant_override("outline_size", 0)
	box.add_child(_body)
	_cost = Label.new()
	_cost.add_theme_font_size_override("font_size", 24)
	_cost.add_theme_constant_override("outline_size", 0)
	box.add_child(_cost)
	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 14)
	_choices.hide()
	box.add_child(_choices)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	_yes = Button.new()
	_yes.custom_minimum_size = Vector2(220, 64)
	_yes.theme_type_variation = &"StartButton"
	_yes.add_theme_font_size_override("font_size", 26)
	_yes.pressed.connect(_confirm)
	row.add_child(_yes)
	_no = Button.new()
	_no.text = "Cancel"
	_no.custom_minimum_size = Vector2(200, 64)
	_no.add_theme_font_size_override("font_size", 26)
	_no.pressed.connect(close)
	row.add_child(_no)


## Shows the question. cost = coins it takes (0 = free / nothing to buy);
## on_yes runs when the player confirms and can afford it.
func ask(title: String, body: String, cost: int, on_yes: Callable, yes_text := "Buy", locked := false) -> void:
	_title.text = title
	_body.text = body
	_on_yes = on_yes
	_choices.hide()
	_yes.show()
	var afford: bool = GameState.money >= cost and not locked
	_yes.text = "%s (%d)" % [yes_text, cost] if cost > 0 else yes_text
	_yes.disabled = not afford
	if cost > 0:
		_cost.text = "You have %d coins." % GameState.money if GameState.money >= cost \
			else "You have %d coins: %d more needed." % [GameState.money, cost - GameState.money]
		_cost.add_theme_color_override("font_color", Color(0.75, 0.95, 0.6) if GameState.money >= cost else Color(1, 0.55, 0.45))
	else:
		_cost.text = ""
	show()
	move_to_front()
	(_yes if afford else _no).grab_focus()


## Like ask(), but the player picks one of `options` (e.g. a specialization);
## on_pick(option) runs when they pick one and can afford `cost`.
func ask_choice(title: String, body: String, cost: int, options: Array, on_pick: Callable) -> void:
	ask(title, body, cost, Callable())
	_yes.hide()
	_on_pick = on_pick
	for c in _choices.get_children():
		c.queue_free()
	var afford: bool = GameState.money >= cost
	for o in options:
		var b := Button.new()
		b.text = str(o)
		b.custom_minimum_size = Vector2(170, 64)
		b.theme_type_variation = &"StartButton"
		b.add_theme_font_size_override("font_size", 24)
		b.disabled = not afford
		b.pressed.connect(_pick.bind(str(o)))
		_choices.add_child(b)
	_choices.show()
	_no.grab_focus()


func _pick(option: String) -> void:
	var f := _on_pick
	close()
	if f.is_valid():
		f.call(option)


func _confirm() -> void:
	if not _yes.visible or _yes.disabled:
		return
	var f := _on_yes
	close()
	if f.is_valid():
		f.call()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_confirm()

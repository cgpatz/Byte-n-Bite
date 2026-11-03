extends Control
## In-game HUD: coins, restaurant level, interaction prompt, short messages.

@onready var money_label: Label = %MoneyLabel
@onready var level_label: Label = %LevelLabel
@onready var prompt: PanelContainer = %Prompt
@onready var prompt_label: Label = %PromptLabel
@onready var toast: Label = %Toast

const PixelArt := preload("res://scenes/art/pixel_art.gd")
## HUD icons are 16×16 art shown 2× (32 px).
const UI_ICON_SCALE := 2

## Emitted by the HUD buttons: "recipe_book", "library" or "stats".
signal window_requested(which: String)

var _toast_tween: Tween
var _player_label: Label
var _exp_bar: ProgressBar
var _special: Button
## Goals + challenges checklist (top left).
var _goals: PanelContainer
var _goals_tab: Control
var _chal_label: RichTextLabel
const LevelChallenges := preload("res://systems/challenges/level_challenges.gd")
const LevelGoals := preload("res://systems/goals/level_goals.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const Art := preload("res://scenes/ui/common/ui_art.gd")
const Market := preload("res://systems/market/market_rules.gd")
const Paper := preload("res://scenes/ui/common/paper.gd")
## Market button (M) and delivery timers (top right, under the window buttons).
var _market_button: Button
var _deliveries_box: VBoxContainer
var _delivery_tick := 0.0
var _arrived: Control
var _arrived_tween: Tween


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.restaurant_level_changed.connect(_on_level_changed)
	_on_money_changed(GameState.money)
	_on_level_changed(GameState.restaurant_level)
	_build_player_level()
	_build_buttons()
	_build_special()
	_build_challenges()
	_build_deliveries()
	_build_zoom()
	var hint := get_node_or_null("ControlsHint") as Label
	if hint:
		hint.hide()  # keys are shown in each button's tooltip and in the tutorial
	_style_top_bar()
	GameState.player_exp_changed.connect(_on_player_exp_changed)
	_on_player_exp_changed(GameState.player_level, GameState.player_exp, GameState.exp_needed())


## Manager level + EXP: a rounded bar with "Lv 1   40/100 EXP" under it.
func _build_player_level() -> void:
	var row := money_label.get_parent()
	var col := VBoxContainer.new()
	col.name = "ExpColumn"
	col.add_theme_constant_override("separation", 2)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	_exp_bar = ProgressBar.new()
	_exp_bar.name = "ExpBar"
	_exp_bar.custom_minimum_size = Vector2(170, 20)
	_exp_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.15, 0.12)
	bg.set_corner_radius_all(10)
	bg.set_border_width_all(3)
	bg.border_color = Paper.INK
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.42, 0.72, 0.33)
	fill.set_corner_radius_all(8)
	_exp_bar.add_theme_stylebox_override("background", bg)
	_exp_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(_exp_bar)
	_player_label = Paper.label("", 15, Paper.INK_SOFT)
	_player_label.name = "PlayerLevelLabel"
	col.add_child(_player_label)


## Top bar (Paper Notebook): coin + coins, house + "Lv 1 · Tiny Stall",
## manager + EXP bar, on a taped paper strip.
func _style_top_bar() -> void:
	var plank := money_label.get_parent().get_parent() as PanelContainer
	plank.theme_type_variation = &""
	plank.add_theme_stylebox_override("panel", Paper.panel(Vector4(24, 30, 32, 14)))
	var row := money_label.get_parent() as HBoxContainer
	row.add_theme_constant_override("separation", 12)
	money_label.add_theme_font_size_override("font_size", 32)
	money_label.add_theme_color_override("font_color", Paper.RED)
	money_label.add_theme_constant_override("outline_size", 0)
	money_label.add_theme_font_override("font", Art.bold_font())
	money_label.custom_minimum_size.x = 70
	level_label.add_theme_font_size_override("font_size", 24)
	level_label.add_theme_color_override("font_color", Paper.INK)
	level_label.add_theme_constant_override("outline_size", 0)
	level_label.add_theme_font_override("font", Art.bold_font())
	var coin := Paper.icon("coin")
	row.add_child(coin)
	row.move_child(coin, money_label.get_index())
	var sep1 := _ink_sep()
	row.add_child(sep1)
	row.move_child(sep1, level_label.get_index())
	var house := Paper.icon("house")
	row.add_child(house)
	row.move_child(house, level_label.get_index())
	var exp_col := row.get_node("ExpColumn")
	var sep2 := _ink_sep()
	row.add_child(sep2)
	row.move_child(sep2, exp_col.get_index())
	var mgr := Paper.icon("manager")
	row.add_child(mgr)
	row.move_child(mgr, exp_col.get_index())
	plank.reset_size()
	plank.position = Vector2(16, 12)


func _ink_sep() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(Paper.INK, 0.35)
	c.custom_minimum_size = Vector2(3, 40)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Icon buttons in the top-right corner (no text): Market, Lessons, Recipes,
## Library, Stats, Pause. Each has a tooltip and a small key badge.
const WINDOW_BUTTONS := [
	["market", "market", "M", "Market: go to the Night Market to buy ingredients"],
	["tutorial", "lessons", "T", "Lessons: Chef Miso's C lessons and Kitchen Functions"],
	["recipe_book", "recipes", "R", "Recipe Book: dishes and their ingredients"],
	["library", "library", "L", "Library: your reusable functions"],
	["stats", "stats", "Tab", "Stats: your progress and staff"],
	["pause", "pause", "Esc", "Pause menu"],
]


## HUD icon buttons by window key (the gameplay guide points at them).
var window_buttons := {}


## Rounded paper icon buttons (84 x 80), each with a key chip under it.
func _build_buttons() -> void:
	var row := HBoxContainer.new()
	row.name = "WindowButtons"
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for spec in WINDOW_BUTTONS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -6)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var b := Paper.icon_button(spec[1], spec[0] == "market")
		b.tooltip_text = "%s  (%s)" % [spec[3], spec[2]]
		b.pressed.connect(func(): window_requested.emit(spec[0]))
		col.add_child(b)
		var chip := Paper.key_chip(spec[2], 14)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(chip)
		window_buttons[spec[0]] = b
		if spec[0] == "market":
			_market_button = b
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	row.offset_top = 10
	row.offset_bottom = row.offset_top + row.get_combined_minimum_size().y


## Puts assets/ui/hud/<key>.png in front of a HUD item, if that file exists.
func _add_icon(before: Control, key: String) -> void:
	var tex := PixelArt.find(["res://assets/ui/hud/%s.png" % key])
	if tex == null:
		return
	var icon := TextureRect.new()
	icon.name = key.to_pascal_case() + "Icon"
	icon.texture = tex
	icon.custom_minimum_size = tex.get_size() * UI_ICON_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := before.get_parent()
	row.add_child(icon)
	row.move_child(icon, before.get_index())


func _on_player_exp_changed(level: int, exp_now: int, needed: int) -> void:
	if needed <= 0:
		_exp_bar.max_value = 1
		_exp_bar.value = 1
		_exp_bar.tooltip_text = "Manager Lv %d: max level!" % level
		_player_label.text = "Lv %d   MAX" % level
	else:
		_exp_bar.max_value = needed
		_exp_bar.value = exp_now
		_exp_bar.tooltip_text = "Manager Lv %d: EXP %d / %d" % [level, exp_now, needed]
		_player_label.text = "Lv %d   %d/%d EXP" % [level, exp_now, needed]


func _on_money_changed(amount: int) -> void:
	money_label.text = "%d" % amount
	money_label.tooltip_text = "Coins"


func _on_level_changed(level: int) -> void:
	level_label.text = "Lv %d · %s" % [level, GameState.level_data().display_name]
	level_label.tooltip_text = "Restaurant level"
	_refresh_special()
	_refresh_challenges()


## Quest Log (left drawer, G): 1) Chef Miso quest, one C idea at a time, in
## order; 2) the Level Challenge, harder tasks that combine the level's ideas,
## locked until Chef Miso's quests are done; 3) Restaurant Goals (sales and
## profit, always running); 4) optional Mastery quests for bonus coins.
## The Challenge and the Goals unlock the next restaurant upgrade.
const MisoQuests := preload("res://data/help/miso_quests.gd")
const QL_W := 412.0  # the quest card width (460) minus the paper panel padding
# Paper Notebook colours: dark ink on cream paper.
const QL_INK := Color("3a2a1e")
const QL_SOFT := Color("6b5442")
const QL_GOLD := Color("e0a63a")
const QL_GREEN := Color("4f8a3a")
var _ql_body: VBoxContainer
var _ql_scroll: ScrollContainer
var _ql_example: PopupPanel
var _ql_example_text: Label


func _build_challenges() -> void:
	# A drawer on the left edge: a sideways tab, and the log beside it when open.
	_goals = PanelContainer.new()
	_goals.add_theme_stylebox_override("panel", Paper.panel(Vector4(24, 30, 24, 16)))
	_goals.position = Vector2(0, 200)
	_goals.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_goals)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_goals.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var t := Label.new()
	t.text = "QUEST LOG"
	t.add_theme_font_override("font", Art.serif())
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Paper.INK)
	t.add_theme_constant_override("outline_size", 0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_chal_label = RichTextLabel.new()   # level name, right side of the header
	_chal_label.bbcode_enabled = true
	_chal_label.fit_content = true
	_chal_label.scroll_active = false
	_chal_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_chal_label.custom_minimum_size = Vector2(150, 0)
	_chal_label.add_theme_font_size_override("normal_font_size", 13)
	_chal_label.add_theme_constant_override("outline_size", 0)
	_chal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_chal_label)
	_ql_scroll = ScrollContainer.new()
	_ql_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ql_scroll.custom_minimum_size = Vector2(QL_W, 0)
	outer.add_child(_ql_scroll)
	_ql_body = VBoxContainer.new()
	_ql_body.add_theme_constant_override("separation", 8)
	_ql_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ql_scroll.add_child(_ql_body)
	_goals_tab = preload("res://scenes/ui/hud/side_tab.gd").new()
	_goals_tab.size = Vector2(34, 200)
	_goals_tab.tooltip_text = "Quest Log: click or press G to open / close"
	_goals_tab.pressed.connect(toggle_goals)
	add_child(_goals_tab)
	_goals_tab.hide()  # the quest card's "All quests" button (or G) opens the log
	_build_quest_card()
	GameState.challenge_completed.connect(func(_l, _i): _refresh_challenges())
	GameState.goal_reached.connect(func(_l, _i): _refresh_challenges())
	GameState.stats_changed.connect(_refresh_challenges)
	GameState.quests_changed.connect(_refresh_challenges)
	_refresh_challenges()


## Opens / closes the goals and challenges list (remembered between games).
func toggle_goals() -> void:
	SettingsManager.goals_open = not SettingsManager.goals_open
	SettingsManager.save_settings()
	_refresh_challenges()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G \
			and _goals_tab != null and _goals_tab.visible:
		var f := get_viewport().gui_get_focus_owner()
		if f is TextEdit or f is LineEdit:
			return
		get_viewport().set_input_as_handled()
		toggle_goals()


func _refresh_challenges() -> void:
	if _goals == null:
		return
	var lv: int = GameState.restaurant_level
	var goals: Array = LevelGoals.for_level(lv)
	var chals: Array = LevelChallenges.for_level(lv)
	var quests: Array = MisoQuests.for_level(lv)
	var any := not (goals.is_empty() and chals.is_empty() and quests.is_empty())
	_goals_tab.visible = false
	_goals.visible = any
	_refresh_quest_card()
	if not any:
		return
	for c in _ql_body.get_children():
		c.queue_free()
	_chal_label.text = "[right][color=#6b5442]Lv %d · %s[/color][/right]" % [lv, GameState.level_data().display_name]
	var miso_left := quests.size() - GameState.miso_progress(lv)
	var unlocked: bool = GameState.miso_done(lv)
	# 1) Chef Miso quest
	if not quests.is_empty():
		_ql_body.add_child(_ql_miso_card(lv, quests))
	# 2) Level Challenge
	if not chals.is_empty():
		var cl: int = GameState.challenges_left(lv).size()
		var sec := _ql_section("Level Challenge", "%d / %d" % [chals.size() - cl, chals.size()], Color(0.95, 0.62, 0.3))
		if not unlocked:
			sec.add_child(_ql_line("[img=16x16]res://assets/ui/windows/recipe_book/lock.png[/img] [color=#6b5442]Finish Chef Miso's quests to unlock (%d left).[/color]" % miso_left, 14))
		else:
			for g in chals:
				var done: bool = GameState.challenge_done(lv, g.id)
				sec.add_child(_ql_item(g.title, g.task, "+%d coins · +%d EXP" % [g.coins, g.exp], done, g.how))
		_ql_body.add_child(sec.get_parent())
	# 3) Restaurant Goals
	if not goals.is_empty():
		var gl: int = GameState.goals_left(lv).size()
		var sec2 := _ql_section("Restaurant Goals", "%d / %d" % [goals.size() - gl, goals.size()], Color(0.45, 0.7, 0.9))
		for g in goals:
			var done2: bool = GameState.goal_reached_at(lv, g.id)
			sec2.add_child(_ql_goal(g.title, GameState.goal_progress(g, lv), int(g.n), done2))
		_ql_body.add_child(sec2.get_parent())
	# 4) Mastery (optional)
	var mastery: Array = LevelChallenges.mastery_for(lv)
	if not mastery.is_empty():
		var sec3 := _ql_section("Mastery (optional)", "bonus", Color(0.75, 0.55, 0.95))
		for m in mastery:
			if unlocked:
				sec3.add_child(_ql_item("★ " + m.title, m.task, "+%d coins · +%d EXP" % [m.coins, m.exp], GameState.mastery_done(lv, m.id), m.how))
			else:
				sec3.add_child(_ql_line("[color=#8a7a66]★ %s: unlocks with the Level Challenge.[/color]" % m.title, 13))
		_ql_body.add_child(sec3.get_parent())
	if lv < GameState.MAX_RESTAURANT_LEVEL and GameState.goals_left(lv).is_empty() and GameState.challenges_left(lv).is_empty() and unlocked:
		_ql_body.add_child(_ql_line("[color=#3f7a2e][b]All done: upgrade the restaurant at the chalkboard![/b][/color]", 15))
	var open: bool = SettingsManager.goals_open
	var left: int = GameState.goals_left(lv).size() + GameState.challenges_left(lv).size() + miso_left
	_goals_tab.text = "%s Quests  ·  %d left" % ["◂" if open else "▸", left]
	_goals.visible = open
	_ql_layout.call_deferred()


## Height follows the content, up to the space under the HUD (then it scrolls).
func _ql_layout() -> void:
	if _ql_body == null:
		return
	var vs := get_viewport_rect().size
	# The full log opens under the quest card (left column), so the middle of
	# the screen stays clear; it scrolls when it is taller than the space left.
	var top := 200.0
	if _qcard:
		top = _qcard.position.y + _qcard.size.y + 10.0
	var want := _ql_body.get_combined_minimum_size().y
	_ql_scroll.custom_minimum_size = Vector2(QL_W, want)
	_goals.reset_size()
	# Shrink the scroll area by however much the panel would run off the bottom.
	var extra := _goals.get_combined_minimum_size().y - want   # header + panel padding
	var room := maxf(160.0, vs.y - top - 16.0 - extra)
	if want > room:
		_ql_scroll.custom_minimum_size = Vector2(QL_W, room)
		_goals.reset_size()
	if _qcard:
		_goals.position = Vector2(_qcard.position.x, top)


## A section card: coloured header bar + VBox for its rows (returned).
func _ql_section(title: String, count: String, accent: Color) -> VBoxContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.98, 0.92, 0.92)
	sb.border_color = accent.darkened(0.3)
	sb.border_width_left = 5
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var l := Label.new()
	l.text = title
	l.add_theme_font_override("font", Art.bold_font())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", accent.darkened(0.45))
	l.add_theme_constant_override("outline_size", 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var c := Label.new()
	c.text = count
	c.add_theme_font_size_override("font_size", 13)
	c.add_theme_color_override("font_color", QL_SOFT)
	c.add_theme_constant_override("outline_size", 0)
	h.add_child(c)
	return v


## The Chef Miso card: portrait, "Quest 3 / 7", the topic, what to do, the
## progress pips and an Example button.
func _ql_miso_card(lv: int, quests: Array) -> Control:
	var k: int = GameState.miso_progress(lv)
	var v := _ql_section("Chef Miso Quest", "%d / %d" % [mini(k + 1, quests.size()) if k < quests.size() else quests.size(), quests.size()], Color(0.98, 0.78, 0.35))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var face := TextureRect.new()
	face.texture = load("res://assets/ui/windows/tutorial/mentor.png")
	face.custom_minimum_size = Vector2(44, 60)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	if k >= quests.size():
		col.add_child(_ql_line("[color=#3f7a2e][b]All quests done! ✔[/b][/color]\n[color=#6b5442]The Level Challenge is open.[/color]", 14))
	else:
		var q: Dictionary = quests[k]
		var who := "your staff"
		if game and game.has_method("_staff_list") and not game._staff_list().is_empty():
			who = game._staff_list()[0].staff_name
		col.add_child(_ql_line("[b][color=#8a4b12]%s[/color][/b]" % q.topic, 15))
		col.add_child(_ql_line(q.do.replace("{who}", who), 13))
	# Progress pips.
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	for n in quests.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(maxf(8.0, (QL_W - 60.0) / quests.size() - 4.0), 6)
		d.color = QL_GREEN if n < k else (QL_GOLD if n == k else Color(0.23, 0.16, 0.12, 0.15))
		d.tooltip_text = quests[n].topic
		pips.add_child(d)
	v.add_child(pips)
	if k < quests.size():
		var ex := Paper.button("Show example", false, 15)
		ex.custom_minimum_size = Vector2(0, 44)
		ex.size_flags_horizontal = Control.SIZE_SHRINK_END
		ex.pressed.connect(_ql_show_example.bind(quests[k], ex))
		v.add_child(ex)
	return v.get_parent()


## Run pressed: the example pop-up has done its job, put it away.
func hide_examples() -> void:
	if _ql_example and _ql_example.visible:
		_ql_example.hide()


func _ql_show_example(q: Dictionary, from: Control) -> void:
	if _ql_example == null:
		_ql_example = PopupPanel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("2b211b")
		sb.border_color = Paper.INK
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		_ql_example.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		_ql_example.add_child(v)
		_ql_example_text = Label.new()
		_ql_example_text.add_theme_font_override("font", Art.mono())
		_ql_example_text.add_theme_font_size_override("font_size", 16)
		_ql_example_text.add_theme_color_override("font_color", Color(0.85, 0.95, 0.78))
		v.add_child(_ql_example_text)
		var copy := Paper.button("Copy", false, 15)
		copy.custom_minimum_size = Vector2(0, 44)
		copy.size_flags_horizontal = Control.SIZE_SHRINK_END
		copy.pressed.connect(func():
			DisplayServer.clipboard_set(_ql_example_text.get_meta("code", ""))
			copy.text = "Copied!")
		v.add_child(copy)
		add_child(_ql_example)
	var code: String = q.example
	_ql_example_text.text = "%s\n\n%s" % [q.topic, code]
	_ql_example_text.set_meta("code", code)
	var btn: Button = _ql_example.get_child(0).get_child(1)
	btn.text = "Copy"
	var r := from.get_global_rect()
	_ql_example.popup(Rect2i(Vector2i(int(r.end.x) + 10, int(r.position.y) - 40), Vector2i(0, 0)))


func _ql_line(bbcode: String, fs: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_font_size_override("bold_font_size", fs)
	r.add_theme_color_override("default_color", QL_INK)
	r.add_theme_constant_override("outline_size", 0)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.text = bbcode
	return r


## A challenge row: tick box, title, reward, and the task (hover for an example).
func _ql_item(title: String, task: String, reward: String, done: bool, how: String) -> Control:
	var r := _ql_line("%s [b][color=%s]%s[/color][/b]  [color=#6b5442][font_size=12]%s[/font_size][/color]%s" % [
		"☑" if done else "☐", "#3f7a2e" if done else "#3a2a1e", title, reward,
		"" if done else "\n[color=#6b5442][font_size=12]%s[/font_size][/color]" % task], 14)
	r.tooltip_text = "%s\n\nExample: %s" % [task, how]
	return r


## A goal row: title, n / total and a small progress bar.
func _ql_goal(title: String, have: int, total: int, done: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(_ql_line("%s [color=%s]%s[/color]  [color=#6b5442]%d / %d[/color]" % [
		"☑" if done else "☐", "#3f7a2e" if done else "#3a2a1e", title, have, total], 14))
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, total)
	bar.value = have
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.23, 0.16, 0.12, 0.15)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = QL_GREEN if done else Color("3f7fb0")
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	v.add_child(bar)
	return v


## Today's Special (Restaurant Levels 1-2): click to change what every customer orders.
func _build_special() -> void:
	# A gold rounded pill; the quest card (below) holds it.
	_special = Paper.button("", true, 22)
	_special.custom_minimum_size = Vector2(0, 56)
	_special.tooltip_text = "Until Restaurant Level 2, every customer orders Today's Special.\nClick to pick another dish from your menu."
	_special.pressed.connect(func(): GameState.next_special())
	GameState.special_changed.connect(func(_d): _refresh_special())
	_refresh_special()


func _refresh_special() -> void:
	if _special == null:
		return
	_special.visible = GameState.special_active()
	_special.text = "Today's Special: %s ▸" % Kitchen.title_of(GameState.todays_special)


## Shows "[E] <prompt>" for the focused object, or hides it when target is null.
func show_prompt_for(target: Node) -> void:
	if target == null:
		prompt.hide()
		return
	# The prompt now shows as a thought bubble above the manager (manager.gd).
	prompt.hide()


func show_toast(text: String) -> void:
	if text == "":
		return
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	toast.modulate.a = 1.0
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)


## "ADMIN RUN" badge under the coins, shown only in admin runs.
func set_admin_badge(on: bool) -> void:
	var badge := get_node_or_null("AdminBadge") as Label
	if badge:
		badge.visible = on


# --- Market and deliveries -----------------------------------------------------------

func set_in_market(on: bool) -> void:
	if _market_button:
		_market_button.tooltip_text = "Back to the restaurant  (M)" if on else "Market: go to the Night Market to buy ingredients  (M)"
		_market_button.modulate = Color(1.0, 0.9, 0.55) if on else Color.WHITE


func _build_deliveries() -> void:
	_deliveries_box = VBoxContainer.new()
	_deliveries_box.name = "Deliveries"
	# Bottom right, above the zoom control (the Orders hang at the top right).
	_deliveries_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_deliveries_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_deliveries_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_deliveries_box.offset_left = -304
	_deliveries_box.offset_right = -16
	_deliveries_box.offset_top = -190
	_deliveries_box.offset_bottom = -190
	_deliveries_box.alignment = BoxContainer.ALIGNMENT_END
	_deliveries_box.add_theme_constant_override("separation", 8)
	_deliveries_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_deliveries_box)
	refresh_deliveries()


func _process(delta: float) -> void:
	_delivery_tick -= delta
	if _delivery_tick <= 0.0:
		_delivery_tick = 0.25
		refresh_deliveries()
		refresh_orders()


## One row per delivery on its way, plus a "Here!" row while crates wait.
func refresh_deliveries() -> void:
	if _deliveries_box == null:
		return
	for c in _deliveries_box.get_children():
		c.queue_free()
	for dv in GameState.deliveries:
		if dv.get("waiting", false):
			_delivery_row("Full!", 1.0, Color(1, 0.6, 0.3), "Waiting: the delivery area is full. Claim crates to make room.", true)
		else:
			var p: float = 1.0 - float(dv.left) / maxf(float(dv.total), 0.01)
			_delivery_row(Market.clock(dv.left), p, Art.GOLD, "%d items on the way" % Market.items_in(dv.cart))
	if not GameState.crates.is_empty():
		_delivery_row("Here!", 1.0, Color(0.55, 0.95, 0.45), "%d crate(s) in the delivery area: walk there and press E on each." % GameState.crates.size(), true)


func _delivery_row(text: String, progress: float, col: Color, tip: String, full := false) -> void:
	# assets/delivery/delivery_timer_*.png: a 72 × 16 panel (truck at the left,
	# bar at art x 37–68), shown 4×. The time goes between the truck and the bar.
	var row := Control.new()
	row.custom_minimum_size = Vector2(288, 64)
	row.tooltip_text = tip
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_deliveries_box.add_child(row)
	var bg := TextureRect.new()
	bg.texture = PixelArt.find(["res://assets/delivery/delivery_timer_full.png" if full else "res://assets/delivery/delivery_timer_0.png"])
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = Vector2(288, 64)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	if not full:
		var fill := ColorRect.new()
		fill.color = Color(0.93, 0.8, 0.1)
		fill.position = Vector2(148, 28)
		fill.size = Vector2(roundf(124 * clampf(progress, 0.0, 1.0) / 4.0) * 4.0, 16)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(fill)
	var l := Label.new()
	l.text = text
	l.position = Vector2(58, 14)
	l.size = Vector2(90, 36)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20 if text.length() > 5 else 24)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)


## "Delivery arrived!" note at the top of the screen.
func show_delivery_arrived(crates: int) -> void:
	if _arrived == null:
		_arrived = Control.new()
		_arrived.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arrived.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_arrived.offset_left = -244
		_arrived.offset_top = 160
		_arrived.size = Vector2(488, 144)
		add_child(_arrived)
		var bg := TextureRect.new()
		bg.texture = PixelArt.find(["res://assets/delivery/arrived_popup.png"])
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.size = Vector2(488, 144)
		_arrived.add_child(bg)
		var truck := TextureRect.new()
		truck.texture = PixelArt.find(["res://assets/delivery/delivery_truck_open.png", "res://assets/delivery/delivery_truck.png"])
		truck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		truck.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		truck.position = Vector2(18, 22)
		truck.size = Vector2(160, 100)
		_arrived.add_child(truck)
		Art.label(_arrived, "Delivery arrived!", Vector2(196, 28), 28, Art.INK, false, 280, HORIZONTAL_ALIGNMENT_LEFT, Art.serif())
		var sub := Art.label(_arrived, "", Vector2(198, 76), 18, Art.INK_SOFT, false, 280)
		sub.name = "Sub"
	(_arrived.get_node("Sub") as Label).text = "%d crate%s in the delivery area" % [crates, "" if crates == 1 else "s"]
	_arrived.modulate.a = 1.0
	_arrived.show()
	if _arrived_tween:
		_arrived_tween.kill()
	_arrived_tween = create_tween()
	_arrived_tween.tween_interval(3.0)
	_arrived_tween.tween_property(_arrived, "modulate:a", 0.0, 0.6)


# --- Notification cards ---------------------------------------------------------------

var _notes: VBoxContainer

## A card that pops in at the top of the screen with an icon, a title and a
## line of help, then fades after a few seconds (click it to close).
func notify(title: String, body: String, icon: Texture2D = null, accent := Color(0.85, 0.55, 0.2), seconds := 6.0) -> void:
	if _notes == null:
		_notes = VBoxContainer.new()
		_notes.name = "Notifications"
		_notes.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_notes.offset_left = -300
		_notes.offset_right = 300
		_notes.offset_top = 320
		_notes.add_theme_constant_override("separation", 8)
		_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Own layer above the windows, so Chef Miso's hints are never hidden.
		var layer := CanvasLayer.new()
		layer.layer = 15
		add_child(layer)
		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(holder)
		holder.add_child(_notes)
	# The same message already on screen: don't stack a copy.
	var key := title + "|" + body
	for c in _notes.get_children():
		if c.has_meta("key") and c.get_meta("key") == key and not c.is_queued_for_deletion():
			return
	Sfx.play("pop", -4.0)
	# One notice at a time: a new one replaces the old (no mixed messages).
	while _notes.get_child_count() >= 1:
		var old := _notes.get_child(0)
		_notes.remove_child(old)
		old.queue_free()
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.98, 0.94, 0.86)
	st.border_color = accent
	st.border_width_left = 10
	st.border_width_top = 3
	st.border_width_right = 3
	st.border_width_bottom = 3
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 6
	card.add_theme_stylebox_override("panel", st)
	card.custom_minimum_size = Vector2(_place_notes(), 0)
	card.set_meta("key", key)
	card.set_meta("title", title)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			card.queue_free())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	if icon:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(56, 56)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", Art.bold_font())
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", accent.darkened(0.25))
	t.add_theme_constant_override("outline_size", 0)
	col.add_child(t)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Art.INK)
	b.add_theme_constant_override("outline_size", 0)
	col.add_child(b)
	_notes.add_child(card)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	tw.tween_interval(seconds)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(card.queue_free)


## Notices sit near the top, in the free space between the quest card and the
## code editor (never over the code). Returns the card width to use.
func _place_notes() -> float:
	var vs := get_viewport_rect().size
	var left := 0.0
	if _qcard and _qcard.visible:
		left = _qcard.position.x + _qcard.size.x + 12.0
	var right := vs.x
	var pp = game.programming_panel if game else null
	if pp and pp.visible and pp.has_method("window_rect"):
		right = minf(right, (pp.window_rect() as Rect2).position.x - 12.0)
	var w := clampf(right - left - 16.0, 380.0, 600.0)
	var cx := (left + right) / 2.0 if right - left >= 396.0 else vs.x / 2.0
	_notes.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_notes.position = Vector2(cx - w / 2.0, 112.0)
	_notes.size = Vector2(w, 0)
	return w


## Removes notices whose title starts with prefix (e.g. an old "not quite yet"
## once that quest is done), so the player never sees mixed messages.
func clear_notices(prefix: String) -> void:
	if _notes == null:
		return
	for c in _notes.get_children():
		if String(c.get_meta("title", "")).begins_with(prefix):
			_notes.remove_child(c)
			c.queue_free()


# --- Orders (top right, under the icon buttons) ---------------------------------------
# A paper tab "ORDERS (n)" and hanging paper tickets: a red badge with the table
# number (or the posted ticket #), the dish picture and name, and a patience
# bar (green > yellow > red). Only the tab shows when there are no orders.

## Set by Game so the board can read the order queue.
var game: Node
var _board: VBoxContainer
var _board_title: Label
var _board_row: HFlowContainer
var _board_sig := ""
var _board_open := true
var _ticket_bars: Array = []  # [ProgressBar, customer]
const TICKET := Vector2(100, 136)
var _board_toggle: Button


func _build_order_board() -> void:
	_board = VBoxContainer.new()
	_board.name = "OrderBoard"
	_board.add_theme_constant_override("separation", 6)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_board)
	var tab := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Paper.FACE_HOVER
	sb.border_color = Paper.INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 8
	sb.content_margin_top = 0
	sb.content_margin_bottom = 2
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 3
	tab.add_theme_stylebox_override("panel", sb)
	tab.size_flags_horizontal = Control.SIZE_SHRINK_END
	tab.tooltip_text = "Orders waiting, oldest first. Badge = table number (# = ticket posted with post_order()); ? = order not taken yet. The bar is the customer's patience."
	_board.add_child(tab)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	tab.add_child(trow)
	_board_title = Paper.label("ORDERS (0)", 17, Paper.INK, true)
	_board_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(_board_title)
	_board_toggle = Button.new()
	_board_toggle.flat = true
	_board_toggle.focus_mode = Control.FOCUS_NONE
	_board_toggle.add_theme_font_size_override("font_size", 16)
	_board_toggle.add_theme_color_override("font_color", Paper.INK)
	_board_toggle.add_theme_color_override("font_hover_color", Paper.RED)
	_board_toggle.tooltip_text = "Hide or show the order tickets"
	_board_toggle.pressed.connect(func(): set_orders_open(not _board_open))
	trow.add_child(_board_toggle)
	_board_row = HFlowContainer.new()
	_board_row.alignment = FlowContainer.ALIGNMENT_END
	_board_row.add_theme_constant_override("h_separation", 10)
	_board_row.add_theme_constant_override("v_separation", 10)
	_board_row.custom_minimum_size = Vector2(TICKET.x * 5 + 40, 0)
	_board_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_board_row)
	set_orders_open(SettingsManager.orders_open)


func _place_board() -> void:
	var row: Control = get_node_or_null("WindowButtons")
	var top: float = (row.position.y + row.size.y + 8.0) if row else 120.0
	_board.reset_size()
	var w: float = maxf(_board.get_combined_minimum_size().x, TICKET.x * 5 + 40)
	_board.position = Vector2(get_viewport_rect().size.x - w - 14.0, top)
	_board.size.x = w


## Kept for older callers: the board now shrinks to its tab by itself.
func set_orders_open(on: bool) -> void:
	_board_open = on
	if SettingsManager.orders_open != on:
		SettingsManager.orders_open = on
		SettingsManager.save_settings()
	if _board_row:
		_board_row.visible = on
	if _board_toggle:
		_board_toggle.text = "▾" if on else "▸"
	if _board:
		_place_board()


func refresh_orders() -> void:
	if _board == null:
		_build_order_board()
	if game == null:
		return
	var list: Array = game.orders.duplicate()
	var sig := ""
	for o in list:
		sig += "%s%s%s%s%s%d;" % [o.dish, o.taken, o.posted, o.ticket, o.claimed_by != null or o.serving != null, int(o.get("left", 1))]
	if sig != _board_sig:
		_board_sig = sig
		for c in _board_row.get_children():
			c.queue_free()
		_ticket_bars.clear()
		_board_title.text = "ORDERS (%d)" % list.size()
		for o in list:
			_board_row.add_child(_order_tile(o))
		_place_board()
	# Patience bars move every refresh.
	for tb in _ticket_bars:
		var bar: ProgressBar = tb[0]
		var c = tb[1]
		if c == null or not is_instance_valid(c) or not is_instance_valid(bar):
			continue
		var left: float = clampf(1.0 - float(c.waited) / maxf(float(c.patience), 0.01), 0.0, 1.0)
		bar.value = left
		var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			fill.bg_color = Color(0.42, 0.72, 0.33) if left > 0.5 else (Color(0.93, 0.76, 0.2) if left > 0.25 else Color(0.84, 0.27, 0.22))


func _order_tile(o: Dictionary) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = TICKET + Vector2(10, 12)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var t := PanelContainer.new()
	t.position = Vector2(10, 12)
	t.size = TICKET
	t.custom_minimum_size = TICKET
	var busy: bool = o.claimed_by != null or o.serving != null
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.97, 0.88) if (o.taken or o.posted) else Color(0.88, 0.84, 0.78)
	sb.border_color = Color(0.32, 0.6, 0.26) if busy else Paper.INK
	sb.set_border_width_all(4 if busy else 3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 12
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	t.add_theme_stylebox_override("panel", sb)
	holder.add_child(t)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(v)
	var c = o.customer
	if o.taken or o.posted:
		var ic := TextureRect.new()
		ic.texture = Art.dish_art(o.dish)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(76, 48)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
		var left_n := int(o.get("left", 1))
		var nm := Paper.label(Kitchen.title_of(o.dish) + (" ×%d" % left_n if left_n > 1 else ""), 14, Paper.INK, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(nm)
		holder.tooltip_text = "%s%s%s%s" % [Kitchen.title_of(o.dish), "  ×%d plates left (of %d)" % [left_n, int(o.get("qty", 1))] if int(o.get("qty", 1)) > 1 else "", "  (ticket #%d)" % o.ticket if o.posted else "", "  · being made" if busy else ""]
	else:
		var q := Paper.label("?", 40, Paper.INK_SOFT, true)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.custom_minimum_size.y = 66
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(q)
		holder.tooltip_text = "Order not taken yet: use take_order()"
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.3, 0.24, 0.2)
	bg.set_corner_radius_all(7)
	bg.set_border_width_all(2)
	bg.border_color = Paper.INK
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.42, 0.72, 0.33)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	v.add_child(bar)
	if c != null and is_instance_valid(c):
		_ticket_bars.append([bar, c])
	else:
		bar.visible = false
	# Red badge: table number (or the posted ticket number).
	var badge_text := "?"
	if o.posted:
		badge_text = "#%d" % o.ticket
	elif c != null and is_instance_valid(c) and c.get("seat") is Dictionary:
		var key := String(c.seat.get("key", ""))
		if key.begins_with("t"):
			badge_text = str(int(key.substr(1).get_slice("_", 0)) + 1)
		else:
			badge_text = "S"
	var badge := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Paper.RED
	bsb.border_color = Paper.INK
	bsb.set_border_width_all(3)
	bsb.set_corner_radius_all(22)
	bsb.content_margin_left = 10
	bsb.content_margin_right = 10
	bsb.content_margin_top = 2
	bsb.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", bsb)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := Paper.label(badge_text, 16, Color(1, 0.97, 0.92), true)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(bl)
	badge.position = Vector2(0, 0)
	badge.custom_minimum_size = Vector2(36, 36)
	holder.add_child(badge)
	return holder


# --- Zoom control (bottom right): - / + and the current zoom (4x / 5x / 6x) -----------

var _zoom_box: PanelContainer
var _zoom_label: Label
const ZOOM_NAMES := ["4×", "5×", "6×"]


func _build_zoom() -> void:
	_zoom_box = PanelContainer.new()
	_zoom_box.name = "ZoomControl"
	_zoom_box.add_theme_stylebox_override("panel", Paper.panel(Vector4(18, 30, 18, 10)))
	_zoom_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_zoom_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_zoom_box.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for d in [-1, 1]:
		var b := Paper.button("−" if d < 0 else "+", false, 26)
		b.custom_minimum_size = Vector2(56, 52)
		b.tooltip_text = "Zoom out (mouse wheel down)" if d < 0 else "Zoom in (mouse wheel up)"
		b.pressed.connect(func():
			if game and game.has_method("set_zoom_step"):
				game.set_zoom_step(SettingsManager.zoom_step + d))
		row.add_child(b)
	_zoom_label = Paper.label("", 18, Paper.INK)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_zoom_label)
	on_zoom_changed(SettingsManager.zoom_step)
	_zoom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)


func on_zoom_changed(step: int) -> void:
	if _zoom_label:
		_zoom_label.text = ZOOM_NAMES[clampi(step, 0, 2)]


# --- Quest card (left, under the top bar) -------------------------------------------
# "QUEST k/n" tab, the current Chef Miso quest (title, task, progress), Example
# and All quests buttons, and Today's Special at the bottom. ▾ folds it to one
# line (remembered).

var _qcard: PanelContainer
var _qc_v: VBoxContainer
const SEG_DONE := Color(0.42, 0.66, 0.33)
const SEG_TODO := Color(0.85, 0.78, 0.62)


func _build_quest_card() -> void:
	_qcard = PanelContainer.new()
	_qcard.name = "QuestCard"
	_qcard.mouse_filter = Control.MOUSE_FILTER_STOP
	_qcard.custom_minimum_size = Vector2(460, 0)
	add_child(_qcard)
	_qc_v = VBoxContainer.new()
	_qc_v.add_theme_constant_override("separation", 8)
	_qcard.add_child(_qc_v)


func _qc_who() -> String:
	if game and game.has_method("_staff_list") and not game._staff_list().is_empty():
		return game._staff_list()[0].staff_name
	return "your staff"


func _refresh_quest_card() -> void:
	if _qcard == null:
		return
	for c in _qc_v.get_children():
		if c != _special:
			_qc_v.remove_child(c)
			c.queue_free()
	if _special and _special.get_parent():
		_special.get_parent().remove_child(_special)
	var lv: int = GameState.restaurant_level
	var quests: Array = MisoQuests.for_level(lv)
	var k: int = GameState.miso_progress(lv)
	var n := quests.size()
	var done_all := k >= n
	var title := ""
	var task := ""
	if n == 0:
		title = "Restaurant goals"
		task = "Open your Quest Log to see what's next."
	elif done_all:
		title = "All quests done! ✔"
		var left: Array = GameState.challenges_left(lv)
		if left.is_empty():
			task = "Finish the goals, then upgrade at the chalkboard."
		else:
			var c0 = left[0]
			var ct: String = String(c0.get("title", "")) if c0 is Dictionary else String(LevelChallenges.find(lv, String(c0)).get("title", ""))
			task = "Level Challenge: %s" % ct
	else:
		title = quests[k].topic
		task = _plain(String(quests[k].do).replace("{who}", _qc_who()))
	var tab_text := "QUEST %d/%d" % [mini(k + 1, n), n] if n > 0 else "QUESTS"
	var collapsed: bool = SettingsManager.quest_collapsed
	var paper := Paper.panel(Vector4(22, 30, 22, 16) if not collapsed else Vector4(20, 24, 20, 10))
	_qcard.add_theme_stylebox_override("panel", paper)
	if collapsed:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_qc_v.add_child(row)
		row.add_child(Paper.icon("chef"))
		var l := Paper.label("Quest %d/%d · %s" % [mini(k + 1, n), n, title] if n > 0 else title, 20, Paper.RED, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		row.add_child(l)
		var open_b := Paper.button("▸", false, 18)
		open_b.tooltip_text = "Show the quest card"
		open_b.custom_minimum_size = Vector2(52, 44)
		open_b.pressed.connect(_toggle_quest_card)
		row.add_child(open_b)
	else:
		var head := HBoxContainer.new()
		_qc_v.add_child(head)
		var tab := PanelContainer.new()
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Paper.RED
		tsb.set_corner_radius_all(8)
		tsb.content_margin_left = 14
		tsb.content_margin_right = 14
		tsb.content_margin_top = 2
		tsb.content_margin_bottom = 4
		tab.add_theme_stylebox_override("panel", tsb)
		tab.add_child(Paper.label(tab_text, 17, Color(1, 0.96, 0.9), true))
		tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(tab)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(sp)
		var fold := Paper.button("▾", false, 18)
		fold.tooltip_text = "Fold the quest card to one line"
		fold.custom_minimum_size = Vector2(52, 44)
		fold.pressed.connect(_toggle_quest_card)
		head.add_child(fold)
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 10)
		_qc_v.add_child(row2)
		var face := Paper.icon("chef")
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row2.add_child(face)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		row2.add_child(col)
		var tl := Paper.label(title, 26, SEG_DONE.darkened(0.2) if done_all else Paper.RED, true)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(tl)
		var tk := Paper.label(task, 18, Paper.INK)
		tk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tk.custom_minimum_size.x = 340
		col.add_child(tk)
		if n > 0:
			var segs := HBoxContainer.new()
			segs.add_theme_constant_override("separation", 6)
			_qc_v.add_child(segs)
			for i in n:
				var seg := Panel.new()
				seg.custom_minimum_size = Vector2(0, 12)
				seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var ssb := StyleBoxFlat.new()
				ssb.bg_color = SEG_DONE if i < k else (Paper.RED if i == k else SEG_TODO)
				ssb.set_corner_radius_all(6)
				seg.add_theme_stylebox_override("panel", ssb)
				seg.tooltip_text = quests[i].topic
				segs.add_child(seg)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 10)
		_qc_v.add_child(btns)
		if not done_all and n > 0:
			var ex := Paper.button("Example", false, 18)
			ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ex.custom_minimum_size.y = 52
			ex.pressed.connect(_ql_show_example.bind(quests[k], ex))
			btns.add_child(ex)
		var all := Paper.button("All quests %s" % ("◂" if SettingsManager.goals_open else "▸"), false, 18)
		all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all.custom_minimum_size.y = 52
		all.tooltip_text = "Quest Log: Level Challenge, goals and Mastery quests (G)"
		all.pressed.connect(toggle_goals)
		btns.add_child(all)
	if _special:
		_qc_v.add_child(_special)
		_refresh_special()
	_qcard.reset_size()
	_place_quest_card.call_deferred()


func _place_quest_card() -> void:
	var plank := money_label.get_parent().get_parent() as Control
	_qcard.position = Vector2(16, plank.position.y + plank.size.y + 10)
	_qcard.reset_size()
	_ql_layout()


func _toggle_quest_card() -> void:
	SettingsManager.quest_collapsed = not SettingsManager.quest_collapsed
	SettingsManager.save_settings()
	_refresh_quest_card()


## BBCode -> plain text for labels.
func _plain(bb: String) -> String:
	var r := RegEx.new()
	r.compile("\\[/?[a-z_]+[^\\]]*\\]")
	return r.sub(bb, "", true)



# --- Shift receipt (game.gd sends one every few dishes) -------------------------

var _receipt: PanelContainer


func show_receipt(no: int, place: String, shift: Dictionary) -> void:
	if is_instance_valid(_receipt):
		_receipt.queue_free()
	_receipt = PanelContainer.new()
	_receipt.add_theme_stylebox_override("panel", Paper.receipt(18))
	_receipt.mouse_filter = Control.MOUSE_FILTER_STOP
	_receipt.tooltip_text = "Click to close"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_receipt.add_child(v)
	var w := 30
	var lines: Array = []
	lines.append(_center("BYTE N' BITE", w))
	lines.append(_center(place.to_upper(), w))
	lines.append(_center(" SHIFT RECEIPT #%d " % no, w, "-"))
	var total := 0
	for d in shift.dishes:
		var n := int(shift.dishes[d])
		total += n
		lines.append(_cols("%s x%d" % [Kitchen.title_of(d), n], "", w))
	lines.append("-".repeat(w))
	lines.append(_cols("Dishes served", str(total), w))
	lines.append(_cols("Coins earned", str(int(shift.coins)), w))
	lines.append(_cols("Programs run", str(int(shift.runs)), w))
	lines.append(_cols("Bugs fixed", str(int(shift.fixed)), w))
	var ideas: Array = shift.ideas.keys()
	lines.append("-".repeat(w))
	lines.append("C you used:")
	lines.append("  " + (", ".join(ideas) if not ideas.is_empty() else "kitchen commands"))
	lines.append(_center(" Thank you, chef! ", w, "-"))
	var l := Label.new()
	l.text = "\n".join(lines)
	l.add_theme_font_override("font", Art.mono())
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Paper.INK)
	l.add_theme_constant_override("outline_size", 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	v.add_child(l)
	add_child(_receipt)
	_receipt.reset_size()
	var vs := get_viewport_rect().size
	_receipt.position = Vector2((vs.x - _receipt.size.x) / 2.0, vs.y - _receipt.size.y - 40)
	var r := _receipt
	r.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and is_instance_valid(r):
			r.queue_free())
	Sfx.play("pop", -4.0)
	# Prints out like a receipt, stays a while, then fades.
	r.pivot_offset = Vector2(r.size.x / 2.0, r.size.y)
	r.scale = Vector2(1, 0.05)
	var tw := r.create_tween()
	tw.tween_property(r, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(12.0)
	tw.tween_property(r, "modulate:a", 0.0, 0.6)
	tw.tween_callback(r.queue_free)


func _center(t: String, w: int, fill := " ") -> String:
	var pad := maxi(0, w - t.length())
	return fill.repeat(pad / 2) + t + fill.repeat(pad - pad / 2)


func _cols(a: String, b: String, w: int) -> String:
	return a + " ".repeat(maxi(1, w - a.length() - b.length())) + b

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
	var hint := get_node_or_null("ControlsHint") as Label
	if hint:
		hint.hide()  # keys are shown in each button's tooltip and in the tutorial
	_add_icon(money_label, "coin")
	_add_icon(level_label, "restaurant")
	_add_icon(_player_label, "manager_level")
	_add_icon(_exp_bar, "exp")
	GameState.player_exp_changed.connect(_on_player_exp_changed)
	_on_player_exp_changed(GameState.player_level, GameState.player_exp, GameState.exp_needed())


## Manager level + EXP bar, added next to coins and restaurant level.
func _build_player_level() -> void:
	var row := money_label.get_parent()
	_player_label = Label.new()
	_player_label.name = "PlayerLevelLabel"
	_player_label.label_settings = money_label.label_settings
	for key in ["font_size"]:
		if money_label.has_theme_font_size_override(key):
			_player_label.add_theme_font_size_override(key, money_label.get_theme_font_size(key))
	_player_label.theme_type_variation = money_label.theme_type_variation
	row.add_child(_player_label)
	_exp_bar = ProgressBar.new()
	_exp_bar.name = "ExpBar"
	_exp_bar.custom_minimum_size = Vector2(180, 22)
	_exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_exp_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.08, 0.06)
	bg.set_corner_radius_all(6)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.35, 0.22, 0.12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.55, 0.85, 0.4)
	fill.set_corner_radius_all(6)
	_exp_bar.add_theme_stylebox_override("background", bg)
	_exp_bar.add_theme_stylebox_override("fill", fill)
	row.add_child(_exp_bar)


## Icon buttons in the top-right corner (no text): Market, Lessons, Recipes,
## Library, Stats, Pause. Each has a tooltip and a small key badge.
const WINDOW_BUTTONS := [
	["market", "market", "M", "Market: go to the Night Market to buy ingredients"],
	["tutorial", "tutorial", "T", "Lessons: Chef Miso's C lessons and Kitchen Functions"],
	["recipe_book", "recipe_book", "R", "Recipe Book: dishes and their ingredients"],
	["library", "library", "L", "Library: your reusable functions"],
	["stats", "stats", "Tab", "Stats: your progress and staff"],
	["pause", "pause", "Esc", "Pause menu"],
]


## HUD icon buttons by window key (the gameplay guide points at them).
var window_buttons := {}


func _build_buttons() -> void:
	var row := HBoxContainer.new()
	row.name = "WindowButtons"
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -680
	row.offset_right = -24
	row.offset_top = 24
	row.offset_bottom = 104
	row.alignment = BoxContainer.ALIGNMENT_END
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(row)
	for spec in WINDOW_BUTTONS:
		var b := _icon_button(spec[1], spec[2], spec[3])
		b.pressed.connect(func(): window_requested.emit(spec[0]))
		row.add_child(b)
		window_buttons[spec[0]] = b
		if spec[0] == "market":
			_market_button = b


func _icon_button(icon_key: String, key: String, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(80, 80)
	b.tooltip_text = "%s  (%s)" % [tip, key]
	b.icon = PixelArt.find(["res://assets/ui/icons/%s.png" % icon_key])
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	var badge := Label.new()
	badge.text = key
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", Color(1, 0.93, 0.8))
	badge.add_theme_constant_override("outline_size", 4)
	badge.add_theme_color_override("font_outline_color", Color(0.16, 0.08, 0.04))
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -40
	badge.offset_top = -26
	badge.offset_right = -6
	badge.offset_bottom = -4
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)
	return b


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
	_player_label.text = "Manager Lv %d" % level
	if needed <= 0:
		_exp_bar.max_value = 1
		_exp_bar.value = 1
		_exp_bar.tooltip_text = "Max level!"
	else:
		_exp_bar.max_value = needed
		_exp_bar.value = exp_now
		_exp_bar.tooltip_text = "EXP %d / %d" % [exp_now, needed]


func _on_money_changed(amount: int) -> void:
	money_label.text = "Coins: %d" % amount


func _on_level_changed(level: int) -> void:
	level_label.text = "Restaurant Lv %d" % level
	_refresh_special()
	_refresh_challenges()


## Goals (sell dishes, earn profit) and Challenges (programming tasks) for this
## level, under Today's Special. Both unlock the next upgrade. Hover for hints.
func _build_challenges() -> void:
	# A drawer on the left edge: a sideways tab, and the list beside it when open.
	_goals = PanelContainer.new()
	_goals.theme_type_variation = &"WoodPanel"
	_goals.position = Vector2(0, 200)
	_goals.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_goals)
	_chal_label = RichTextLabel.new()
	_chal_label.bbcode_enabled = true
	_chal_label.fit_content = true
	_chal_label.scroll_active = false
	_chal_label.custom_minimum_size = Vector2(300, 0)
	_chal_label.add_theme_font_size_override("normal_font_size", 15)
	_chal_label.add_theme_font_size_override("bold_font_size", 16)
	_chal_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_goals.add_child(_chal_label)
	_goals_tab = preload("res://scenes/ui/hud/side_tab.gd").new()
	_goals_tab.size = Vector2(34, 200)
	_goals_tab.tooltip_text = "Goals & Challenges: click or press G to open / close"
	_goals_tab.pressed.connect(toggle_goals)
	add_child(_goals_tab)
	GameState.challenge_completed.connect(func(_l, _i): _refresh_challenges())
	GameState.goal_reached.connect(func(_l, _i): _refresh_challenges())
	GameState.stats_changed.connect(_refresh_challenges)
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
	var any := not (goals.is_empty() and chals.is_empty())
	_goals_tab.visible = any
	_goals.visible = any
	if not any:
		return
	var t := ""
	var tips: Array = []
	if not goals.is_empty():
		var gl: int = GameState.goals_left(lv).size()
		t += "[b][color=#ffd98a]Level %d goals[/color][/b]  [color=#c9b48f](%d / %d)[/color]\n" % [lv, goals.size() - gl, goals.size()]
		for g in goals:
			var done: bool = GameState.goal_reached_at(lv, g.id)
			t += "%s [color=%s]%s[/color]  [color=#c9b48f]%d / %d[/color]\n" % [
				"☑" if done else "☐", "#9fd18a" if done else "#f2e3c4", g.title,
				GameState.goal_progress(g, lv), g.n]
	if not chals.is_empty():
		var cl: int = GameState.challenges_left(lv).size()
		t += "[b][color=#ffd98a]Challenges[/color][/b]  [color=#c9b48f](%d / %d)[/color]\n" % [chals.size() - cl, chals.size()]
		for g in chals:
			var done: bool = GameState.challenge_done(lv, g.id)
			t += "%s [color=%s]%s[/color]  [color=#c9b48f]+%d coins · +%d EXP[/color]\n" % [
				"☑" if done else "☐", "#9fd18a" if done else "#f2e3c4", g.title, g.coins, g.exp]
			if not done:
				tips.append("%s: %s\n   e.g. %s" % [g.title, g.task, g.how])
	if lv < GameState.MAX_RESTAURANT_LEVEL and GameState.goals_left(lv).is_empty() and GameState.challenges_left(lv).is_empty():
		t += "[color=#9fd18a]All done: upgrade at the chalkboard![/color]"
	_chal_label.text = t.strip_edges()
	var open: bool = SettingsManager.goals_open
	var left: int = GameState.goals_left(lv).size() + GameState.challenges_left(lv).size()
	_goals_tab.text = "%s Goals  ·  %d left" % ["◂" if open else "▸", left]
	_goals.visible = open
	_goals.reset_size()
	_goals_tab.position = Vector2(_goals.size.x - 4 if open else 0.0, _goals.position.y)
	_goals.tooltip_text = "\n\n".join(tips) if not tips.is_empty() else "Goals count dishes sold and coins earned at this level."


## Today's Special (Restaurant Levels 1-2): click to change what every customer orders.
func _build_special() -> void:
	_special = Art.button(self, "", Rect2(24, 128, 470, 60), true, 22)
	_special.focus_mode = Control.FOCUS_NONE
	_special.tooltip_text = "Until Restaurant Level 2, every customer orders Today's Special.\nClick to pick another dish from your menu."
	_special.pressed.connect(func(): GameState.next_special())
	GameState.special_changed.connect(func(_d): _refresh_special())
	_refresh_special()


func _refresh_special() -> void:
	if _special == null:
		return
	_special.visible = GameState.special_active()
	_special.text = "Today's Special: %s  ▸" % Kitchen.title_of(GameState.todays_special)


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
	_deliveries_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_deliveries_box.offset_left = -312
	_deliveries_box.offset_right = -24
	_deliveries_box.offset_top = 150
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
		add_child(_notes)
	while _notes.get_child_count() >= 3:
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
	card.custom_minimum_size = Vector2(600, 0)
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


# --- Order board (serving counter orders, 3 columns × 4 rows, scrolls) ---------------

## Set by Game so the board can read the order queue.
var game: Node
var _board: PanelContainer
var _board_grid: GridContainer
var _board_title: Label
var _board_scroll: ScrollContainer
var _board_sig := ""
const BOARD_COLS := 3
const BOARD_ROWS := 4
const TILE := Vector2(96, 92)


func _build_order_board() -> void:
	_board = PanelContainer.new()
	_board.name = "OrderBoard"
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.2, 0.12, 0.08, 0.93)
	st.border_color = Color(0.1, 0.05, 0.03)
	st.set_border_width_all(4)
	st.set_corner_radius_all(6)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 10
	_board.add_theme_stylebox_override("panel", st)
	_board.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var w := BOARD_COLS * TILE.x + (BOARD_COLS - 1) * 8 + 20 + 14
	var h := BOARD_ROWS * TILE.y + (BOARD_ROWS - 1) * 8 + 60
	_board.offset_left = -w - 24
	_board.offset_right = -24
	_board.offset_top = -h - 24
	_board.offset_bottom = -24
	add_child(_board)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_board.add_child(v)
	_board_title = Label.new()
	_board_title.text = "Orders"
	_board_title.add_theme_font_size_override("font_size", 22)
	_board_title.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
	_board_title.tooltip_text = "Orders waiting at the serving counter, oldest first. # = ticket posted with post_order(); ? = order not taken yet. Scroll for more."
	_board_title.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(_board_title)
	_board_scroll = ScrollContainer.new()
	_board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_board_scroll.custom_minimum_size = Vector2(BOARD_COLS * TILE.x + (BOARD_COLS - 1) * 8 + 14, BOARD_ROWS * TILE.y + (BOARD_ROWS - 1) * 8)
	v.add_child(_board_scroll)
	_board_grid = GridContainer.new()
	_board_grid.columns = BOARD_COLS
	_board_grid.add_theme_constant_override("h_separation", 8)
	_board_grid.add_theme_constant_override("v_separation", 8)
	_board_scroll.add_child(_board_grid)


func refresh_orders() -> void:
	if _board == null:
		_build_order_board()
	if game == null:
		return
	var list: Array = game.orders.duplicate()
	# Posted tickets first (queue order), then the rest in arrival order.
	var sig := ""
	for o in list:
		sig += "%s%s%s%s%s;" % [o.dish, o.taken, o.posted, o.ticket, o.claimed_by != null or o.serving != null]
	if sig == _board_sig:
		return
	_board_sig = sig
	for c in _board_grid.get_children():
		c.queue_free()
	_board_title.text = "Orders (%d)" % list.size() if not list.is_empty() else "Orders: none yet"
	for o in list:
		_board_grid.add_child(_order_tile(o))


func _order_tile(o: Dictionary) -> Control:
	var t := PanelContainer.new()
	t.custom_minimum_size = TILE
	var busy: bool = o.claimed_by != null or o.serving != null
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.95, 0.75) if o.posted else (Color(0.98, 0.94, 0.86) if o.taken else Color(0.78, 0.74, 0.7))
	sb.border_color = Color(0.35, 0.7, 0.3) if busy else Color(0.45, 0.3, 0.18)
	sb.set_border_width_all(4 if busy else 2)
	sb.set_corner_radius_all(4)
	t.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	t.add_child(v)
	var top := Label.new()
	top.text = ("#%d" % o.ticket) if o.posted else ("making" if busy else ("taken" if o.taken else "waiting"))
	top.add_theme_font_size_override("font_size", 14)
	top.add_theme_color_override("font_color", Color(0.3, 0.18, 0.08))
	top.add_theme_constant_override("outline_size", 0)
	v.add_child(top)
	if o.taken or o.posted:
		var ic := TextureRect.new()
		ic.texture = Art.dish_art(o.dish)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(80, 44)
		v.add_child(ic)
		var nm := Label.new()
		nm.text = Kitchen.title_of(o.dish)
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.custom_minimum_size = Vector2(80, 0)
		nm.add_theme_font_size_override("font_size", 12)
		nm.add_theme_color_override("font_color", Color(0.3, 0.18, 0.08))
		nm.add_theme_constant_override("outline_size", 0)
		v.add_child(nm)
		t.tooltip_text = "%s%s" % [Kitchen.title_of(o.dish), "  (ticket #%d)" % o.ticket if o.posted else ""]
	else:
		var q := Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 40)
		q.add_theme_color_override("font_color", Color(0.4, 0.3, 0.25))
		v.add_child(q)
		t.tooltip_text = "Order not taken yet: use take_order()"
	return t

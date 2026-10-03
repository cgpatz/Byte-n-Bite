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
		hint.text = "WASD move  ·  E interact / buy upgrades  ·  M market  ·  T lessons  ·  R recipes  ·  L library  ·  Tab stats  ·  G goals  ·  Esc / P pause"
		hint.offset_left = -1100
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


## Recipes / Library / Stats buttons in the top-right corner.
func _build_buttons() -> void:
	var row := HBoxContainer.new()
	row.name = "WindowButtons"
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -940
	row.offset_right = -24
	row.offset_top = 70
	row.offset_bottom = 134
	row.alignment = BoxContainer.ALIGNMENT_END
	add_child(row)
	_market_button = Button.new()
	_market_button.text = "Market (M)"
	_market_button.focus_mode = Control.FOCUS_NONE
	_market_button.custom_minimum_size = Vector2(0, 64)
	_market_button.add_theme_font_size_override("font_size", 22)
	_market_button.tooltip_text = "Go to the Night Market to buy ingredients (or use the back door)."
	PixelArt.button_icon(_market_button, ["market"])
	_market_button.pressed.connect(func(): window_requested.emit("market"))
	row.add_child(_market_button)
	row.offset_left -= 230
	for spec in [["Lessons (T)", "tutorial", "tutorial"], ["Recipes (R)", "recipe_book", "recipe_book"], ["Library (L)", "library", "library"], ["Stats (Tab)", "stats", "stats"]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 22)
		PixelArt.button_icon(b, [spec[2]])
		b.pressed.connect(func(): window_requested.emit(spec[1]))
		row.add_child(b)


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
	prompt_label.text = "[E]  %s" % target.get_prompt()
	prompt.show()


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
		_market_button.text = "Back (M)" if on else "Market (M)"
		_market_button.tooltip_text = "Go back to the restaurant." if on else "Go to the Night Market to buy ingredients (or use the back door)."


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

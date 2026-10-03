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
## Level goals checklist (Level 1: data types, variables, printf).
var _goals: PanelContainer
var _goals_label: RichTextLabel
const LevelGoals := preload("res://systems/goals/level_goals.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const Art := preload("res://scenes/ui/common/ui_art.gd")


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.restaurant_level_changed.connect(_on_level_changed)
	_on_money_changed(GameState.money)
	_on_level_changed(GameState.restaurant_level)
	_build_player_level()
	_build_buttons()
	_build_special()
	_build_goals()
	var hint := get_node_or_null("ControlsHint") as Label
	if hint:
		hint.text = "WASD move  ·  E interact / buy upgrades  ·  T lessons  ·  R recipes  ·  L library  ·  Tab stats  ·  Esc / P pause"
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
	_refresh_goals()


## Level goals checklist under Today's Special. Hover a goal line for a hint.
func _build_goals() -> void:
	_goals = PanelContainer.new()
	_goals.theme_type_variation = &"WoodPanel"
	_goals.position = Vector2(24, 200)
	_goals.custom_minimum_size = Vector2(470, 0)
	_goals.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_goals)
	_goals_label = RichTextLabel.new()
	_goals_label.bbcode_enabled = true
	_goals_label.fit_content = true
	_goals_label.scroll_active = false
	_goals_label.custom_minimum_size = Vector2(430, 0)
	_goals_label.add_theme_font_size_override("normal_font_size", 18)
	_goals_label.add_theme_font_size_override("bold_font_size", 20)
	_goals_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_goals.add_child(_goals_label)
	GameState.goal_completed.connect(func(_l, _i): _refresh_goals())
	_refresh_goals()


func _refresh_goals() -> void:
	if _goals == null:
		return
	var lv: int = GameState.restaurant_level
	var list: Array = LevelGoals.for_level(lv)
	_goals.visible = not list.is_empty()
	if list.is_empty():
		return
	var left: int = GameState.goals_left(lv).size()
	var t := "[b][color=#ffd98a]Level %d goals[/color][/b]  [color=#c9b48f](%d / %d done%s)[/color]\n" % [
		lv, list.size() - left, list.size(), "" if left > 0 else (": upgrade unlocked!" if lv < GameState.MAX_RESTAURANT_LEVEL else ": all done!")]
	var tips: Array = []
	for g in list:
		var done: bool = GameState.goal_done(lv, g.id)
		t += "%s [color=%s]%s[/color]  [color=#c9b48f]+%d coins · +%d EXP[/color]\n" % [
			"☑" if done else "☐", "#9fd18a" if done else "#f2e3c4", g.title, g.coins, g.exp]
		if not done:
			tips.append("%s: %s\n   e.g. %s" % [g.title, g.task, g.how])
	_goals_label.text = t.strip_edges()
	_goals.tooltip_text = "\n\n".join(tips) if not tips.is_empty() else "All done! Upgrade at the chalkboard."
	_goals.reset_size()


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

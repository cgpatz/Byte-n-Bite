extends Station
## A crate from a Market delivery, waiting in the restaurant's delivery area
## (FR-13). Only the manager can claim it: [E] adds its ingredients to the
## kitchen. Art: assets/delivery/crates/crate_<ingredient>.png (16 × 21).

const Market := preload("res://systems/market/market_rules.gd")

## Index in GameState.crates.
var crate_index := 0
var ing := "RICE"
var amount := 1


func setup(i: int, c: Dictionary) -> void:
	crate_index = i
	ing = c.ing
	amount = int(c.n)
	station_id = "CRATE"
	display_name = "%s crate" % Market.title(ing)
	size = Vector2(48, 40)
	solid = false
	show_label = false
	art = PixelArt.find(["res://assets/delivery/crates/crate_%s.png" % ing.to_lower(),
		"res://assets/delivery/crates/crate_mixed.png"])


func _draw() -> void:
	if art:
		var s := float(PixelArt.SCALE)
		var tl := Vector2(-art.get_width() * s / 2.0, 20 - art.get_height() * s)
		draw_set_transform(tl, 0.0, Vector2(s, s))
		draw_texture(art, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(Rect2(-24, -28, 48, 48), Color(0.6, 0.4, 0.2))
	var font := ThemeDB.fallback_font
	var t := "x%d" % amount
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string_outline(font, Vector2(-w / 2.0, 34), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(-w / 2.0, 34), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func get_prompt() -> String:
	return "Claim %d %s" % [amount, Market.title(ing)]

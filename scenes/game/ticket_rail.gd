extends Node2D
## Order tickets pinned on the serving counter (post_order() / check_counter()):
## numbered paper slips in queue order, oldest on the left. Drawn above the
## counter so players can watch "first in, first out" happen.

const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const PixelArt := preload("res://scenes/art/pixel_art.gd")
const W := 44.0
const H := 46.0
const GAP := 6.0

var game: Node


func _ready() -> void:
	z_index = 200
	top_level = true


func _draw() -> void:
	if game == null:
		return
	var st = game.get_station("SERVING_COUNTER")
	if st == null:
		return
	var posted: Array = game.orders.filter(func(o): return o.posted and o.claimed_by == null)
	if posted.is_empty():
		return
	posted.sort_custom(func(a, b): return a.ticket < b.ticket)
	var shown := mini(posted.size(), 6)
	var total := shown * W + (shown - 1) * GAP
	# Pinned along the counter's back edge, centred.
	var top: Vector2 = st.global_position + Vector2(-total / 2.0, -st.size.y / 2.0 - H + 18)
	var font := ThemeDB.fallback_font
	draw_line(top + Vector2(-6, -2), top + Vector2(total + 6, -2), Color(0.35, 0.22, 0.12), 3.0)
	for i in shown:
		var o: Dictionary = posted[i]
		var r := Rect2(top + Vector2(i * (W + GAP), 0), Vector2(W, H))
		draw_rect(r, Color(1, 0.97, 0.86))
		draw_rect(r, Color(0.45, 0.3, 0.18), false, 2.0)
		draw_circle(r.position + Vector2(W / 2.0, 0), 3.0, Color(0.8, 0.2, 0.2))
		draw_string(font, r.position + Vector2(3, 14), "#%d" % o.ticket, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.18, 0.08))
		var icon: Texture2D = PixelArt.find(["res://assets/ui/windows/recipe_book/dish_%s.png" % o.dish.to_lower()])
		if icon == null:
			icon = PixelArt.food_icon(o.dish, true, true)
		if icon == null:
			# No art yet: the dish's initials (GS = Garden Salad).
			var initials := ""
			var words := Kitchen.title_of(o.dish).split(" ", false)
			if words.size() == 1:
				initials = words[0].substr(0, 3).to_upper()
			else:
				for w in words:
					initials += w[0]
			draw_string(font, r.position + Vector2(0, 38), initials.substr(0, 3), HORIZONTAL_ALIGNMENT_CENTER, W, 16, Color(0.55, 0.2, 0.1))
		else:
			var fit := 24.0 / maxf(icon.get_width(), icon.get_height())
			var sz := icon.get_size() * fit
			draw_texture_rect(icon, Rect2(r.position + Vector2((W - sz.x) / 2.0, 17), sz), false)
	if posted.size() > shown:
		draw_string(font, top + Vector2(total + 8, H / 2.0), "+%d" % (posted.size() - shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.6))

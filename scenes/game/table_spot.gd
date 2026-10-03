extends Station
## An empty table slot that can be bought: a dashed outline with
## "+ Table" and the price. The manager walks up and presses E.

const Dash := 10.0


func _ready() -> void:
	super._ready()
	solid = false
	station_id = ""
	display_name = "Table spot"
	GameState.money_changed.connect(func(_m): queue_redraw())


func get_prompt() -> String:
	return "Buy a table (%d coins)" % GameState.next_table_cost()


func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	var afford: bool = GameState.money >= GameState.next_table_cost()
	var col := Color(1, 0.86, 0.45, 0.9) if afford else Color(0.9, 0.85, 0.75, 0.55)
	draw_rect(r, Color(col, 0.12))
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / (Dash * 2.0))
		for k in n:
			var t0 := float(k) / n
			var t1 := t0 + 0.5 / n
			draw_line(a.lerp(b, t0), a.lerp(b, t1), col, 3.0)
	var font := ThemeDB.fallback_font
	var t1s := "+ Table"
	var t2s := "%d" % GameState.next_table_cost()
	draw_string_outline(font, Vector2(-32, -2), t1s, HORIZONTAL_ALIGNMENT_CENTER, 64, 16, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(-32, -2), t1s, HORIZONTAL_ALIGNMENT_CENTER, 64, 16, col)
	draw_string_outline(font, Vector2(-32, 18), t2s, HORIZONTAL_ALIGNMENT_CENTER, 64, 16, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(-32, 18), t2s, HORIZONTAL_ALIGNMENT_CENTER, 64, 16, col)

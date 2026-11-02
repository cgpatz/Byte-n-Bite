extends Node2D
## Level 1 v2 street life (decoration only): a few people walking along the
## sidewalk and cars driving along the road in front of the restaurant. They
## never enter the room and have no collisions. World units: 1 art px = 4.

const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const K := 4.0
## The outside picture's world rect (Art/Outside).
var area := Rect2(-704, -212, 1920, 1080)
## Sidewalk: feet at art y 201; road lanes centred at art y 224 and 254.
const WALK_Y := 201.0
const LANE_Y := [224.0, 254.0]
const FRAME := Vector2(16, 24)

var _walkers: Array = []  # {sprite, speed, dir, t}
var _cars: Array = []     # {sprite, speed, dir, wait}


func _ready() -> void:
	z_index = 5
	var looks: Array = []
	var dir := DirAccess.open("res://assets/character/customers")
	if dir:
		for f in dir.get_files():
			if f.ends_with("_sheet.png"):
				looks.append("res://assets/character/customers/" + f)
	looks.shuffle()
	for i in mini(3, looks.size()):
		var s := Sprite2D.new()
		s.texture = load(looks[i])
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.region_enabled = true
		s.scale = Vector2(K, K)
		add_child(s)
		var d := 1.0 if i % 2 == 0 else -1.0
		var x := area.position.x + randf() * area.size.x
		s.position = Vector2(x, area.position.y + (WALK_Y - FRAME.y) * K + (i % 2) * 8.0)
		_walkers.append({"s": s, "speed": randf_range(28.0, 42.0) * K / 4.0 * 2.0, "dir": d, "t": randf() * 2.0})
	for i in 2:
		var c := Sprite2D.new()
		c.texture = load("res://assets/design/l1_v2/outside/car_%s.png" % ["blue", "red"][i])
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.centered = false
		c.scale = Vector2(K, K)
		var d := 1.0 if i == 0 else -1.0
		c.flip_h = d < 0
		add_child(c)
		c.position = Vector2(area.position.x - 200.0 if d > 0 else area.end.x + 80.0,
				area.position.y + (LANE_Y[i] - 10.0) * K)
		_cars.append({"s": c, "speed": randf_range(150.0, 220.0), "dir": d, "wait": randf_range(0.5, 4.0)})


func _process(delta: float) -> void:
	for w in _walkers:
		var s: Sprite2D = w.s
		s.position.x += w.dir * w.speed * delta
		if w.dir > 0 and s.position.x > area.end.x + 20.0:
			s.position.x = area.position.x - FRAME.x * K - 20.0
		elif w.dir < 0 and s.position.x < area.position.x - FRAME.x * K - 20.0:
			s.position.x = area.end.x + 20.0
		w.t += delta
		# Walk sheet: 4 frames per row; rows down, up, left, right.
		var col := int(w.t * 8.0) % 4
		var row := 3 if w.dir > 0 else 2
		s.region_rect = Rect2(col * FRAME.x, row * FRAME.y, FRAME.x, FRAME.y)
	for c in _cars:
		var cs: Sprite2D = c.s
		if c.wait > 0.0:
			c.wait -= delta
			continue
		cs.position.x += c.dir * c.speed * delta
		var w2: float = cs.texture.get_width() * K
		if (c.dir > 0 and cs.position.x > area.end.x + 40.0) or (c.dir < 0 and cs.position.x < area.position.x - w2 - 40.0):
			cs.position.x = area.position.x - w2 - 40.0 if c.dir > 0 else area.end.x + 40.0
			c.speed = randf_range(150.0, 220.0)
			c.wait = randf_range(2.0, 7.0)

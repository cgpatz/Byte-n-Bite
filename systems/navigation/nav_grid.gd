extends RefCounted
## Simple grid pathfinding for staff (T15). The restaurant is split into small
## cells; cells covered by solid stations, walls or tables are blocked. Paths
## use 8 directions without cutting corners, then get smoothed a little.

const CELL := 32.0
## Staff body radius: cells closer than this to a solid are blocked too.
const BODY_RADIUS := 18.0

var origin := Vector2.ZERO
var cols := 0
var rows := 0
var _blocked := PackedByteArray()


## bounds: area to cover. solids: Array of Rect2 (world space) that can't be walked through.
func build(bounds: Rect2, solids: Array) -> void:
	origin = bounds.position
	cols = int(ceil(bounds.size.x / CELL))
	rows = int(ceil(bounds.size.y / CELL))
	_blocked = PackedByteArray()
	_blocked.resize(cols * rows)
	_blocked.fill(0)
	for r in solids:
		var grown: Rect2 = (r as Rect2).grow(BODY_RADIUS - 2.0)
		var c0 := _to_cell(grown.position)
		var c1 := _to_cell(grown.end)
		for y in range(maxi(c0.y, 0), mini(c1.y + 1, rows)):
			for x in range(maxi(c0.x, 0), mini(c1.x + 1, cols)):
				if grown.has_point(cell_center(Vector2i(x, y))):
					_blocked[y * cols + x] = 1


func _to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.y - origin.y) / CELL))


func cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func is_free(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows and _blocked[c.y * cols + c.x] == 0


## Finds a path from `from` to any free cell within `reach` px of `target` (a Rect2
## like a station's box). Returns {"ok": bool, "points": PackedVector2Array}.
func find_path(from: Vector2, target: Rect2, reach: float) -> Dictionary:
	var start := _to_cell(from)
	if not is_free(start):
		start = _nearest_free(start)
		if start.x < 0:
			return {"ok": false, "points": PackedVector2Array()}
	var zone := target.grow(reach)
	if _is_goal(start, target, zone):
		return {"ok": true, "points": PackedVector2Array()}
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var goal := Vector2i(-1, -1)
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if _is_goal(c, target, zone):
			goal = c
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var nc: Vector2i = c + d
			if came.has(nc) or not is_free(nc):
				continue
			if d.x != 0 and d.y != 0 and (not is_free(Vector2i(c.x + d.x, c.y)) or not is_free(Vector2i(c.x, c.y + d.y))):
				continue  # no corner cutting
			came[nc] = c
			queue.append(nc)
	if goal.x < 0:
		return {"ok": false, "points": PackedVector2Array()}
	var cells: Array[Vector2i] = []
	var cur := goal
	while cur != start:
		cells.push_front(cur)
		cur = came[cur]
	return {"ok": true, "points": _smooth(from, cells)}


func _is_goal(c: Vector2i, _target: Rect2, zone: Rect2) -> bool:
	return zone.has_point(cell_center(c))  # solid stations block their own cells


func _nearest_free(c: Vector2i) -> Vector2i:
	for radius in range(1, 6):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var nc := c + Vector2i(x, y)
				if is_free(nc):
					return nc
	return Vector2i(-1, -1)


## Drops in-between points that lie on a straight clear line.
func _smooth(from: Vector2, cells: Array[Vector2i]) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var anchor := from
	for i in cells.size():
		var p := cell_center(cells[i])
		var is_last := i == cells.size() - 1
		if is_last:
			pts.append(p)
		elif not _line_clear(anchor, cell_center(cells[i + 1])):
			pts.append(p)
			anchor = p
	return pts


func _line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(ceil(a.distance_to(b) / (CELL * 0.25)))
	for s in range(steps + 1):
		var p := a.lerp(b, float(s) / maxf(steps, 1))
		# Check a small box around the point so the body fits.
		for off in [Vector2.ZERO, Vector2(6, 6), Vector2(-6, 6), Vector2(6, -6), Vector2(-6, -6)]:
			if not is_free(_to_cell(p + off)):
				return false
	return true

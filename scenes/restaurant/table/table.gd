@tool
extends Station
class_name Table
## A dining table with chairs around it. Spawned into a restaurant's table
## slots by the seating system; chairs are added with seating upgrades.
##
## Two kinds (set by the table slot, see Restaurant.get_table_slot_info()):
##   small  — 1 tile (64×64), up to 4 chairs
##   family — 2 tiles wide (128×64), up to 6 chairs (2 top, 2 bottom, 1 each end)

enum Kind { SMALL, FAMILY }
const SMALL_SIZE := Vector2(64, 64)
const FAMILY_SIZE := Vector2(128, 64)
const FAMILY_MAX_CHAIRS := 6
const SMALL_MAX_CHAIRS := 4

@export var kind := Kind.SMALL:
	set(v):
		kind = v
		size = FAMILY_SIZE if kind == Kind.FAMILY else SMALL_SIZE
		queue_redraw()
## Small tables: put the first chairs at the top and bottom instead of the
## left and right (keeps side aisles open in narrow rooms).
@export var ends_first := false:
	set(v):
		ends_first = v
		queue_redraw()
@export_range(0, 6) var chairs := 2:
	set(v):
		chairs = v
		queue_redraw()

## Chair image for just this table (optional; normally assets/decor/chair.png
## is used automatically). Drawn 4× at each chair position.
@export var chair_art: Texture2D:
	set(v):
		chair_art = v
		queue_redraw()
## Chair art found automatically (used when chair_art is empty).
var chair_auto_art: Texture2D:
	set(v):
		chair_auto_art = v
		queue_redraw()

const CHAIR_SIZE := Vector2(22, 22)


func _draw() -> void:
	# Chairs first so the table art sits on top of them.
	_draw_chairs()
	super._draw()


func _draw_chairs() -> void:
	var tex: Texture2D = chair_art if chair_art else chair_auto_art
	if not tex and not draw_greybox:
		return
	var offsets := chair_offsets()
	for i in mini(chairs, offsets.size()):
		if tex:
			var sc := float(PixelArt.SCALE)
			draw_set_transform(offsets[i] - tex.get_size() * sc / 2.0, 0.0, Vector2(sc, sc))
			draw_texture(tex, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
			continue
		var r := Rect2(offsets[i] - CHAIR_SIZE / 2.0, CHAIR_SIZE)
		draw_rect(r, Color(0.72, 0.28, 0.22))
		draw_rect(r, Color(0.3, 0.1, 0.08), false, 3.0)


## Chair positions (relative to the table centre) in the order chairs are added.
func chair_offsets() -> Array:
	var left := Vector2(-size.x / 2.0 - 16, 0)
	var right := Vector2(size.x / 2.0 + 16, 0)
	var top_y := -size.y / 2.0 - 16
	var bottom_y := size.y / 2.0 + 16
	if kind == Kind.FAMILY:
		# Long sides first (2 top, 2 bottom), then the two ends.
		return [Vector2(-32, top_y), Vector2(32, bottom_y), Vector2(32, top_y),
			Vector2(-32, bottom_y), left, right]
	if ends_first:
		return [Vector2(0, top_y), Vector2(0, bottom_y), left, right]
	return [left, right, Vector2(0, top_y), Vector2(0, bottom_y)]


static func max_chairs_for(table_kind: int) -> int:
	return FAMILY_MAX_CHAIRS if table_kind == Kind.FAMILY else SMALL_MAX_CHAIRS


## Index in GameState.table_chairs (set by Game when it places the table).
var table_index := -1


func get_prompt() -> String:
	if table_index >= 0 and table_index < GameState.table_chairs.size() \
			and GameState.table_chairs[table_index] < GameState.chair_cap(table_index):
		return "Add a chair (%d coins)" % GameState.level_data().chair_cost
	return "%s: %d chair%s (full)" % [display_name, chairs, "" if chairs == 1 else "s"]


func interact(_by: Node) -> String:
	return "%s: %d chair%s" % [display_name, chairs, "" if chairs == 1 else "s"]

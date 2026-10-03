@tool
extends Node2D
class_name Restaurant
## A restaurant LAYOUT (one per restaurant level). Design only — no game logic.
##
## Node layout:
##   Floor       greybox floor colours (hidden with show_greybox off)
##   Art         YOUR ART, drawn under walls/stations/characters:
##     Background     full image of the restaurant, auto-stretched to fit
##                    (Level 5: one Background per room)
##     Tiles          TileMapLayer (64 px tiles, assets/tiles/restaurant_tileset.tres)
##     Props          Node2D (y-sorted) for rugs, plants, shelves, small details
##   Foreground  art drawn ABOVE the characters (awnings, hanging lamps, plant tops)
##   Walls       solid walls (Station nodes, labels off)
##   Stations    kitchen stations, found by station_id (e.g. "GRILL")
##   TableSlots  Marker2D spots where bought tables appear, in purchase order
##   Spawns      ManagerSpawn, StaffSpawn1..5
##   Delivery room: back room beside the kitchen (RECEIVING zone + BackDoor);
##                deliveries never use the front entrance.
##   Rooms       (optional) ReferenceRect frames; the camera shows one room at a time
##   GridOverlay editor-only tile grid

const TILE := 64
const BACKGROUND_SCRIPT := preload("res://scenes/restaurant/art_background.gd")
const TILESET := preload("res://assets/tiles/restaurant_tileset.tres")
const PixelArt := preload("res://scenes/art/pixel_art.gd")

@export var level_name := "Tiny Stall"
## Size in tiles, walls included (from the Restaurant Evolution Reference Sheet).
@export var grid_size := Vector2i(8, 8)
## Hide every placeholder rectangle at once when the art is ready.
@export var show_greybox := true:
	set(v):
		show_greybox = v
		_apply_greybox()
## Press after adding or changing PNGs in assets/ to see them here.
@export_tool_button("Reload Art", "Reload") var reload_art_button := reload_art


func _ready() -> void:
	_apply_greybox()
	_apply_auto_art()
	if not Engine.is_editor_hint():
		_setup_depth()
	if Engine.is_editor_hint() and get_tree().edited_scene_root == self:
		_ensure_art_layers.call_deferred()


## Adds the art layers to this layout scene the first time it is opened in the
## editor (they are saved with the scene when you press Save).
func _ensure_art_layers() -> void:
	var art := _ensure(self, "Art", Node2D)
	if art.get_index() > 1:
		move_child(art, 1)  # right after Floor, under walls and stations
	var rooms := get_rooms()
	if rooms.is_empty():
		var bg := _ensure(art, "Background", Sprite2D) as Sprite2D
		if bg.get_script() == null:
			bg.set_script(BACKGROUND_SCRIPT)
			bg.set("fit_size", Vector2(grid_size * TILE))
	else:
		for r in rooms:
			var bg := _ensure(art, "Background" + r.name, Sprite2D) as Sprite2D
			if bg.get_script() == null:
				bg.set_script(BACKGROUND_SCRIPT)
				bg.position = r.rect.position - global_position
				bg.set("fit_size", r.rect.size)
	var tiles := _ensure(art, "Tiles", TileMapLayer) as TileMapLayer
	if tiles.tile_set == null:
		tiles.tile_set = TILESET
	var props := _ensure(art, "Props", Node2D)
	props.y_sort_enabled = true
	var fg := _ensure(self, "Foreground", Node2D)
	fg.z_index = 10


# --- Automatic art ------------------------------------------------------------------

## "L1", "L2"... from the scene file name (L1_TinyStall.tscn). Used for per-level art folders.
func level_key() -> String:
	var f := scene_file_path.get_file()
	if f.length() >= 2 and f[0] == "L" and f[1].is_valid_int():
		return f.substr(0, 2)
	return ""


## Re-reads the PNGs in assets/ and updates every station.
func reload_art() -> void:
	PixelArt.clear_cache()
	_apply_auto_art()


func _apply_auto_art() -> void:
	if not is_inside_tree():
		return
	var lk := level_key()
	for group in ["Stations", "Walls"]:
		var n := get_node_or_null(group)
		if n:
			_auto_art_recursive(n, lk)
	# Background images: assets/backgrounds/levels/L1.png (L5: L5_cafe.png, L5_diner.png, L5_kitchen.png)
	var art := get_node_or_null("Art")
	if art == null or lk == "":
		return
	for c in art.get_children():
		if c is Sprite2D and String(c.name).begins_with("Background") and c.texture == null:
			var room := String(c.name).trim_prefix("Background").to_lower()
			var key := lk if room == "" else "%s_%s" % [lk, room]
			var tex := PixelArt.find(["res://assets/backgrounds/levels/%s.png" % key])
			if tex:
				c.texture = tex


func _auto_art_recursive(node: Node, lk: String) -> void:
	for c in node.get_children():
		if c is Station:
			var tex := art_for(c, lk)
			if c.auto_art != tex:
				c.auto_art = tex
		else:
			_auto_art_recursive(c, lk)


## Kitchen stations: assets/stations/[L1/]<station_id>.png
## Decor blocks (no Station Id): assets/decor/[L1/]<name>.png, where the name is
## the node name without positions/numbers ("PlantsBottomLeft" -> "plants").
## Plain walls get no automatic art: paint them in the background image.
func art_for(st: Station, lk := level_key()) -> Texture2D:
	if st.station_id != "":
		return PixelArt.for_level("stations", st.station_id, lk)
	if st.get_parent() and st.get_parent().name == "Walls":
		return null
	return PixelArt.for_level("decor", decor_key(String(st.name)), lk)


static func decor_key(node_name: String) -> String:
	var re := RegEx.create_from_string("(Top|Bottom|Left|Right|Upper|Lower|Middle|\\d+)+$")
	var base := re.sub(node_name, "")
	return PixelArt.file_key(base if base != "" else node_name)


# --- Depth (who is drawn in front) ------------------------------------------------------
# In the game, stations, props, tables and characters are sorted by their Y
# position: whatever stands lower on screen is drawn in front. Floors,
# backgrounds, tiles and floor zones (like the delivery area) stay underneath.

func _setup_depth() -> void:
	y_sort_enabled = true
	for path in ["Walls", "Stations", "Art", "Art/Props"]:
		var n := get_node_or_null(path)
		if n:
			n.y_sort_enabled = true
	for path in ["Floor", "GridOverlay", "Art/Tiles"]:
		var n := get_node_or_null(path) as CanvasItem
		if n:
			n.z_index = -2
	var art := get_node_or_null("Art")
	if art:
		for c in art.get_children():
			if c is Sprite2D:
				c.z_index = -2
	_depth_recursive(get_node_or_null("Stations"))


func _depth_recursive(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		if c is Station:
			if not c.solid:
				c.z_index = -1  # floor zones (delivery area, stool spots)
		elif c is Node2D:
			c.y_sort_enabled = true
			_depth_recursive(c)


func _ensure(parent: Node, node_name: String, type) -> Node:
	var n := parent.get_node_or_null(node_name)
	if n == null:
		n = type.new()
		n.name = node_name
		parent.add_child(n)
		n.owner = self
	return n


func _apply_greybox() -> void:
	if not is_inside_tree():
		return
	var floor_node := get_node_or_null("Floor")
	if floor_node:
		floor_node.visible = show_greybox
	for group in ["Walls", "Stations"]:
		var n := get_node_or_null(group)
		if n:
			_set_greybox_recursive(n)


func _set_greybox_recursive(node: Node) -> void:
	for c in node.get_children():
		if c is Station:
			c.draw_greybox = show_greybox
		else:
			_set_greybox_recursive(c)


## World-space rectangle covered by the layout (walls + delivery room).
func get_bounds() -> Rect2:
	var r := Rect2(global_position, Vector2(grid_size * TILE))
	for w in $Walls.get_children():
		if w is Station:
			r = r.merge(Rect2(w.global_position - w.size / 2.0, w.size))
	return r


## Returns the station with this id (e.g. "GRILL"), or null. Searches Stations
## and Walls (BACK_DOOR), including sub-groups. Tables live in Game, not here.
func get_station(station_id: String) -> Station:
	for group in ["Stations", "Walls"]:
		var found := _find_station(get_node(group), station_id)
		if found:
			return found
	return null


func _find_station(node: Node, station_id: String) -> Station:
	for c in node.get_children():
		if c is Station and c.station_id == station_id:
			return c
		var deeper := _find_station(c, station_id)
		if deeper:
			return deeper
	return null


func get_manager_spawn() -> Vector2:
	return ($Spawns/ManagerSpawn as Marker2D).global_position


## Spawn point for the n-th staff member (0-based). Falls back to the first one.
func get_staff_spawn(index: int) -> Vector2:
	var marker := get_node_or_null("Spawns/StaffSpawn%d" % (index + 1)) as Marker2D
	if marker == null:
		marker = $Spawns/StaffSpawn1 as Marker2D
	return marker.global_position


## Table slot positions in the order tables are placed.
func get_table_slots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for m in $TableSlots.get_children():
		if m is Marker2D:
			out.append(m.global_position)
	return out


## Table slots with their table type, in purchase order:
## [{"pos": Vector2, "family": bool, "ends_first": bool}]
## Set on each TableSlot marker in the Inspector → Metadata:
##   family = true       → a family table (2 tiles wide, up to 6 chairs)
##   ends_first = true   → small table whose first chairs go top and bottom
func get_table_slot_info() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in $TableSlots.get_children():
		if m is Marker2D:
			out.append({
				"pos": m.global_position,
				"family": bool(m.get_meta("family", false)),
				"ends_first": bool(m.get_meta("ends_first", false)),
			})
	return out


## Camera rooms (ReferenceRect children of "Rooms"). Empty = show the whole layout.
func get_rooms() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rooms := get_node_or_null("Rooms")
	if rooms == null:
		return out
	for r in rooms.get_children():
		if r is Control:
			out.append({"name": String(r.name), "rect": Rect2(r.global_position, r.size)})
	return out

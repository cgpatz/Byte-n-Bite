extends Node2D
## The Market (FR-11, FR-58): a separate area away from the restaurant where the
## manager buys ingredients. Market design 3 "Night Market" (16 × 12 tiles):
## five stall tents, a price board, lanterns, a snack corner and the teleport
## pad back to the restaurant. Built in code; art in assets/market/.
## The restaurant keeps running while the manager is here.

const Market := preload("res://systems/market/market_rules.gd")
const PixelArt := preload("res://scenes/art/pixel_art.gd")
const STATION_SCENE := preload("res://scenes/stations/Station.tscn")
const STALL_SCRIPT := preload("res://scenes/market/stall.gd")
const ART := "res://assets/market/"
const TILE := 64.0
const SIZE := Vector2(1024, 768)
## Where the manager appears (just below the teleport pad), in local px.
const ARRIVE := Vector2(512, 568)
const PAD_CENTER := Vector2(512, 448)

## Tent top-left tile for each stall (tents are 3 × 3 tiles).
const STALL_TILES := {"GRAINS": Vector2i(1, 1), "DAIRY": Vector2i(6, 1), "BUTCHER": Vector2i(11, 1),
	"GREENS": Vector2i(1, 8), "CAFE": Vector2i(11, 8)}
const TENT_ART := {"GRAINS": "tent_grains", "DAIRY": "tent_dairy", "BUTCHER": "tent_butcher",
	"GREENS": "tent_greens", "CAFE": "tent_cafe"}

var stalls := {}
var pad: Station
var _pad_sprite: Sprite2D
var _pad_t := 0.0


func _ready() -> void:
	y_sort_enabled = true
	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.texture = _tex("market_bg")
	bg.centered = false
	bg.scale = Vector2(4, 4)
	bg.z_index = -10
	add_child(bg)
	# Walls: skyline at the top, the edges of the square.
	_wall(Rect2(0, 0, SIZE.x, 128))
	_wall(Rect2(-64, 0, 64, SIZE.y))
	_wall(Rect2(SIZE.x, 0, 64, SIZE.y))
	_wall(Rect2(0, SIZE.y, SIZE.x, 64))
	for key in STALL_TILES:
		var t: Vector2i = STALL_TILES[key]
		var st := STATION_SCENE.instantiate() as Station
		st.set_script(STALL_SCRIPT)
		st.name = "Stall" + key.capitalize()
		st.station_id = "STALL_" + key
		st.display_name = Market.STALLS[key].title
		st.size = Vector2(192, 128)
		st.position = Vector2((t.x + 1.5) * TILE, (t.y + 2) * TILE)
		st.art = _tex(TENT_ART[key])
		st.opens = "shop:" + key
		st.stall_key = key
		st.vendor_tex = PixelArt.find(["res://assets/character/customers/%s_sheet.png" % Market.STALLS[key].vendor])
		add_child(st)
		stalls[key] = st
	# Price board (shows what's in stock and when the Market restocks).
	var board := _decor("PriceBoard", "price_board", Vector2(64, 480), Vector2(128, 64), true)
	board.display_name = "Price Board"
	board.opens = "price_board"
	board.interactable = true
	# Teleport pad back to the restaurant (E, or step on it).
	pad = STATION_SCENE.instantiate() as Station
	pad.name = "TeleportPad"
	pad.station_id = "TELEPORT_PAD"
	pad.display_name = "Teleport Pad"
	pad.size = Vector2(112, 112)
	pad.solid = false
	pad.draw_greybox = false
	pad.opens = "return"
	pad.position = PAD_CENTER
	add_child(pad)
	_pad_sprite = Sprite2D.new()
	_pad_sprite.texture = _tex("teleport_pad_sheet")
	_pad_sprite.hframes = 4
	_pad_sprite.scale = Vector2(4, 4)
	_pad_sprite.position = PAD_CENTER
	_pad_sprite.z_index = -5
	add_child(_pad_sprite)
	# Lantern posts, snack corner, crates.
	for p in [Vector2(352, 352), Vector2(672, 352), Vector2(352, 672), Vector2(672, 672)]:
		_decor("LanternPost", "lantern_post", p, Vector2(32, 24), true)
	_decor("Barrel", "barrel", Vector2(416, 672), Vector2(48, 40), true)
	_decor("Barrel", "barrel", Vector2(544, 672), Vector2(48, 40), true)
	_decor("Bench", "bench", Vector2(480, 712), Vector2(112, 32), true)
	_decor("Crate", "crate", Vector2(928, 480), Vector2(56, 48), true)
	_decor("Crate", "crate", Vector2(992, 480), Vector2(56, 48), true)
	# Hanging string lights (drawn above people).
	for y in [168.0, 360.0]:
		for i in 4:
			var s := Sprite2D.new()
			s.texture = _tex("string_lanterns")
			s.centered = false
			s.scale = Vector2(4, 4)
			s.position = Vector2(i * 256, y - 28)
			s.z_index = 5
			add_child(s)
	# A couple of shoppers.
	_shopper("taro", Vector2(288, 540))
	_shopper("coco", Vector2(800, 492))
	refresh()


func _process(delta: float) -> void:
	_pad_t += delta
	if _pad_sprite:
		_pad_sprite.frame = int(_pad_t * 6.0) % 4


## Updates closed stalls (Café Supplies opens with the Café).
func refresh() -> void:
	for key in stalls:
		var st = stalls[key]
		st.closed = Market.STALLS[key].get("cafe", false) and GameState.cafe_step < 1


## Global position the manager arrives at.
func arrival_point() -> Vector2:
	return to_global(ARRIVE)


func pad_point() -> Vector2:
	return to_global(PAD_CENTER)


func bounds() -> Rect2:
	return Rect2(global_position, SIZE)


func _tex(key: String) -> Texture2D:
	return PixelArt.find([ART + key + ".png"])


func _wall(r: Rect2) -> void:
	var w := STATION_SCENE.instantiate() as Station
	w.name = "Wall"
	w.station_id = ""
	w.display_name = ""
	w.size = r.size
	w.position = r.get_center()
	w.draw_greybox = false
	w.show_label = false
	w.interactable = false
	add_child(w)


func _decor(node_name: String, art_key: String, pos: Vector2, size: Vector2, solid: bool) -> Station:
	var d := STATION_SCENE.instantiate() as Station
	d.name = node_name
	d.station_id = ""
	d.display_name = ""
	d.size = size
	d.position = pos
	d.solid = solid
	d.art = _tex(art_key)
	d.show_label = false
	d.interactable = false
	add_child(d)
	return d


func _shopper(look: String, feet: Vector2) -> void:
	var tex := PixelArt.find(["res://assets/character/customers/%s_sheet.png" % look])
	if tex == null:
		return
	var s := Sprite2D.new()
	PixelArt.setup_character(s, tex, 0.0)
	s.position = feet
	add_child(s)

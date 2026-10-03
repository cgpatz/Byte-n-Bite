@tool
extends StaticBody2D
class_name Station
## Kitchen station / furniture / wall. Drawn as a labeled placeholder rectangle
## until you give it art: set `art` in the Inspector and the image is drawn in
## the station's box instead (collision and interaction stay the same).

## ID used by C programs later, e.g. go_to(GRILL).
@export var station_id := "GRILL":
	set(v):
		station_id = v
		queue_redraw()
@export var display_name := "Grill":
	set(v):
		display_name = v
		queue_redraw()
@export var size := Vector2(160, 100):
	set(v):
		size = v
		_update_shape()
		queue_redraw()
@export var color := Color(0.55, 0.25, 0.2):
	set(v):
		color = v
		queue_redraw()
@export var show_label := true:
	set(v):
		show_label = v
		queue_redraw()
## Solid = blocks movement. Non-solid zones (e.g. the receiving area) can be walked over.
@export var solid := true:
	set(v):
		solid = v
		_update_layers()
## Draw the placeholder rectangle. Turn off once real art covers this station
## (collision and interaction keep working).
@export var draw_greybox := true:
	set(v):
		draw_greybox = v
		queue_redraw()
@export_group("Art")
## Image for just this station (optional). Normally art is found automatically
## from assets/stations/ by Station Id: see assets/ART_GUIDE.md.
@export var art: Texture2D:
	set(v):
		art = v
		queue_redraw()
## Off (default) = pixel art drawn 4× and standing on the station's tiles.
## On = the image is stretched to exactly fill `size`.
@export var art_fit := false:
	set(v):
		art_fit = v
		queue_redraw()
@export var art_offset := Vector2.ZERO:
	set(v):
		art_offset = v
		queue_redraw()
@export_group("")

## Can the manager press E on it?
@export var interactable := true
## What pressing E here offers: "" (shows info_text), "upgrades" (the Upgrade
## Board: buy the next restaurant level), "cafe_menu" (buy Café recipes),
## "shop:<STALL>" (a Market stall), "price_board" or "return" (Market teleport pad).
@export var opens := ""
@export_multiline var info_text := ""

const PixelArt := preload("res://scenes/art/pixel_art.gd")
const LAYER_SOLID := 1
const LAYER_ZONE := 2

var _shape: CollisionShape2D
## Art found automatically by the restaurant (used when `art` is empty).
var auto_art: Texture2D:
	set(v):
		auto_art = v
		queue_redraw()


func _ready() -> void:
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_update_shape()
	_update_layers()
	queue_redraw()


func _update_shape() -> void:
	if _shape:
		(_shape.shape as RectangleShape2D).size = size


func _update_layers() -> void:
	collision_layer = LAYER_SOLID if solid else LAYER_ZONE
	collision_mask = 0


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	var tex: Texture2D = art if art else auto_art
	if tex:
		if art_fit:
			draw_texture_rect(tex, Rect2(rect.position + art_offset, rect.size), false)
		else:
			_draw_pixel_art(tex)
		return  # art replaces the placeholder and its label
	if not draw_greybox:
		return
	if solid:
		draw_rect(rect, color)
		draw_rect(rect, color.darkened(0.5), false, 4.0)
	else:
		draw_rect(rect, Color(color, 0.25))
		draw_rect(rect, color, false, 4.0)
	if show_label and display_name != "":
		var font := ThemeDB.fallback_font
		var fs := 20
		var text_size := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var pos := Vector2(-text_size.x / 2.0, fs * 0.35)
		draw_string_outline(font, pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
		draw_string(font, pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Tiles this station covers (e.g. 120×56 -> 2×1).
func footprint_tiles() -> Vector2i:
	return Vector2i(maxi(1, roundi(size.x / 64.0)), maxi(1, roundi(size.y / 64.0)))


## Draws pixel art 4× bigger, centred left-right, with its bottom edge on the
## bottom of the station's tiles (taller art rises above, like a fridge).
func _draw_pixel_art(tex: Texture2D) -> void:
	var s := float(PixelArt.SCALE)
	var bottom := footprint_tiles().y * 64.0 / 2.0
	var top_left := Vector2(-tex.get_width() * s / 2.0, bottom - tex.get_height() * s) + art_offset
	draw_set_transform(top_left, 0.0, Vector2(s, s))
	draw_texture(tex, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)


# --- Interaction (used by the manager) ---------------------------------------

func can_interact() -> bool:
	return interactable


func get_prompt() -> String:
	if opens == "upgrades":
		return "Upgrade the restaurant"
	if opens == "cafe_menu":
		return "Buy Café recipes"
	if station_id == "CAFE_DOOR":
		return "Open the Café"
	if station_id == "BACK_DOOR":
		return "Go to Market"
	if station_id == "FRIDGE":
		return "Check the fridge (ingredients)"
	if opens == "price_board":
		return "Read the price board"
	if opens == "return":
		return "Go back to the restaurant"
	return "Inspect %s" % display_name


func interact(_by: Node) -> String:
	return info_text if info_text != "" else "%s  (%s)" % [display_name, station_id]

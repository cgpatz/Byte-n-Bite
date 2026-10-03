@tool
extends Node2D
## Editor-only tile grid so layouts line up with the tile art. Hidden in-game.

@export var grid_size := Vector2i(8, 8):
	set(v):
		grid_size = v
		queue_redraw()
@export var tile_size := 64:
	set(v):
		tile_size = v
		queue_redraw()


func _ready() -> void:
	visible = Engine.is_editor_hint()


func _draw() -> void:
	var c := Color(1, 1, 1, 0.12)
	for x in grid_size.x + 1:
		draw_line(Vector2(x * tile_size, 0), Vector2(x * tile_size, grid_size.y * tile_size), c, 1.0)
	for y in grid_size.y + 1:
		draw_line(Vector2(0, y * tile_size), Vector2(grid_size.x * tile_size, y * tile_size), c, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid_size * tile_size)), Color(1, 0.8, 0.3, 0.8), false, 3.0)

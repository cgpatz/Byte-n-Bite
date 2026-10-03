@tool
extends Sprite2D
## Background image for a restaurant (or one Level 5 room).
## Drop any image into `texture`: it is stretched to exactly fill `fit_size`
## (the layout or room size in pixels), so it lines up with walls and stations.

@export var fit_size := Vector2(512, 512):
	set(v):
		fit_size = v
		_fit()
## Turn off to keep the image at its own size (then move/scale it by hand).
@export var stretch_to_fit := true:
	set(v):
		stretch_to_fit = v
		_fit()


func _ready() -> void:
	centered = false
	texture_changed.connect(_fit)
	_fit()


func _fit() -> void:
	if not is_inside_tree() or texture == null or not stretch_to_fit:
		return
	scale = fit_size / texture.get_size()

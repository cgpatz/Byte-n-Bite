extends Node
## Exports tracing templates for pixel art: every restaurant layout drawn as a
## greybox picture, so you can paint your background on top of it.
## Open tools/ExportLayoutTemplates.tscn and press F6. Files are written to
## assets/_templates/ (that folder is ignored by Godot, so templates never ship).
##
##   L1_TinyStall_16px.png   1 tile = 16 px  -> paint your art at this size
##   L1_TinyStall_64px.png   1 tile = 64 px  -> same, as seen in game, with labels + grid
##   Level 5 also gets one pair per room (L5_cafe, L5_diner, L5_kitchen).
## Re-run it after moving stations or walls.

const OUT_DIR := "res://assets/_templates/"
const PixelArt := preload("res://scenes/art/pixel_art.gd")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open(OUT_DIR + ".gdignore", FileAccess.WRITE)
	if f:
		f.close()
	for lv in range(1, GameState.MAX_RESTAURANT_LEVEL + 1):
		var data := GameState.level_data(lv)
		await _export(data.layout_scene, "L%d_%s" % [lv, data.display_name.replace(" ", "")])
	print("Templates written to ", ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()


func _export(scene: PackedScene, base: String) -> void:
	var labelled := await _render(scene, true)
	var plain := await _render(scene, false)
	var bounds: Rect2 = labelled.bounds
	_save_pair(labelled.image, plain.image, base)
	for room in labelled.rooms:
		var rect := Rect2i(Rect2(room.rect.position - bounds.position, room.rect.size))
		_save_pair(labelled.image.get_region(rect), plain.image.get_region(rect), "%s_%s" % [base.substr(0, 2), String(room.name).to_lower()])


func _save_pair(labelled: Image, plain: Image, name: String) -> void:
	var big := labelled.duplicate() as Image
	_draw_grid(big)
	big.save_png(ProjectSettings.globalize_path(OUT_DIR + name + "_64px.png"))
	var small := plain.duplicate() as Image
	small.resize(small.get_width() / PixelArt.SCALE, small.get_height() / PixelArt.SCALE, Image.INTERPOLATE_NEAREST)
	small.save_png(ProjectSettings.globalize_path(OUT_DIR + name + "_16px.png"))


func _draw_grid(img: Image) -> void:
	var c := Color(0, 0, 0, 0.35)
	for x in range(0, img.get_width(), 64):
		for y in img.get_height():
			img.set_pixel(x, y, img.get_pixel(x, y).blend(c))
	for y in range(0, img.get_height(), 64):
		for x in img.get_width():
			img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


## Draws one layout (greybox only) into an image exactly covering its bounds.
func _render(scene: PackedScene, labels: bool) -> Dictionary:
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	var r := scene.instantiate() as Restaurant
	vp.add_child(r)
	await get_tree().process_frame
	for n in ["GridOverlay", "Foreground", "Art"]:
		var node := r.get_node_or_null(n) as CanvasItem
		if node:
			node.visible = false
	for st in _stations(r):
		st.show_label = labels
		st.auto_art = null
	var bounds := r.get_bounds()
	vp.size = Vector2i(bounds.size)
	vp.canvas_transform = Transform2D(0, -bounds.position)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var rooms := r.get_rooms()
	vp.queue_free()
	return {"image": img, "bounds": bounds, "rooms": rooms}


func _stations(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Station:
			out.append(c)
		out.append_array(_stations(c))
	return out

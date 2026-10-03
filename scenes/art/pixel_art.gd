extends RefCounted
## Pixel-art rules for Byte n' Bite, in one place.
##
## Draw everything on a 16 px grid (1 tile = 16 × 16 art pixels). The game shows
## art 4× bigger (1 tile = 64 × 64 screen pixels) with nearest-neighbour
## filtering, so pixels stay crisp.
##
## Art is found automatically by file name (see assets/ART_GUIDE.md); nothing
## needs to be dragged into the Inspector. Missing files = placeholder shapes.

## Screen pixels per art pixel.
const SCALE := 4
## Art pixels per tile.
const TILE_ART := 16

static var _cache := {}


## First texture that exists among `paths` (res:// paths), or null. Cached.
static func find(paths: Array) -> Texture2D:
	for p in paths:
		if _cache.has(p):
			if _cache[p] != null:
				return _cache[p]
			continue
		var tex: Texture2D = null
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D
		_cache[p] = tex
		if tex:
			return tex
	return null


## Forget cached lookups (after adding new files while the game runs in the editor).
static func clear_cache() -> void:
	_cache.clear()


## A small pixel-art image enlarged by a whole number (crisp pixels), for UI
## elements like Button icons that can't scale their icon.
static func enlarged(tex: Texture2D, factor: int) -> Texture2D:
	if tex == null or factor <= 1:
		return tex
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Puts assets/ui/icons/<first existing key>.png on a Button (if the file exists).
static func button_icon(button: Button, keys: Array) -> void:
	var paths: Array = []
	for k in keys:
		paths.append("res://assets/ui/icons/%s.png" % k)
	var tex := find(paths)
	if tex:
		button.icon = tex


## "SERVING_COUNTER" / "ServingCounter" -> "serving_counter"
static func file_key(name: String) -> String:
	return name.to_snake_case().to_lower()


## Level-specific file first (assets/<folder>/L3/<key>.png), then the shared one.
static func for_level(folder: String, key: String, level_key: String) -> Texture2D:
	var k := file_key(key)
	var paths: Array = []
	if level_key != "":
		paths.append("res://assets/%s/%s/%s.png" % [folder, level_key, k])
	paths.append("res://assets/%s/%s.png" % [folder, k])
	return find(paths)


## Food icon for a held item (ingredient, cooked ingredient, or dish).
static func food_icon(name: String, cooked: bool, is_dish: bool) -> Texture2D:
	var k := file_key(name)
	if is_dish:
		return find(["res://assets/food/dishes/%s.png" % k])
	var paths: Array = []
	if cooked:
		paths.append("res://assets/food/ingredients/%s_cooked.png" % k)
	paths.append("res://assets/food/ingredients/%s.png" % k)
	return find(paths)


## Character art: "<key>_sheet.png" (walk sheet) or "<key>.png" (one still image).
static func character(folder: String, key: String) -> Texture2D:
	var k := file_key(key)
	return find([
		"res://assets/%s/%s_sheet.png" % [folder, k],
		"res://assets/%s/%s.png" % [folder, k],
	])


# --- Character sprite sheets ---------------------------------------------------------
# A "<name>_sheet.png" has 4 rows: facing down, up, left, right.
# Each row holds the walk frames left to right; the first frame is also the
# standing pose. Every frame is FRAME_WIDTH (16) art pixels wide; its height is
# the sheet height ÷ 4 (so 16×16 or 16×24 frames both work).
# Example: 4 frames of 16×24 -> sheet is 64 × 96 px.

## Width of one frame in art pixels.
const FRAME_WIDTH := 16
const WALK_FPS := 8.0
## Row order in a walk sheet (matches the game's character art): down, up, left, right.
enum Facing { DOWN, UP, LEFT, RIGHT }


## Sets up a Sprite2D for a character texture (sheet or still), scaled ×4 and
## placed so the feet sit at `feet_y` (screen px below the body centre).
static func setup_character(sprite: Sprite2D, tex: Texture2D, feet_y: float) -> void:
	sprite.texture = tex
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.centered = true
	if tex == null:
		return
	var is_sheet := tex.resource_path.ends_with("_sheet.png")
	if is_sheet and int(tex.get_height()) % 4 == 0 and tex.get_width() >= FRAME_WIDTH:
		sprite.vframes = 4
		sprite.hframes = maxi(1, floori(tex.get_width() / float(FRAME_WIDTH)))
	else:
		sprite.vframes = 1
		sprite.hframes = 1
	var frame_h := float(tex.get_height()) / sprite.vframes
	# Sprite offset is in art pixels (before scaling).
	sprite.offset = Vector2(0, feet_y / SCALE - frame_h / 2.0)


static var _blank_top := {}


## Empty art rows above the character in the first frame (so name tags sit
## right above shorter characters too).
static func blank_rows_top(tex: Texture2D, frame_h: int) -> int:
	if tex == null:
		return 0
	var key := "%s:%d" % [tex.resource_path, frame_h]
	if _blank_top.has(key):
		return _blank_top[key]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var w := mini(FRAME_WIDTH, img.get_width())
	var rows := 0
	for y in mini(frame_h, img.get_height()):
		var empty := true
		for x in w:
			if img.get_pixel(x, y).a > 0.1:
				empty = false
				break
		if not empty:
			break
		rows += 1
	_blank_top[key] = rows
	return rows


## Picks the frame for this movement. Call every frame with the character's velocity.
static func animate_character(sprite: Sprite2D, velocity: Vector2, time: float) -> void:
	if sprite.texture == null or sprite.vframes != 4:
		return
	var row: int = sprite.frame_coords.y
	if velocity.length() > 1.0:
		if absf(velocity.x) > absf(velocity.y):
			row = Facing.RIGHT if velocity.x > 0 else Facing.LEFT
		else:
			row = Facing.DOWN if velocity.y > 0 else Facing.UP
		var col := int(time * WALK_FPS) % sprite.hframes
		sprite.frame_coords = Vector2i(col, row)
	else:
		sprite.frame_coords = Vector2i(0, row)

extends RefCounted
## Helpers for the pixel-art windows (Library, Recipe Book, Stats).
##
## The art in assets/ui/windows/ is drawn at 1 art pixel = 1 file pixel and is
## shown 4× bigger (PixelArt.SCALE), so a 40×17 button file is 160×68 on screen.
## Panels that need to grow (buttons, badges, the board) are 9-sliced: their
## corners stay sharp and only the middle stretches.
## If a file is missing, the window still works and just draws nothing there.

const PixelArt := preload("res://scenes/art/pixel_art.gd")
const SCALE := 4
const DIR := "res://assets/ui/windows/"

const INK := Color(0.24, 0.13, 0.07)          # dark brown text on paper
const INK_SOFT := Color(0.45, 0.33, 0.24)     # secondary text on paper
const INK_LOCKED := Color(0.6, 0.5, 0.4)      # locked rows
const CREAM := Color(1, 0.93, 0.8)            # text on wood
const GOLD := Color(1, 0.85, 0.5)
const RED_HEAD := Color(0.6, 0.2, 0.12)       # headings on paper

static var _cache := {}


## Texture enlarged 4× (cached). `path` is relative to assets/ui/windows/
## ("library/board.png") or a full res:// path.
static func tex(path: String) -> Texture2D:
	var full := path if path.begins_with("res://") else DIR + path
	if _cache.has(full):
		return _cache[full]
	var t: Texture2D = null
	if ResourceLoader.exists(full):
		t = PixelArt.enlarged(load(full), SCALE)
	_cache[full] = t
	return t


## Size in screen pixels of a texture (zero if missing).
static func size_of(path: String) -> Vector2:
	var t := tex(path)
	return t.get_size() if t else Vector2.ZERO


## A picture at its natural (4×) size.
static func image(parent: Control, path: String, pos: Vector2, size := Vector2.ZERO) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(path)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.position = pos
	r.size = size if size != Vector2.ZERO else size_of(path)
	parent.add_child(r)
	return r


## A 9-sliced panel. `m` = border sizes in art pixels [left, top, right, bottom].
static func panel(parent: Control, path: String, rect: Rect2, m := [4, 4, 4, 4], tile := false) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = tex(path)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.patch_margin_left = m[0] * SCALE
	p.patch_margin_top = m[1] * SCALE
	p.patch_margin_right = m[2] * SCALE
	p.patch_margin_bottom = m[3] * SCALE
	if tile:
		p.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
		p.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	p.position = rect.position
	p.size = rect.size
	parent.add_child(p)
	return p


## StyleBox from a 9-sliced picture (for buttons, line edits, badges).
static func style(path: String, m := [5, 5, 5, 6], content := Vector4(20, 8, 20, 12), tint := Color.WHITE) -> StyleBox:
	var t := tex(path)
	if t == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.29, 0.16, 0.1)
		return flat
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = m[0] * SCALE
	s.texture_margin_top = m[1] * SCALE
	s.texture_margin_right = m[2] * SCALE
	s.texture_margin_bottom = m[3] * SCALE
	s.content_margin_left = content.x
	s.content_margin_top = content.y
	s.content_margin_right = content.z
	s.content_margin_bottom = content.w
	s.modulate_color = tint
	return s


## Wood plank button (button_small.png), or the gold one.
static func button(parent: Control, text: String, rect: Rect2, gold := false, font_size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.custom_minimum_size = rect.size
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	set_button_look(b, gold, font_size)
	parent.add_child(b)
	return b


static func set_button_look(b: Button, gold: bool, font_size := 26) -> void:
	var path := "res://assets/ui/buttons/button_small_gold.png" if gold else "res://assets/ui/buttons/button_small.png"
	b.add_theme_stylebox_override("normal", style(path))
	b.add_theme_stylebox_override("hover", style(path, [5, 5, 5, 6], Vector4(20, 8, 20, 12), Color(1.12, 1.08, 1.0)))
	b.add_theme_stylebox_override("pressed", style(path, [5, 5, 5, 6], Vector4(20, 12, 20, 8), Color(0.85, 0.82, 0.78)))
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_stylebox_override("disabled", style(path, [5, 5, 5, 6], Vector4(20, 8, 20, 12), Color(0.6, 0.6, 0.6)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", font_size)
	var c := Color(0.29, 0.15, 0.06) if gold else CREAM
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, c)
	b.add_theme_constant_override("outline_size", 0)


## A text label placed at `pos`. Give `width` to align/clip it inside a box.
static func label(parent: Control, text: String, pos: Vector2, font_size := 22, color := INK,
		bold := false, width := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if font:
		l.add_theme_font_override("font", font)
	elif bold:
		l.add_theme_font_override("font", bold_font())
	if width > 0:
		l.size = Vector2(width, 0)
		l.horizontal_alignment = align
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(l)
	return l


static var _serif: Font
static var _bold: Font
static var _mono: Font


## Title font (bold serif, like the mockups).
static func serif() -> Font:
	if _serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "Cambria", "DejaVu Serif", "Times New Roman", "serif"])
		f.font_weight = 700
		f.fallbacks = [preload("res://assets/fonts/DejaVuSans.ttf")]
		_serif = f
		# The web build can't see system fonts: use the bundled serif.
		if OS.has_feature("web"):
			_serif = preload("res://assets/fonts/DejaVuSerif-Bold.ttf")
	return _serif


static func bold_font() -> Font:
	if _bold == null:
		var base: Font = ThemeDB.fallback_font
		var theme_font = ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() else null
		if theme_font:
			base = theme_font
		var v := FontVariation.new()
		v.base_font = base
		v.variation_embolden = 0.9
		_bold = v
	return _bold


static func mono() -> Font:
	if _mono == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "DejaVu Sans Mono", "Courier New", "monospace"])
		f.fallbacks = [preload("res://assets/fonts/DejaVuSans.ttf")]
		_mono = f
		if OS.has_feature("web"):
			_mono = preload("res://assets/fonts/DejaVuSansMono.ttf")
	return _mono


## Picture of a dish: assets/ui/windows/recipe_book/dish_<name>.png, else the
## in-game food icon (assets/food/dishes/<name>.png), else null.
static func dish_art(dish: String) -> Texture2D:
	var t := tex("recipe_book/dish_%s.png" % dish.to_lower())
	if t:
		return t
	return PixelArt.food_icon(dish, true, true)


## Syntax colours shared by the code editors.
static func c_highlighter(keywords: Array, unsupported: Array) -> CodeHighlighter:
	var hl := CodeHighlighter.new()
	hl.number_color = Color(0.98, 0.72, 0.45)
	hl.symbol_color = Color(0.85, 0.8, 0.7)
	hl.function_color = Color(0.55, 0.8, 1.0)
	hl.member_variable_color = Color(0.92, 0.9, 0.85)
	for k in keywords:
		hl.add_keyword_color(k, Color(1.0, 0.6, 0.45))
	for k in unsupported:
		hl.add_keyword_color(k, Color(1.0, 0.3, 0.3))
	for k in preload("res://systems/kitchen/kitchen_rules.gd").constants():
		hl.add_keyword_color(k, Color(0.96, 0.8, 0.36))
	hl.add_color_region("//", "", Color(0.5, 0.6, 0.45), true)
	hl.add_color_region("/*", "*/", Color(0.5, 0.6, 0.45))
	hl.add_color_region("\"", "\"", Color(0.95, 0.85, 0.5))
	return hl

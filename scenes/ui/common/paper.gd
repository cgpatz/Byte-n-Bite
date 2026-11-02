extends RefCounted
## "Paper Notebook" HUD style (Level 1 v2 design): rounded paper buttons and
## panels from assets/design/l1_v2/hud/. The art is 1 texture px = 1 art px and
## is shown at 4x, so every texture is scaled up once with Nearest (crisp
## pixels, whole-number scale) and used as a 9-slice StyleBoxTexture.

const DIR := "res://assets/design/l1_v2/hud/"
const K := 4  # art px -> screen px

const INK := Color("3a2a1e")
const INK_SOFT := Color("6b5442")
const FACE := Color("efe1bd")
const FACE_HOVER := Color("f8edd2")
const GOLD := Color("f3d36b")
const RED := Color("b8322b")

static var _cache := {}


## The texture scaled 4x with Nearest (cached).
static func tex(name: String, k := K) -> Texture2D:
	var key := "%s@%d" % [name, k]
	if _cache.has(key):
		return _cache[key]
	var path := DIR + name + ".png"
	if not ResourceLoader.exists(path):
		return null
	var src: Texture2D = load(path)
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## 9-slice box: margins in art px (left, top, right, bottom), content padding in screen px.
static func box(name: String, m: Vector4, pad := Vector4(16, 8, 16, 8)) -> StyleBox:
	var t := tex(name)
	if t == null:
		var f := StyleBoxFlat.new()
		f.bg_color = FACE
		f.border_color = INK
		f.set_border_width_all(4)
		f.set_corner_radius_all(14)
		return f
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = m.x * K
	sb.texture_margin_top = m.y * K
	sb.texture_margin_right = m.z * K
	sb.texture_margin_bottom = m.w * K
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


## The paper panel (taped corners, ruled lines).
static func panel(pad := Vector4(28, 34, 28, 18)) -> StyleBox:
	return box("panel_paper_9slice", Vector4(12, 9, 12, 5), pad)


## Rounded paper (or gold) text button.
static func style_button(b: Button, gold := false, font_size := 20) -> Button:
	var base := "text_button_round_gold_" if gold else "text_button_round_"
	var pad := Vector4(18, 6, 22, 12)
	b.add_theme_stylebox_override("normal", box(base + "normal", Vector4(6, 4, 7, 5), pad))
	b.add_theme_stylebox_override("hover", box(base + "hover", Vector4(6, 4, 7, 5), pad))
	b.add_theme_stylebox_override("pressed", box(base + "pressed", Vector4(6, 4, 7, 5), pad))
	b.add_theme_stylebox_override("hover_pressed", box(base + "pressed", Vector4(6, 4, 7, 5), pad))
	b.add_theme_stylebox_override("disabled", box(base + "normal", Vector4(6, 4, 7, 5), pad))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", INK_SOFT)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func button(text: String, gold := false, font_size := 20) -> Button:
	var b := Button.new()
	b.text = text
	return style_button(b, gold, font_size)


## Rounded square icon button (84 x 80 on screen) with a 12x12 icon at 4x.
static func icon_button(icon: String, gold := false) -> Button:
	var b := Button.new()
	var base := "icon_button_round_gold_" if gold else "icon_button_round_"
	var pad := Vector4(8, 8, 12, 12)
	for st in [["normal", "normal"], ["hover", "hover"], ["pressed", "pressed"], ["hover_pressed", "pressed"], ["disabled", "normal"]]:
		b.add_theme_stylebox_override(st[0], box(base + st[1], Vector4(7, 7, 8, 8), pad))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(84, 80)
	b.focus_mode = Control.FOCUS_NONE
	b.icon = tex("icon_%s_12" % icon)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.expand_icon = false
	return b


## A small key chip ("M", "Tab"...) like a keyboard key.
static func key_chip(key: String, font_size := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box("key_chip", Vector4(3, 2, 3, 2), Vector4(8, 0, 8, 0)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = key
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	return p


## Rounded paper speech bubble (the E prompt).
static func bubble(pad := Vector4(14, 8, 14, 8)) -> StyleBox:
	return box("bubble_round_9slice", Vector4(3, 3, 3, 3), pad)


## 12x12 HUD icon at 4x as a TextureRect.
static func icon(name: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex("icon_%s_12" % name)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(48, 48)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func label(text: String, font_size := 20, color := INK, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	if bold:
		l.add_theme_font_override("font", preload("res://scenes/ui/common/ui_art.gd").bold_font())
	return l

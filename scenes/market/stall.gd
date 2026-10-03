@tool
extends Station
## A Market stall (tent). The vendor stands behind the counter: the tent is
## drawn, then the vendor, then the counter again over the vendor's legs.
## Closed stalls (Café Supplies before the Café is bought) are drawn dark
## with a CLOSED sign.

## Tent art rows (art px) from the counter top down; drawn over the vendor.
const COUNTER_TOP := 30
## Where the vendor's head starts (art px from the tent's top).
const VENDOR_TOP := 11

var stall_key := ""
var vendor_tex: Texture2D
var closed := false:
	set(v):
		closed = v
		queue_redraw()


func _draw() -> void:
	var tex: Texture2D = art if art else auto_art
	if tex == null:
		super._draw()
		return
	var s := float(PixelArt.SCALE)
	var bottom := footprint_tiles().y * 64.0 / 2.0
	var tl := Vector2(-tex.get_width() * s / 2.0, bottom - tex.get_height() * s)
	var tint := Color(0.42, 0.42, 0.5) if closed else Color.WHITE
	draw_set_transform(tl, 0.0, Vector2(s, s))
	draw_texture(tex, Vector2.ZERO, tint)
	if vendor_tex and not closed:
		var fw := 16.0
		var fh := vendor_tex.get_height() / 4.0
		var vx := (tex.get_width() - fw) / 2.0
		draw_texture_rect_region(vendor_tex, Rect2(vx, VENDOR_TOP, fw, fh), Rect2(0, 0, fw, fh))
		var ch := tex.get_height() - COUNTER_TOP
		draw_texture_rect_region(tex, Rect2(0, COUNTER_TOP, tex.get_width(), ch), Rect2(0, COUNTER_TOP, tex.get_width(), ch))
	draw_set_transform(Vector2.ZERO)
	if closed:
		var sign_rect := Rect2(-70, -46, 140, 40)
		draw_rect(sign_rect, Color(0.36, 0.2, 0.1))
		draw_rect(sign_rect, Color(0.2, 0.1, 0.05), false, 4.0)
		var font := ThemeDB.fallback_font
		var w := font.get_string_size("CLOSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(font, Vector2(-w / 2.0, -17), "CLOSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.85, 0.5))


func get_prompt() -> String:
	if closed:
		return "%s (closed)" % display_name
	return "Shop at %s" % display_name

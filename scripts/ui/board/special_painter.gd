class_name SpecialPainter
extends RefCounted
## Case spéciale : dalle cernée d'encre de sa couleur et symbole selon le bonus.


static func draw(ci: CanvasItem, special: Dictionary, center: Vector2, s: float) -> void:
	var col := Color(special["color"])
	var w := Ink.width(s, 0.04)
	var r := Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)).grow(-s * 0.1)
	ci.draw_rect(r, Color(col, 0.22))
	ci.draw_rect(r, Ink.INK, false, w * 1.6)
	ci.draw_rect(r.grow(-w), Color(col, 0.9), false, w)
	var k := s * 0.16
	if special["range"] > 1.0:  # colline : deux sommets
		Ink.poly(ci, PackedVector2Array([center + Vector2(-k * 1.6, k), center + Vector2(-k * 0.3, -k), center + Vector2(k, k)]), col, w)
		Ink.poly(ci, PackedVector2Array([center + Vector2(-k * 0.2, k), center + Vector2(k * 0.8, -k * 0.4), center + Vector2(k * 1.7, k)]), col.darkened(0.25), w)
	elif special["damage"] > 1.0:  # cristal : losange à facette claire
		Ink.poly(ci, PackedVector2Array([center + Vector2(0, -k * 1.5), center + Vector2(k, 0), center + Vector2(0, k * 1.5), center + Vector2(-k, 0)]), col, w)
		ci.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -k * 1.5), center + Vector2(0, k * 1.5), center + Vector2(-k, 0)]), col.lightened(0.3))
	elif special["rate"] > 1.0:  # rune : cercle gravé
		ci.draw_arc(center, k * 1.3, 0.0, TAU, 20, Ink.INK, w * 2.4)
		ci.draw_arc(center, k * 1.3, 0.0, TAU, 20, col, w)
		ci.draw_line(center - Vector2(0, k), center + Vector2(0, k), Ink.INK, w * 2.4)
		ci.draw_line(center - Vector2(0, k), center + Vector2(0, k), col, w)
	else:  # filon d'or : pépites
		Ink.disc(ci, center + Vector2(-k * 0.6, k * 0.3), k * 0.6, col, w)
		Ink.disc(ci, center + Vector2(k * 0.7, -k * 0.2), k * 0.45, col, w)

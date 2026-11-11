class_name SpecialPainter
extends RefCounted
## Case spéciale : dalle cernée d'encre de sa couleur et symbole propre à chaque case.


static func draw(ci: CanvasItem, special: Dictionary, center: Vector2, s: float) -> void:
	var col := Color(special["color"])
	var w := Ink.width(s, 0.04)
	var r := Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)).grow(-s * 0.1)
	ci.draw_rect(r, Color(col, 0.22))
	ci.draw_rect(r, Ink.INK, false, w * 1.6)
	ci.draw_rect(r.grow(-w), Color(col, 0.9), false, w)
	_glyph(ci, special["id"], col, center, s * 0.16, w)


static func _glyph(ci: CanvasItem, id: String, col: Color, c: Vector2, k: float, w: float) -> void:
	match id:
		"hill", "mound", "lookout":  # sommets (le Belvédère a sa tour de guet)
			_peaks(ci, col, c, k, w)
			if id == "lookout":
				_stroke(ci, c + Vector2(-k * 0.3, -k), c + Vector2(-k * 0.3, -k * 2.0), col, w)
		"crystal", "obsidian", "altar":  # pierre taillée
			var gem := PackedVector2Array([c + Vector2(0, -k * 1.5), c + Vector2(k, 0), c + Vector2(0, k * 1.5), c + Vector2(-k, 0)])
			Ink.poly(ci, gem, col, w)
			ci.draw_colored_polygon(PackedVector2Array([gem[0], gem[2], gem[3]]), col.lightened(0.3))
			if id == "altar":
				ci.draw_rect(Rect2(c + Vector2(-k * 1.4, k * 1.1), Vector2(k * 2.8, k * 0.5)), Ink.INK)
		"rune", "bell", "islet":  # cercle gravé (Cloche : battant ; Îlot : vagues)
			ci.draw_arc(c, k * 1.3, 0.0, TAU, 20, Ink.INK, w * 2.4)
			ci.draw_arc(c, k * 1.3, 0.0, TAU, 20, col, w)
			if id == "rune":
				_stroke(ci, c - Vector2(0, k), c + Vector2(0, k), col, w)
			elif id == "bell":
				Ink.disc(ci, c + Vector2(0, k * 0.4), k * 0.4, col, w)
			else:
				ci.draw_arc(c + Vector2(0, k * 0.3), k * 0.7, PI, TAU, 8, col, w)
		"hunt", "unstable":  # pépites (instable : fissure)
			Ink.disc(ci, c + Vector2(-k * 0.6, k * 0.3), k * 0.6, col, w)
			Ink.disc(ci, c + Vector2(k * 0.7, -k * 0.2), k * 0.45, col, w)
			if id == "unstable":
				_stroke(ci, c + Vector2(-k * 1.2, -k * 1.2), c + Vector2(k * 1.2, k * 1.2), Ink.INK, w)
		"campfire":  # flamme
			Ink.poly(ci, PackedVector2Array([c + Vector2(0, -k * 1.6), c + Vector2(k, k * 0.6), c + Vector2(0, k * 1.2), c + Vector2(-k, k * 0.6)]), col, w)
			ci.draw_circle(c + Vector2(0, k * 0.5), k * 0.4, Color("#ffe08a"))
		"cooled", "bog":  # goutte
			Ink.disc(ci, c + Vector2(0, k * 0.4), k * 0.9, col, w)
			Ink.poly(ci, PackedVector2Array([c + Vector2(0, -k * 1.5), c + Vector2(k * 0.7, 0), c + Vector2(-k * 0.7, 0)]), col, w)
		"menhir":  # pierre levée frappée d'un éclair
			Ink.poly(ci, PackedVector2Array([c + Vector2(-k * 0.6, k * 1.4), c + Vector2(-k * 0.4, -k * 1.4), c + Vector2(k * 0.5, -k * 1.2), c + Vector2(k * 0.6, k * 1.4)]), col, w)
			_stroke(ci, c + Vector2(k * 0.2, -k), c + Vector2(-k * 0.2, k * 0.2), Ink.PAPER, w)
		"crowsnest":  # oiseau en vol
			ci.draw_arc(c + Vector2(-k * 0.6, 0), k * 0.7, PI * 1.1, PI * 1.9, 8, Ink.INK, w * 2.4)
			ci.draw_arc(c + Vector2(k * 0.6, 0), k * 0.7, PI * 1.1, PI * 1.9, 8, Ink.INK, w * 2.4)
			ci.draw_arc(c + Vector2(-k * 0.6, 0), k * 0.7, PI * 1.1, PI * 1.9, 8, col, w)
			ci.draw_arc(c + Vector2(k * 0.6, 0), k * 0.7, PI * 1.1, PI * 1.9, 8, col, w)
		"bloodstone":  # cœur de pierre
			Ink.disc(ci, c + Vector2(-k * 0.5, -k * 0.3), k * 0.6, col, w)
			Ink.disc(ci, c + Vector2(k * 0.5, -k * 0.3), k * 0.6, col, w)
			Ink.poly(ci, PackedVector2Array([c + Vector2(-k * 1.05, 0), c + Vector2(k * 1.05, 0), c + Vector2(0, k * 1.3)]), col, w)
		"forge":  # enclume
			Ink.poly(ci, PackedVector2Array([c + Vector2(-k * 1.4, -k * 0.6), c + Vector2(k * 1.4, -k * 0.6), c + Vector2(k * 0.6, k * 0.2), c + Vector2(-k * 0.6, k * 0.2)]), col, w)
			ci.draw_rect(Rect2(c + Vector2(-k * 0.8, k * 0.2), Vector2(k * 1.6, k * 0.9)), col.darkened(0.3))
		"ditch":  # tranchée
			ci.draw_rect(Rect2(c + Vector2(-k * 1.4, -k * 0.4), Vector2(k * 2.8, k * 0.8)), col.darkened(0.4))
		_:
			Ink.disc(ci, c, k, col, w)


static func _peaks(ci: CanvasItem, col: Color, c: Vector2, k: float, w: float) -> void:
	Ink.poly(ci, PackedVector2Array([c + Vector2(-k * 1.6, k), c + Vector2(-k * 0.3, -k), c + Vector2(k, k)]), col, w)
	Ink.poly(ci, PackedVector2Array([c + Vector2(-k * 0.2, k), c + Vector2(k * 0.8, -k * 0.4), c + Vector2(k * 1.7, k)]), col.darkened(0.25), w)


static func _stroke(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, Ink.INK, w * 2.4)
	ci.draw_line(a, b, col, w)

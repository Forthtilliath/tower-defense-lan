class_name ElementGlyphs
extends RefCounted
## Silhouettes des tourelles élémentaires (foudre, feu, glace, poison, saignement).
## mono : passe d'ombre, toutes les couleurs deviennent de l'encre (voir TowerGlyphs).


## Dessine la silhouette ; renvoie false si l'identifiant n'est pas une tourelle élémentaire.
static func draw(ci: CanvasItem, id: String, col: Color, c: Vector2, r: float, mono: bool) -> bool:
	var white := Color(Ink.INK) if mono else Color.WHITE
	var dark := Color(Ink.INK) if mono else col.darkened(0.45)
	var hot := Color(Ink.INK) if mono else Color("#ffe08a")
	match id:
		"pylon":  # pylône en treillis et arcs au sommet
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, r * 1.1), c + Vector2(0, -r * 0.9), c + Vector2(r * 0.8, r * 1.1)]), col)
			ci.draw_line(c + Vector2(-r * 0.45, r * 0.3), c + Vector2(r * 0.45, r * 0.3), dark, 2.0)
			ci.draw_arc(c - Vector2(0, r * 0.9), r * 0.55, PI * 1.1, PI * 1.9, 10, white, 2.0)
			ci.draw_arc(c - Vector2(0, r * 0.9), r * 0.9, PI * 1.2, PI * 1.8, 10, white, 1.5)
		"railgun":  # double rail et pointe d'éclair
			ci.draw_circle(c, r * 0.7, dark)
			for k in [-1, 1]:
				var o: Vector2 = Vector2(r * 0.25, r * 0.25) * k
				ci.draw_line(c + Vector2(-r * 0.9, r * 0.9) + o, c + Vector2(r * 1.0, -r * 1.0) + o, col, 3.0)
			ci.draw_circle(c + Vector2(r * 1.05, -r * 1.05), r * 0.25, white)
		"salamander":  # bec et langue de feu
			ci.draw_circle(c + Vector2(0, r * 0.35), r * 0.8, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.25, -r * 0.2), c + Vector2(-r * 0.9, -r * 1.4), c + Vector2(0, -r * 0.9), c + Vector2(r * 0.9, -r * 1.4), c + Vector2(r * 0.25, -r * 0.2)]), hot)
			ci.draw_circle(c + Vector2(0, r * 0.35), r * 0.3, dark)
		"greek_fire":  # amphore et flammèche
			ci.draw_circle(c + Vector2(0, r * 0.35), r * 0.85, col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.8), Vector2(r * 0.6, r * 0.7)), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, -r * 0.8), c + Vector2(0, -r * 1.5), c + Vector2(r * 0.3, -r * 0.8)]), hot)
			ci.draw_line(c + Vector2(-r * 0.6, r * 0.3), c + Vector2(r * 0.6, r * 0.3), dark, 2.0)
		"lens":  # lentille cerclée et rayons
			ci.draw_circle(c, r * 0.75, col.lightened(0.3) if not mono else col)
			ci.draw_arc(c, r * 0.85, 0.0, TAU, 20, dark, 3.0)
			ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.25), r * 0.2, white)
			for k in 4:
				var d := Vector2.from_angle(PI * 0.25 + PI * 0.5 * k)
				ci.draw_line(c + d * r * 1.05, c + d * r * 1.45, col, 2.0)
		"obelisk":  # pilier de glace effilé
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.5), c + Vector2(r * 0.55, -r * 0.6), c + Vector2(r * 0.45, r * 1.1), c + Vector2(-r * 0.45, r * 1.1), c + Vector2(-r * 0.55, -r * 0.6)]), col)
			ci.draw_line(c + Vector2(0, -r * 1.3), c + Vector2(0, r * 1.0), white, 1.5)
		"icebreaker":  # pic à glace
			ci.draw_line(c + Vector2(-r * 0.9, r * 1.1), c + Vector2(r * 0.4, -r * 0.4), dark, 3.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 1.2), c + Vector2(r * 1.3, -r * 0.1), c + Vector2(r * 0.7, -r * 0.9)]), col)
			ci.draw_circle(c + Vector2(r * 0.5, -r * 0.7), r * 0.18, white)
		"alembic":  # fiole à col
			ci.draw_circle(c + Vector2(0, r * 0.4), r * 0.85, col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.22, -r * 1.3), Vector2(r * 0.44, r * 1.0)), col)
			ci.draw_circle(c + Vector2(-r * 0.25, r * 0.3), r * 0.18, white)
			ci.draw_circle(c + Vector2(r * 0.3, r * 0.6), r * 0.12, white)
		"miasma":  # nuage
			for k in [[-0.55, 0.2, 0.6], [0.55, 0.2, 0.6], [0.0, -0.3, 0.75], [0.0, 0.45, 0.55]]:
				ci.draw_circle(c + Vector2(k[0], k[1]) * r, r * k[2], col)
			ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.35), r * 0.15, white)
		"plague":  # trois spores reliées
			ci.draw_circle(c, r * 0.5, dark)
			for k in 3:
				var d := Vector2.from_angle(-PI / 2.0 + TAU * k / 3.0)
				ci.draw_line(c, c + d * r * 0.9, col, 2.5)
				ci.draw_circle(c + d * r * 0.95, r * 0.42, col)
			ci.draw_circle(c, r * 0.22, white)
		"scythe":  # lame courbe et manche
			ci.draw_line(c + Vector2(-r * 0.6, r * 1.2), c + Vector2(r * 0.4, -r * 1.1), dark, 3.0)
			ci.draw_arc(c + Vector2(-r * 0.2, -r * 0.6), r * 0.9, PI * 1.05, PI * 1.85, 12, col, 4.0)
			ci.draw_circle(c + Vector2(r * 0.4, -r * 1.1), r * 0.15, white)
		_:
			return false
	return true

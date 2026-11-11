class_name SpecGlyphs
extends RefCounted
## Silhouettes des tourelles propres aux spécialisations (Rafale, Tourbillon, Stèle de gelure,
## Paratonnerre, Phare, Comptoir, Chantier). mono : passe d'ombre (voir TowerGlyphs).


## Dessine la silhouette ; renvoie false si l'identifiant n'est pas l'une de ces tourelles.
static func draw(ci: CanvasItem, id: String, col: Color, c: Vector2, r: float, mono: bool) -> bool:
	var white := Color(Ink.INK) if mono else Color.WHITE
	var dark := Color(Ink.INK) if mono else col.darkened(0.45)
	match id:
		"gatling":  # barillet de quatre canons
			ci.draw_circle(c, r * 0.95, col)
			for k in 4:
				var a := TAU * k / 4.0 + PI / 4.0
				ci.draw_circle(c + Vector2.from_angle(a) * r * 0.5, r * 0.22, dark)
			ci.draw_line(c, c - Vector2(0, r * 1.5), white, 2.0)
		"whirlwind":  # spirale de vent
			for k in 3:
				var rad := r * (0.45 + 0.35 * k)
				ci.draw_arc(c, rad, PI * (0.2 + 0.4 * k), PI * (1.5 + 0.4 * k), 14, col if k < 2 else white, 3.0 - k * 0.6)
			ci.draw_circle(c, r * 0.25, dark)
		"frost_stele":  # pierre levée givrée
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, r * 1.1), c + Vector2(-r * 0.45, -r * 0.9),
				c + Vector2(0, -r * 1.25), c + Vector2(r * 0.45, -r * 0.9), c + Vector2(r * 0.6, r * 1.1)]), col)
			ci.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.4), white, 2.0)
			ci.draw_line(c + Vector2(-r * 0.35, -r * 0.1), c + Vector2(r * 0.35, -r * 0.1), white, 2.0)
		"lightning_rod":  # mât et pointe, arcs de chaque côté
			ci.draw_line(c + Vector2(0, r * 1.1), c + Vector2(0, -r * 1.3), dark, 3.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.25, -r * 0.9), c + Vector2(0, -r * 1.5), c + Vector2(r * 0.25, -r * 0.9)]), col)
			for side in [-1.0, 1.0]:
				ci.draw_arc(c + Vector2(0, -r * 0.5), r * 0.7, PI * (1.0 if side < 0 else 1.75), PI * (1.25 if side < 0 else 2.0), 6, col, 2.0)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, r * 0.8), Vector2(r * 1.4, r * 0.35)), col)
		"beacon":  # tour et feu, faisceaux
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, r * 1.1), c + Vector2(-r * 0.3, -r * 0.5), c + Vector2(r * 0.3, -r * 0.5), c + Vector2(r * 0.55, r * 1.1)]), col)
			ci.draw_circle(c - Vector2(0, r * 0.75), r * 0.35, white)
			for side in [-1.0, 1.0]:
				ci.draw_line(c - Vector2(0, r * 0.75), c + Vector2(side * r * 1.3, -r * 1.1), white, 1.5)
		"counter":  # coffre et pièce
			ci.draw_rect(Rect2(c - Vector2(r * 0.95, r * 0.4), Vector2(r * 1.9, r * 1.2)), col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.95, r * 0.75), Vector2(r * 1.9, r * 0.4)), dark)
			ci.draw_circle(c + Vector2(0, -r * 1.1), r * 0.38, white if mono else Color("#ffd54a"))
		"worksite":  # grue
			ci.draw_line(c + Vector2(-r * 0.4, r * 1.1), c + Vector2(-r * 0.4, -r * 1.1), col, 3.5)
			ci.draw_line(c + Vector2(-r * 1.0, -r * 1.0), c + Vector2(r * 1.2, -r * 1.0), col, 3.0)
			ci.draw_line(c + Vector2(r * 0.9, -r * 1.0), c + Vector2(r * 0.9, r * 0.1), white, 1.5)
			ci.draw_rect(Rect2(c + Vector2(r * 0.65, r * 0.1), Vector2(r * 0.5, r * 0.4)), dark)
		_:
			return false
	return true

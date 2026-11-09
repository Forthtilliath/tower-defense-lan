class_name TowerGlyphs
extends RefCounted
## Silhouette dessinée de chaque tourelle (sans image), choisie par son identifiant.


static func draw(ci: CanvasItem, id: String, col: Color, c: Vector2, r: float) -> void:
	match id:
		"crossbow":  # arc et carreau
			ci.draw_circle(c, r, col)
			ci.draw_arc(c, r * 1.2, PI * 1.15, PI * 1.85, 12, col.lightened(0.4), 3.0)
			ci.draw_line(c, c - Vector2(0, r * 1.5), Color.WHITE, 2.0)
		"cannon":  # fût épais
			ci.draw_circle(c, r * 1.05, col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.35, r * 1.6), Vector2(r * 0.7, r * 1.2)), col.darkened(0.35))
		"frost":  # cristal hexagonal
			ci.draw_colored_polygon(ngon(c, r * 1.2, 6, -PI / 2.0), col)
			ci.draw_circle(c, r * 0.45, Color.WHITE)
		"ballista":  # longue arbalète
			ci.draw_circle(c, r * 0.9, col)
			ci.draw_line(c + Vector2(-r * 1.3, -r * 0.2), c + Vector2(r * 1.3, -r * 0.2), col.lightened(0.3), 4.0)
			ci.draw_line(c, c - Vector2(0, r * 1.7), Color.WHITE, 3.0)
		"tesla":  # bobine et éclair
			ci.draw_circle(c, r, col.darkened(0.3))
			ci.draw_circle(c, r * 0.6, col)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.3, -r * 1.4), c + Vector2(r * 0.2, -r * 0.6), c + Vector2(-r * 0.2, -r * 0.4), c + Vector2(r * 0.3, r * 0.4)]), Color.WHITE, 2.0)
		"venom":  # goutte
			ci.draw_circle(c + Vector2(0, r * 0.25), r * 0.85, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, 0), c + Vector2(0, -r * 1.3), c + Vector2(r * 0.6, 0)]), col)
			ci.draw_circle(c + Vector2(-r * 0.25, r * 0.1), r * 0.2, Color(1, 1, 1, 0.8))
		"mortar":  # bouche large inclinée
			ci.draw_circle(c, r * 1.1, col)
			ci.draw_circle(c + Vector2(r * 0.3, -r * 0.4), r * 0.55, col.darkened(0.55))
		"sentinel":  # radar
			ci.draw_circle(c, r * 0.75, col.darkened(0.2))
			ci.draw_arc(c, r * 1.3, PI * 1.1, PI * 1.9, 14, col, 3.0)
			ci.draw_line(c, c + Vector2(r * 0.9, -r * 1.1), Color.WHITE, 2.0)
		"dart":  # trois petites fléchettes
			for k in 3:
				var x := (k - 1) * r * 0.65
				ci.draw_line(c + Vector2(x, r * 0.9), c + Vector2(x, -r * 0.9), col, 2.5)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - r * 0.25, -r * 0.6), c + Vector2(x, -r * 1.2), c + Vector2(x + r * 0.25, -r * 0.6)]), Color.WHITE)
		"crusher":  # bloc carré massif
			ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.5, r * 0.5), Vector2(r, r)), col.darkened(0.45))
		"brazier":  # flamme
			ci.draw_circle(c + Vector2(0, r * 0.35), r * 0.8, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, r * 0.2), c + Vector2(0, -r * 1.4), c + Vector2(r * 0.7, r * 0.2)]), col)
			ci.draw_circle(c + Vector2(0, r * 0.35), r * 0.4, Color("#ffe08a"))
		"thorns":  # étoile à pointes
			ci.draw_colored_polygon(star(c, r * 1.3, r * 0.5, 6), col)
		"gong":  # disque et ondes
			ci.draw_circle(c, r * 0.8, col)
			ci.draw_arc(c, r * 1.25, 0.0, TAU, 20, col.lightened(0.3), 2.0)
			ci.draw_circle(c, r * 0.25, col.darkened(0.4))
		"scarecrow":  # croix et chapeau
			ci.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 1.2), col.darkened(0.3), 3.0)
			ci.draw_line(c + Vector2(-r * 1.1, 0), c + Vector2(r * 1.1, 0), col.darkened(0.3), 3.0)
			ci.draw_circle(c - Vector2(0, r * 0.7), r * 0.45, col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.7, r * 1.2), Vector2(r * 1.4, r * 0.25)), col.darkened(0.5))
		"flute":  # flûte et note
			ci.draw_line(c + Vector2(-r * 1.1, r * 0.8), c + Vector2(r * 1.1, -r * 0.8), col, 4.0)
			ci.draw_circle(c + Vector2(r * 0.4, r * 0.7), r * 0.3, Color.WHITE)
			ci.draw_line(c + Vector2(r * 0.65, r * 0.7), c + Vector2(r * 0.65, -r * 0.2), Color.WHITE, 2.0)
		"drum":  # tambour
			ci.draw_rect(Rect2(c - Vector2(r * 0.9, r * 0.6), Vector2(r * 1.8, r * 1.2)), col)
			ci.draw_line(c + Vector2(-r * 0.9, -r * 0.6), c + Vector2(r * 0.9, r * 0.6), Color(1, 1, 1, 0.6), 1.5)
			ci.draw_line(c + Vector2(-r * 0.9, r * 0.6), c + Vector2(r * 0.9, -r * 0.6), Color(1, 1, 1, 0.6), 1.5)
		"banner":  # mât et drapeau
			ci.draw_line(c + Vector2(-r * 0.6, r * 1.2), c + Vector2(-r * 0.6, -r * 1.2), Color.WHITE, 2.5)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 1.2), c + Vector2(r * 1.0, -r * 0.7), c + Vector2(-r * 0.6, -r * 0.1)]), col)
		"totem":  # empilement de têtes
			for k in 3:
				var y := (k - 1) * r * 0.75
				ci.draw_rect(Rect2(c + Vector2(-r * 0.55, y - r * 0.33), Vector2(r * 1.1, r * 0.66)), col.darkened(0.15 * k))
				ci.draw_circle(c + Vector2(-r * 0.2, y), r * 0.1, Color.WHITE)
				ci.draw_circle(c + Vector2(r * 0.2, y), r * 0.1, Color.WHITE)
		_:
			ci.draw_circle(c, r, col)


static func ngon(c: Vector2, r: float, n: int, start: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		pts.append(c + Vector2.from_angle(start + TAU * k / n) * r)
	return pts


static func star(c: Vector2, outer: float, inner: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in points * 2:
		var rad := outer if k % 2 == 0 else inner
		pts.append(c + Vector2.from_angle(-PI / 2.0 + PI * k / points) * rad)
	return pts

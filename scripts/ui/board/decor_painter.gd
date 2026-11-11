class_name DecorPainter
extends RefCounted
## Décor propre à chaque thème : ce qui tient lieu d'arbre (« T ») et de rocher (« # »), et les
## petits détails dessinés sur le sol constructible. Le jeu ne change pas : un arbre reste un arbre
## que le Terrassier peut raser, quel que soit son dessin.


## Arbre du thème ; renvoie faux pour le conifère de la Prairie (dessiné par TerrainPainter).
static func tree(ci: CanvasItem, theme: String, index: int, c: Vector2, s: float, w: float) -> bool:
	match theme:
		"tundra":  # sapin enneigé
			_fir(ci, c, s, w, Color("#2f4a3a"), Color("#f4f8fa"))
		"volcano":  # tronc calciné
			_shadow(ci, c, s)
			ci.draw_line(c + Vector2(0, s * 0.4), c + Vector2(0, -s * 0.4), Ink.INK, w * 3.0)
			ci.draw_line(c + Vector2(0, -s * 0.1), c + Vector2(s * 0.25, -s * 0.35), Ink.INK, w * 2.0)
			ci.draw_line(c + Vector2(0, s * 0.05), c + Vector2(-s * 0.22, -s * 0.2), Ink.INK, w * 2.0)
			ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.06, Color("#ff7a2a"))
		"swamp":  # roseaux
			for k in 4:
				var x := (k - 1.5) * s * 0.14 + (Ink.noise(index, k) - 0.5) * s * 0.06
				var top := c + Vector2(x, -s * (0.3 + 0.15 * Ink.noise(index, k + 3)))
				ci.draw_line(c + Vector2(x, s * 0.38), top, Color("#3a4a26"), w * 1.4)
				Ink.ellipse(ci, top + Vector2(0, s * 0.06), s * 0.04, s * 0.1, Color("#6a4a2a"))
		"necropolis":  # cyprès
			_shadow(ci, c, s)
			Ink.poly(ci, PackedVector2Array([c + Vector2(0, -s * 0.62), c + Vector2(s * 0.17, s * 0.1), c + Vector2(0, s * 0.38), c + Vector2(-s * 0.17, s * 0.1)]), Color("#1f2e26"), w)
		"canyon":  # cactus
			_shadow(ci, c, s)
			var green := Color("#4a7a3a")
			ci.draw_line(c + Vector2(0, s * 0.38), c + Vector2(0, -s * 0.45), Ink.INK, w * 5.0)
			ci.draw_line(c + Vector2(0, s * 0.38), c + Vector2(0, -s * 0.45), green, w * 3.0)
			for side in [-1.0, 1.0]:
				var a := c + Vector2(0, -s * 0.05 * side)
				var b := a + Vector2(s * 0.2 * side, 0)
				ci.draw_polyline(PackedVector2Array([a, b, b + Vector2(0, -s * 0.22)]), Ink.INK, w * 4.0)
				ci.draw_polyline(PackedVector2Array([a, b, b + Vector2(0, -s * 0.22)]), green, w * 2.2)
		"forest":  # grand feuillu
			_shadow(ci, c, s)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.06, s * 0.05), Vector2(s * 0.12, s * 0.35)), Color("#4a3020"))
			Ink.disc(ci, c + Vector2(0, -s * 0.2), s * 0.34, Color("#2e5a2a"), w)
			ci.draw_circle(c + Vector2(-s * 0.1, -s * 0.3), s * 0.14, Color("#46803a"))
		_:
			return false
	return true


## Rocher du thème ; renvoie faux pour le rocher de la Prairie (dessiné par TerrainPainter).
static func rock(ci: CanvasItem, theme: String, index: int, c: Vector2, s: float, w: float) -> bool:
	match theme:
		"tundra":  # bloc de glace
			_block(ci, c, s, w, Color("#bfe4f4"), Color("#eaf7fc"))
		"volcano":  # roche noire fendue de lave
			_block(ci, c, s, w, Color("#2a2220"), Color("#3e3430"))
			ci.draw_line(c + Vector2(-s * 0.15, -s * 0.1), c + Vector2(s * 0.12, s * 0.15), Color("#ff6a20"), w * 1.4)
		"swamp":  # souche
			_shadow(ci, c, s)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.05), Vector2(s * 0.44, s * 0.35)), Color("#5a4028"))
			Ink.ellipse(ci, c + Vector2(0, -s * 0.05), s * 0.22, s * 0.08, Color("#8a6a40"))
		"necropolis":  # pierre tombale
			_shadow(ci, c, s)
			var r := Rect2(c + Vector2(-s * 0.2, -s * 0.2), Vector2(s * 0.4, s * 0.55))
			ci.draw_rect(r, Ink.STONE)
			ci.draw_circle(Vector2(c.x, r.position.y), s * 0.2, Ink.STONE)
			ci.draw_line(c + Vector2(0, -s * 0.15), c + Vector2(0, s * 0.15), Ink.INK, w)
			ci.draw_line(c + Vector2(-s * 0.1, -s * 0.05), c + Vector2(s * 0.1, -s * 0.05), Ink.INK, w)
		"canyon":  # rocher rouge
			_block(ci, c, s, w, Color("#a0522d"), Color("#c46a3a"))
		"forest":  # gros champignon
			_shadow(ci, c, s)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.05), Vector2(s * 0.16, s * 0.4)), Color("#efe4cf"))
			Ink.poly(ci, PackedVector2Array([c + Vector2(-s * 0.35, 0), c + Vector2(0, -s * 0.35), c + Vector2(s * 0.35, 0)]), Color("#b0302a"), w)
			ci.draw_circle(c + Vector2(-s * 0.08, -s * 0.12), s * 0.05, Ink.PAPER)
			ci.draw_circle(c + Vector2(s * 0.12, -s * 0.06), s * 0.04, Ink.PAPER)
		_:
			return false
	return true


## Petit détail du sol constructible (une case sur deux environ) : herbe, neige, braise, os…
static func ground_detail(ci: CanvasItem, theme: String, index: int, r: Rect2, w: float) -> void:
	var s := r.size.x
	var p := r.position + Vector2(0.2 + 0.6 * Ink.noise(index, 2), 0.3 + 0.5 * Ink.noise(index, 3)) * s
	var col := Color(MapTheme.detail(theme), 0.35)
	match theme:
		"tundra", "volcano":  # flocons ou braises
			ci.draw_circle(p, maxf(1.0, s * 0.03), col)
			ci.draw_circle(p + Vector2(s * 0.18, s * 0.08), maxf(1.0, s * 0.02), col)
		"necropolis", "canyon":  # fissure ou caillou
			ci.draw_line(p, p + Vector2(s * 0.12, s * 0.05), col, w)
			ci.draw_line(p + Vector2(s * 0.12, s * 0.05), p + Vector2(s * 0.18, -s * 0.04), col, w)
		_:  # touffe d'herbe
			var k := s * 0.07
			ci.draw_line(p, p + Vector2(-k, -k * 1.4), col, w)
			ci.draw_line(p, p + Vector2(0, -k * 1.8), col, w)
			ci.draw_line(p, p + Vector2(k, -k * 1.4), col, w)


static func _shadow(ci: CanvasItem, c: Vector2, s: float) -> void:
	Ink.ellipse(ci, c + Vector2(0, s * 0.4), s * 0.3, s * 0.08, Color(Ink.INK, 0.3))


static func _fir(ci: CanvasItem, c: Vector2, s: float, w: float, dark: Color, snow: Color) -> void:
	_shadow(ci, c, s)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.05, s * 0.15), Vector2(s * 0.1, s * 0.25)), Color("#4a3428"))
	for k in 3:
		var top := c + Vector2(0, -s * (0.62 - 0.22 * k))
		var half := s * (0.2 + 0.07 * k)
		var base_y := top.y + s * (0.38 + 0.02 * k)
		Ink.poly(ci, PackedVector2Array([top, Vector2(c.x + half, base_y), Vector2(c.x - half, base_y)]), dark, w)
		ci.draw_colored_polygon(PackedVector2Array([top, top + Vector2(half * 0.5, s * 0.14), top + Vector2(-half * 0.5, s * 0.14)]), snow)


static func _block(ci: CanvasItem, c: Vector2, s: float, w: float, dark: Color, light: Color) -> void:
	Ink.ellipse(ci, c + Vector2(0, s * 0.28), s * 0.36, s * 0.1, Color(Ink.INK, 0.3))
	var pts := PackedVector2Array([c + Vector2(-s * 0.3, s * 0.25), c + Vector2(-s * 0.25, -s * 0.2), c + Vector2(s * 0.05, -s * 0.32),
		c + Vector2(s * 0.3, -s * 0.12), c + Vector2(s * 0.28, s * 0.25)])
	Ink.poly(ci, pts, dark, w)
	ci.draw_colored_polygon(PackedVector2Array([pts[1], pts[2], c + Vector2(0, 0), pts[0]]), light)

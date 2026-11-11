class_name TerrainPainter
extends RefCounted
## Décor du plateau au style manga : herbe olive, route poussiéreuse cernée d'encre, forêt de
## conifères, rochers, vagues, brèche fumante (départ) et pan de rempart (arrivée).
## Dessiné une seule fois par TerrainLayer (pas à chaque image).

const COLORS := {
	MapDef.Cell.BUILD: Color("#7a8a52"), MapDef.Cell.ROUTE: Color("#c4a978"),
	MapDef.Cell.START: Color("#c4a978"), MapDef.Cell.END: Color("#c4a978"),
	MapDef.Cell.ROCK: Color("#6d7c48"), MapDef.Cell.WATER: Color("#46708c"),
	MapDef.Cell.TREE: Color("#6d7c48"),
}


static func is_road(kind: int) -> bool:
	return kind == MapDef.Cell.ROUTE or kind == MapDef.Cell.START or kind == MapDef.Cell.END


## Fond de case et texture (premier passage, avant les contours et les éléments hauts).
static func ground(ci: CanvasItem, map: MapDef, index: int, r: Rect2) -> void:
	var kind := map.cells[index]
	var c := map.cell_coords(index)
	var col: Color = COLORS[kind]
	if not is_road(kind) and kind != MapDef.Cell.WATER and (c.x + c.y) % 2 == 0:
		col = col.lightened(0.04)
	ci.draw_rect(r, col)
	var s := r.size.x
	var w := Ink.width(s, 0.03)
	if is_road(kind):  # cailloux et trame de points
		for k in 3:
			var p := r.position + Vector2(0.15 + 0.7 * Ink.noise(index, k), 0.15 + 0.7 * Ink.noise(index, k + 9)) * s
			ci.draw_circle(p, maxf(1.0, s * 0.035), col.darkened(0.22))
	elif kind == MapDef.Cell.WATER:  # vagues stylisées
		for k in 2:
			var p := r.position + Vector2(0.3 + 0.4 * k, 0.35 + 0.3 * k) * s
			ci.draw_arc(p, s * 0.13, PI, TAU, 8, Color(Ink.PAPER, 0.65), w)
			ci.draw_arc(p + Vector2(s * 0.26, 0), s * 0.13, PI, TAU, 8, Color(Ink.PAPER, 0.65), w)
	elif kind == MapDef.Cell.BUILD and Ink.noise(index, 1) < 0.5:  # touffe d'herbe à l'encre
		var p := r.position + Vector2(0.2 + 0.6 * Ink.noise(index, 2), 0.3 + 0.5 * Ink.noise(index, 3)) * s
		var k := s * 0.07
		var tuft := Color(Ink.INK, 0.28)
		ci.draw_line(p, p + Vector2(-k, -k * 1.4), tuft, w)
		ci.draw_line(p, p + Vector2(0, -k * 1.8), tuft, w)
		ci.draw_line(p, p + Vector2(k, -k * 1.4), tuft, w)


## Liserés d'encre là où la route (ou l'eau) touche un autre terrain.
static func edges(ci: CanvasItem, map: MapDef, index: int, r: Rect2) -> void:
	var kind := map.cells[index]
	var water := kind == MapDef.Cell.WATER
	if not is_road(kind) and not water:
		return
	var c := map.cell_coords(index)
	var w := Ink.width(r.size.x, 0.06)
	var same := func(i: int) -> bool: return (map.cells[i] == MapDef.Cell.WATER) if water else is_road(map.cells[i])
	if c.y > 0 and not same.call(index - map.width):
		ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Ink.INK, w)
	if c.y + 1 < map.height and not same.call(index + map.width):
		ci.draw_line(Vector2(r.position.x, r.end.y), r.end, Ink.INK, w)
	if c.x > 0 and not same.call(index - 1):
		ci.draw_line(r.position, Vector2(r.position.x, r.end.y), Ink.INK, w)
	if c.x + 1 < map.width and not same.call(index + 1):
		ci.draw_line(Vector2(r.end.x, r.position.y), r.end, Ink.INK, w)


## Éléments hauts (dernier passage : ils peuvent déborder sur la case du dessus).
static func props(ci: CanvasItem, map: MapDef, data: GameData, index: int, r: Rect2) -> void:
	var center := r.get_center()
	var s := r.size.x
	var w := Ink.width(s)
	match map.cells[index]:
		MapDef.Cell.BUILD:
			var special := map.special_at(index)
			if special >= 0 and data != null:
				SpecialPainter.draw(ci, data.specials[special], center, s)
		MapDef.Cell.ROCK:
			_rock(ci, index, center, s, w)
		MapDef.Cell.TREE:
			_tree(ci, center, s, w)
		MapDef.Cell.START:
			_breach(ci, index, center, s, w)
		MapDef.Cell.END:
			_wall(ci, center, s, w)


static func _rock(ci: CanvasItem, index: int, c: Vector2, s: float, w: float) -> void:
	Ink.ellipse(ci, c + Vector2(0, s * 0.28), s * 0.36, s * 0.1, Color(Ink.INK, 0.3))
	var pts := PackedVector2Array()
	for k in 7:
		pts.append(c + Vector2.from_angle(TAU * k / 7.0 - PI / 2.0) * s * (0.26 + 0.1 * Ink.noise(index, k)) * Vector2(1.15, 0.9))
	Ink.poly(ci, pts, Ink.STONE_DARK, w)
	var lit := PackedVector2Array()
	for p in pts:
		lit.append(c + (p - c) * 0.72 - Vector2(s, s) * 0.05)
	ci.draw_colored_polygon(lit, Ink.STONE)
	for k in 2:  # hachures dans l'ombre
		var p := c + Vector2(s * (0.08 + 0.08 * k), s * 0.08)
		ci.draw_line(p, p + Vector2(s * 0.06, s * 0.1), Color(Ink.INK, 0.6), maxf(1.0, w * 0.6))


## Conifère de la grande forêt : trois étages, moitié gauche éclairée.
static func _tree(ci: CanvasItem, c: Vector2, s: float, w: float) -> void:
	Ink.ellipse(ci, c + Vector2(0, s * 0.4), s * 0.3, s * 0.08, Color(Ink.INK, 0.3))
	ci.draw_rect(Rect2(c + Vector2(-s * 0.06, s * 0.15), Vector2(s * 0.12, s * 0.27)), Ink.INK)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.035, s * 0.15), Vector2(s * 0.07, s * 0.25)), Color("#5a4030"))
	for k in 3:
		var top := c + Vector2(0, -s * (0.62 - 0.22 * k))
		var half := s * (0.2 + 0.07 * k)
		var base_y := top.y + s * (0.38 + 0.02 * k)
		var tri := PackedVector2Array([top, Vector2(c.x + half, base_y), Vector2(c.x - half, base_y)])
		Ink.poly(ci, tri, Color("#2f4a2a"), w)
		ci.draw_colored_polygon(PackedVector2Array([top, Vector2(c.x, base_y), Vector2(c.x - half + w, base_y - w * 0.5)]), Color("#46693a"))


## Brèche : cratère fissuré d'où montent des fumerolles.
static func _breach(ci: CanvasItem, index: int, c: Vector2, s: float, w: float) -> void:
	for k in 5:
		var d := Vector2.from_angle(TAU * k / 5.0 + Ink.noise(index, k))
		ci.draw_line(c + d * s * 0.3, c + d * s * 0.48, Ink.INK, w)
	Ink.poly(ci, Ink.burst(c, s * 0.38, s * 0.28, 7, index), Color("#2b1f1a"), w)
	ci.draw_circle(c, s * 0.2, Color("#8f2b24"))
	ci.draw_circle(c + Vector2(s * 0.03, s * 0.03), s * 0.12, Color("#1c1310"))
	for k in 3:  # fumée
		ci.draw_circle(c + Vector2((k - 1) * s * 0.16, -s * (0.36 + 0.06 * (k % 2))), s * (0.11 + 0.03 * (k % 2)), Ink.STEAM)


## Rempart : bloc de pierre massif avec porte, plus haut que la case.
static func _wall(ci: CanvasItem, c: Vector2, s: float, w: float) -> void:
	var r := Rect2(c + Vector2(-s * 0.46, -s * 0.62), Vector2(s * 0.92, s * 1.0))
	ci.draw_rect(Rect2(r.position + Vector2(s * 0.08, s * 0.08), r.size), Color(Ink.INK, 0.4))
	ci.draw_rect(r, Ink.STONE)
	ci.draw_rect(Rect2(r.end.x - s * 0.2, r.position.y, s * 0.2, r.size.y), Ink.STONE_DARK)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, s * 0.12)), Ink.STONE.lightened(0.15))
	var joint := Color(Ink.INK, 0.45)
	for k in 3:  # assises de pierre
		var y := r.position.y + s * (0.3 + 0.22 * k)
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), joint, maxf(1.0, w * 0.5))
	var gate := Rect2(c + Vector2(-s * 0.15, s * 0.05), Vector2(s * 0.3, s * 0.33))
	ci.draw_rect(gate, Color("#241a14"))
	ci.draw_circle(Vector2(c.x, gate.position.y), s * 0.15, Color("#241a14"))
	ci.draw_rect(r, Ink.INK, false, w)

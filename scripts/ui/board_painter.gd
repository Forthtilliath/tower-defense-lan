class_name BoardPainter
extends RefCounted
## Formes dessinées du terrain (sans image) : cases, cases spéciales, trajectoire des volants.


static func tile(ci: CanvasItem, map: MapDef, data: GameData, index: int, r: Rect2) -> void:
	var kind := map.cells[index]
	var c := map.cell_coords(index)
	var col: Color = BoardView.TILE_COLORS[kind]
	if kind == MapDef.Cell.BUILD and (c.x + c.y) % 2 == 0:
		col = col.lightened(0.05)
	ci.draw_rect(r, col)
	var center := r.get_center()
	var s := r.size.x
	match kind:
		MapDef.Cell.BUILD:
			ci.draw_rect(r.grow(-1), Color(0, 0, 0, 0.07), false, 1.0)
			var special := map.special_at(index)
			if special >= 0 and data != null:
				_special(ci, data.specials[special], center, s)
		MapDef.Cell.ROCK:
			ci.draw_circle(center + Vector2(s * 0.05, s * 0.08), s * 0.3, Color("#6f747c"))
			ci.draw_circle(center - Vector2(s * 0.08, s * 0.05), s * 0.22, Color("#9aa0a8"))
		MapDef.Cell.TREE:
			ci.draw_rect(Rect2(center + Vector2(-s * 0.05, s * 0.1), Vector2(s * 0.1, s * 0.28)), Color("#6b4a2b"))
			ci.draw_circle(center - Vector2(0, s * 0.05), s * 0.3, Color("#2f6b2c"))
			ci.draw_circle(center - Vector2(s * 0.08, s * 0.12), s * 0.14, Color("#3f8a3a"))
		MapDef.Cell.WATER:
			for k in 2:
				var y := r.position.y + s * (0.35 + 0.3 * k)
				ci.draw_line(Vector2(r.position.x + s * 0.2, y), Vector2(r.end.x - s * 0.2, y), Color(1, 1, 1, 0.25), 2.0)
		MapDef.Cell.START:
			ci.draw_circle(center, s * 0.38, Color("#4b2a78"))
			ci.draw_circle(center, s * 0.26, Color("#8f5ce0"))
			ci.draw_circle(center, s * 0.12, Color("#e5d4ff"))
		MapDef.Cell.END:
			var base := Rect2(center - Vector2(s * 0.32, s * 0.2), Vector2(s * 0.64, s * 0.5))
			ci.draw_rect(base, Color("#a7b0bf"))
			for k in 3:
				ci.draw_rect(Rect2(base.position + Vector2(k * s * 0.24, -s * 0.12), Vector2(s * 0.16, s * 0.14)), Color("#a7b0bf"))
			ci.draw_rect(Rect2(center + Vector2(-s * 0.08, s * 0.08), Vector2(s * 0.16, s * 0.22)), Color("#4a3a2a"))


## Case spéciale : cadre lumineux de sa couleur et symbole selon le bonus.
static func _special(ci: CanvasItem, special: Dictionary, center: Vector2, s: float) -> void:
	var col := Color(special["color"])
	var r := Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)).grow(-s * 0.08)
	ci.draw_rect(r, Color(col, 0.18))
	ci.draw_rect(r, Color(col, 0.85), false, maxf(1.5, s * 0.05))
	var k := s * 0.16
	if special["range"] > 1.0:  # colline : deux sommets
		ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-k * 1.6, k), center + Vector2(-k * 0.3, -k), center + Vector2(k, k)]), Color(col, 0.9))
		ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-k * 0.2, k), center + Vector2(k * 0.8, -k * 0.4), center + Vector2(k * 1.7, k)]), Color(col.darkened(0.2), 0.9))
	elif special["damage"] > 1.0:  # cristal : losange
		ci.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -k * 1.5), center + Vector2(k, 0), center + Vector2(0, k * 1.5), center + Vector2(-k, 0)]), Color(col, 0.95))
	elif special["rate"] > 1.0:  # rune : cercle gravé
		ci.draw_arc(center, k * 1.3, 0.0, TAU, 20, Color(col, 0.95), maxf(1.5, s * 0.05))
		ci.draw_line(center - Vector2(0, k), center + Vector2(0, k), Color(col, 0.95), maxf(1.5, s * 0.05))
	else:  # filon d'or : pépites
		ci.draw_circle(center + Vector2(-k * 0.6, k * 0.3), k * 0.6, Color(col, 0.95))
		ci.draw_circle(center + Vector2(k * 0.7, -k * 0.2), k * 0.45, Color(col, 0.95))


## Trajectoire des volants : pointillés du départ à l'arrivée.
static func flight_paths(ci: CanvasItem, map: MapDef, origin: Vector2, ts: float) -> void:
	for p in map.start_count():
		var pts: PackedVector2Array = map.air_paths[p]
		ci.draw_dashed_line(origin + pts[0] * ts, origin + pts[pts.size() - 1] * ts, Color(1, 1, 1, 0.22), maxf(1.5, ts * 0.04), ts * 0.25)

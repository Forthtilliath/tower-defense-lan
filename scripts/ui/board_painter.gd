class_name BoardPainter
extends RefCounted
## Formes dessinées du plateau (sans image) : cases, tourelles, monstres.


static func tile(ci: CanvasItem, map: MapDef, index: int, r: Rect2) -> void:
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


static func tower(ci: CanvasItem, data: GameData, t: Dictionary, center: Vector2, ts: float, owner_color: Color) -> void:
	var def: Dictionary = data.towers[t["type"]]
	var half := ts * 0.4
	var base := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
	ci.draw_rect(base, owner_color.darkened(0.45))
	ci.draw_rect(base, owner_color, false, maxf(2.0, ts * 0.05))
	var col := Color(def["color"])
	var r := ts * 0.24
	match data.tower_order.find(t["type"]) % 4:
		0:  # arbalète : arc et carreau
			ci.draw_circle(center, r, col)
			ci.draw_arc(center, r * 1.2, PI * 1.15, PI * 1.85, 12, col.lightened(0.4), 3.0)
			ci.draw_line(center, center - Vector2(0, r * 1.5), Color.WHITE, 2.0)
		1:  # canon : fût épais
			ci.draw_circle(center, r * 1.05, col)
			ci.draw_rect(Rect2(center - Vector2(r * 0.35, r * 1.6), Vector2(r * 0.7, r * 1.2)), col.darkened(0.35))
		2:  # givre : cristal
			var pts := PackedVector2Array()
			for k in 6:
				pts.append(center + Vector2.from_angle(TAU * k / 6.0 - PI / 2.0) * r * 1.2)
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(center, r * 0.45, Color.WHITE)
		_:  # baliste : longue arbalète
			ci.draw_circle(center, r * 0.9, col)
			ci.draw_line(center + Vector2(-r * 1.3, -r * 0.2), center + Vector2(r * 1.3, -r * 0.2), col.lightened(0.3), 4.0)
			ci.draw_line(center, center - Vector2(0, r * 1.7), Color.WHITE, 3.0)
	for l in int(t["level"]) + 1:
		ci.draw_circle(base.position + Vector2(ts * 0.13 + l * ts * 0.17, ts * 0.68), maxf(2.0, ts * 0.055), UiTheme.GOLD)


static func monster(ci: CanvasItem, def: Dictionary, m: Dictionary, pos: Vector2, ts: float) -> void:
	var r := ts * float(def["size"]) * 0.5
	var col := Color(def["color"])
	if m["slowed"]:
		col = col.lerp(Color("#9fdcff"), 0.55)
	if m["flying"]:
		ci.draw_circle(pos + Vector2(0, r * 1.1), r * 0.55, Color(0, 0, 0, 0.25))
		var wing := col.darkened(0.25)
		ci.draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(-r * 1.7, -r * 0.6), pos + Vector2(-r * 0.9, r * 0.3)]), wing)
		ci.draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(r * 1.7, -r * 0.6), pos + Vector2(r * 0.9, r * 0.3)]), wing)
	ci.draw_circle(pos, r, col)
	ci.draw_arc(pos, r, 0.0, TAU, 20, col.darkened(0.45), maxf(1.5, ts * 0.03))
	var eye := Vector2(r * 0.35, -r * 0.2)
	ci.draw_circle(pos - Vector2(eye.x, -eye.y), maxf(1.5, r * 0.17), Color.WHITE)
	ci.draw_circle(pos + eye, maxf(1.5, r * 0.17), Color.WHITE)
	var hp: int = m["hp"]
	if hp < 255:
		var w := maxf(ts * 0.6, r * 2.0)
		var bar := Rect2(pos + Vector2(-w / 2.0, -r - ts * 0.16), Vector2(w, maxf(3.0, ts * 0.07)))
		ci.draw_rect(bar, Color(0, 0, 0, 0.6))
		var k := hp / 255.0
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), UiTheme.DANGER.lerp(UiTheme.SUCCESS, k))

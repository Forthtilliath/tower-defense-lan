class_name UnitPainter
extends RefCounted
## Formes dessinées des unités : tourelles (8 silhouettes), monstres et leurs effets.


static func tower(ci: CanvasItem, data: GameData, t: Dictionary, center: Vector2, ts: float, owner_color: Color) -> void:
	var def: Dictionary = data.towers[t["type"]]
	var half := ts * 0.4
	var base := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
	ci.draw_rect(base, owner_color.darkened(0.45))
	ci.draw_rect(base, owner_color, false, maxf(2.0, ts * 0.05))
	_glyph(ci, data.tower_order.find(t["type"]), Color(def["color"]), center, ts * 0.24)
	var levels := int(t["level"]) + 1
	var step := ts * 0.15
	for l in levels:
		ci.draw_circle(base.position + Vector2(ts * 0.1 + l * step, ts * 0.7), maxf(1.8, ts * 0.045), UiTheme.GOLD)


static func _glyph(ci: CanvasItem, index: int, col: Color, c: Vector2, r: float) -> void:
	match index:
		0:  # arbalète : arc et carreau
			ci.draw_circle(c, r, col)
			ci.draw_arc(c, r * 1.2, PI * 1.15, PI * 1.85, 12, col.lightened(0.4), 3.0)
			ci.draw_line(c, c - Vector2(0, r * 1.5), Color.WHITE, 2.0)
		1:  # canon : fût épais
			ci.draw_circle(c, r * 1.05, col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.35, r * 1.6), Vector2(r * 0.7, r * 1.2)), col.darkened(0.35))
		2:  # givre : cristal hexagonal
			ci.draw_colored_polygon(_ngon(c, r * 1.2, 6, -PI / 2.0), col)
			ci.draw_circle(c, r * 0.45, Color.WHITE)
		3:  # baliste : longue arbalète
			ci.draw_circle(c, r * 0.9, col)
			ci.draw_line(c + Vector2(-r * 1.3, -r * 0.2), c + Vector2(r * 1.3, -r * 0.2), col.lightened(0.3), 4.0)
			ci.draw_line(c, c - Vector2(0, r * 1.7), Color.WHITE, 3.0)
		4:  # tesla : bobine et éclair
			ci.draw_circle(c, r, col.darkened(0.3))
			ci.draw_circle(c, r * 0.6, col)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.3, -r * 1.4), c + Vector2(r * 0.2, -r * 0.6), c + Vector2(-r * 0.2, -r * 0.4), c + Vector2(r * 0.3, r * 0.4)]), Color.WHITE, 2.0)
		5:  # venin : goutte
			ci.draw_circle(c + Vector2(0, r * 0.25), r * 0.85, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, 0), c + Vector2(0, -r * 1.3), c + Vector2(r * 0.6, 0)]), col)
			ci.draw_circle(c + Vector2(-r * 0.25, r * 0.1), r * 0.2, Color(1, 1, 1, 0.8))
		6:  # mortier : bouche large inclinée
			ci.draw_circle(c, r * 1.1, col)
			ci.draw_circle(c + Vector2(r * 0.3, -r * 0.4), r * 0.55, col.darkened(0.55))
		_:  # sentinelle : radar
			ci.draw_circle(c, r * 0.75, col.darkened(0.2))
			ci.draw_arc(c, r * 1.3, PI * 1.1, PI * 1.9, 14, col, 3.0)
			ci.draw_line(c, c + Vector2(r * 0.9, -r * 1.1), Color.WHITE, 2.0)


static func monster(ci: CanvasItem, def: Dictionary, m: Dictionary, pos: Vector2, ts: float) -> void:
	var r := ts * float(def["size"]) * 0.5
	var col := Color(def["color"])
	if m["slowed"]:
		col = col.lerp(Color("#9fdcff"), 0.55)
	if m["poisoned"]:
		col = col.lerp(Color("#8be04e"), 0.35)
	if def["heal_radius"] > 0.0:  # aura du soigneur
		ci.draw_circle(pos, def["heal_radius"] * ts, Color(0.85, 0.5, 0.9, 0.08))
		ci.draw_arc(pos, def["heal_radius"] * ts, 0.0, TAU, 32, Color(0.85, 0.5, 0.9, 0.3), 1.5)
	if m["flying"]:
		ci.draw_circle(pos + Vector2(0, r * 1.1), r * 0.55, Color(0, 0, 0, 0.25))
		var wing := col.darkened(0.25)
		ci.draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(-r * 1.7, -r * 0.6), pos + Vector2(-r * 0.9, r * 0.3)]), wing)
		ci.draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(r * 1.7, -r * 0.6), pos + Vector2(r * 0.9, r * 0.3)]), wing)
	ci.draw_circle(pos, r, col)
	var outline := maxf(1.5, ts * 0.03)
	if def["armor"] > 0.0:  # armure : contour épais métallique
		ci.draw_arc(pos, r, 0.0, TAU, 24, Color("#c9ced6"), outline * 2.2)
	else:
		ci.draw_arc(pos, r, 0.0, TAU, 20, col.darkened(0.45), outline)
	var eye := Vector2(r * 0.35, -r * 0.2)
	ci.draw_circle(pos - Vector2(eye.x, -eye.y), maxf(1.5, r * 0.17), Color.WHITE)
	ci.draw_circle(pos + eye, maxf(1.5, r * 0.17), Color.WHITE)
	if def["regen"] > 0.0:  # régénération : petite croix verte
		var k := maxf(2.0, r * 0.3)
		var p := pos + Vector2(r * 0.75, r * 0.6)
		ci.draw_line(p - Vector2(k, 0), p + Vector2(k, 0), UiTheme.SUCCESS, 2.0)
		ci.draw_line(p - Vector2(0, k), p + Vector2(0, k), UiTheme.SUCCESS, 2.0)
	if def["slow_immune"]:  # immunité (boss, golem) : couronne
		ci.draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-r * 0.6, -r * 0.9), pos + Vector2(-r * 0.6, -r * 1.35), pos + Vector2(-r * 0.25, -r * 1.1),
			pos + Vector2(0, -r * 1.45), pos + Vector2(r * 0.25, -r * 1.1), pos + Vector2(r * 0.6, -r * 1.35),
			pos + Vector2(r * 0.6, -r * 0.9)]), UiTheme.GOLD)
	var hp: int = m["hp"]
	if hp < 255:
		var w := maxf(ts * 0.6, r * 2.0)
		var bar := Rect2(pos + Vector2(-w / 2.0, -r - ts * 0.2), Vector2(w, maxf(3.0, ts * 0.07)))
		ci.draw_rect(bar, Color(0, 0, 0, 0.6))
		var k := hp / 255.0
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), UiTheme.DANGER.lerp(UiTheme.SUCCESS, k))


## Effets : onde d'explosion (zone) ou arc électrique (chaîne).
static func fx(ci: CanvasItem, f: Dictionary, origin: Vector2, ts: float) -> void:
	var life: float = f["life"]
	var pos: Vector2 = origin + f["pos"] * ts
	if f["kind"] == SimBoard.Fx.BOLT:
		var to: Vector2 = origin + f["to"] * ts
		var mid := (pos + to) / 2.0 + (to - pos).orthogonal().normalized() * ts * 0.15
		ci.draw_polyline(PackedVector2Array([pos, mid, to]), Color(0.7, 0.85, 1.0, life), maxf(2.0, ts * 0.06))
	else:
		var radius: float = f["radius"] * ts * (1.2 - 0.4 * life)
		ci.draw_arc(pos, radius, 0.0, TAU, 32, Color(1, 0.8, 0.4, life), 3.0)


static func _ngon(c: Vector2, r: float, n: int, start: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		pts.append(c + Vector2.from_angle(start + TAU * k / n) * r)
	return pts

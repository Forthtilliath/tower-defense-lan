class_name UnitPainter
extends RefCounted
## Tourelles, projectiles et effets au style manga : socles octogonaux cernés d'encre, traînées
## de vitesse, éclats d'impact et éclairs en zigzag. Les monstres sont dans MonsterPainter.

const TOWER_CORE := Color("#2e2a24")


static func tower(ci: CanvasItem, data: GameData, t: Dictionary, center: Vector2, ts: float, owner_color: Color) -> void:
	var def: Dictionary = data.towers[t["type"]]
	var w := Ink.width(ts)
	var outer := ts * 0.42 / cos(PI / 8.0)
	var shadow := center + Vector2(ts * 0.06, ts * 0.07)
	ci.draw_colored_polygon(TowerGlyphs.ngon(shadow, outer, 8, PI / 8.0), Color(Ink.INK, 0.45))
	Ink.poly(ci, TowerGlyphs.ngon(center, outer, 8, PI / 8.0), owner_color, w)
	ci.draw_colored_polygon(TowerGlyphs.ngon(center, outer * 0.76, 8, PI / 8.0), TOWER_CORE.lerp(owner_color, 0.18))
	if def["support"]:  # tourelle de soutien : cercle de sa couleur
		ci.draw_arc(center, outer * 0.68, 0.0, TAU, 24, Color(def["color"], 0.85), maxf(1.5, ts * 0.04))
	TowerGlyphs.draw_inked(ci, t["type"], Color(def["color"]), center, ts * 0.24, Vector2.ONE * maxf(1.5, ts * 0.035))
	_rank(ci, int(t["level"]) + 1, center + Vector2(-ts * 0.3, ts * 0.24), ts, w)
	var flags := int(t.get("buffs", 0))
	if flags & 7 != 0:  # renforcée par une aura : chevron en haut à droite
		var p := center + Vector2(ts * 0.3, -ts * 0.28)
		var k := ts * 0.08
		Ink.poly(ci, PackedVector2Array([p + Vector2(-k, k), p + Vector2(0, -k), p + Vector2(k, k)]), UiTheme.SUCCESS, w * 0.6)
	if flags & 8 != 0:  # brouillée : voile sombre et grésillement
		ci.draw_colored_polygon(TowerGlyphs.ngon(center, outer, 8, PI / 8.0), Color(Ink.INK, 0.5))
		var salt := int(Time.get_ticks_msec() / 90.0)
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(center + Vector2(-ts * 0.3 + ts * 0.12 * k, ts * 0.12 * (Ink.noise(salt, k) * 2.0 - 1.0)))
		ci.draw_polyline(pts, MonsterPainter.JAM, maxf(1.5, ts * 0.05))


## Galons de grade (un par niveau) : barrettes dorées inclinées.
static func _rank(ci: CanvasItem, levels: int, at: Vector2, ts: float, w: float) -> void:
	var h := ts * 0.11
	var bw := ts * 0.05
	for l in levels:
		var x := at.x + l * ts * 0.1
		Ink.poly(ci, PackedVector2Array([Vector2(x, at.y + h), Vector2(x + bw, at.y), Vector2(x + bw * 2.0, at.y), Vector2(x + bw, at.y + h)]), UiTheme.GOLD, w * 0.5)


## Projectile : traînée de vitesse de sa position précédente à sa position actuelle.
static func projectile(ci: CanvasItem, from: Vector2, at: Vector2, ts: float) -> void:
	if from.distance_squared_to(at) > 1.0:
		ci.draw_line(from, at, Color(Ink.INK, 0.75), maxf(3.0, ts * 0.09))
		ci.draw_line(from, at, Color(Ink.PAPER, 0.85), maxf(1.5, ts * 0.04))
	ci.draw_circle(at, maxf(2.5, ts * 0.075), Ink.INK)
	ci.draw_circle(at, maxf(1.5, ts * 0.045), Ink.PAPER)


## Effets : éclat d'impact avec lignes de vitesse (zone), éclair en zigzag (chaîne, trait),
## effets élémentaires (FxPainter).
static func fx(ci: CanvasItem, data: GameData, f: Dictionary, origin: Vector2, ts: float) -> void:
	var life: float = f["life"]
	var pos: Vector2 = origin + f["pos"] * ts
	var w := Ink.width(ts)
	if f["kind"] == SimBoard.Fx.BOLT:
		_bolt(ci, pos, origin + f["to"] * ts, life, ts)
		return
	if f["kind"] != SimBoard.Fx.RING:
		FxPainter.fx(ci, data, f, pos, origin + f.get("to", Vector2.ZERO) * ts, ts)
		return
	var radius: float = f["radius"] * ts * (1.2 - 0.4 * life)
	var salt := int(f["pos"].x * 97.0 + f["pos"].y * 31.0)
	var pts := Ink.burst(pos, radius, radius * 0.6, 9, salt)
	ci.draw_colored_polygon(pts, Color(1.0, 0.82, 0.42, life * 0.55))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(Ink.INK, life), w)
	if life > 0.5:
		ci.draw_colored_polygon(Ink.burst(pos, radius * 0.5, radius * 0.25, 7, salt + 1), Color(Ink.PAPER, life))
	Ink.speed_lines(ci, pos, radius * 1.05, radius * 1.45, 10, Color(Ink.INK, life * 0.8), w * 0.7, salt)


static func _bolt(ci: CanvasItem, from: Vector2, to: Vector2, life: float, ts: float) -> void:
	var side := (to - from).orthogonal().normalized() * ts * 0.18
	var salt := int(life * 12.0)
	var pts := PackedVector2Array([from])
	for k in range(1, 5):
		pts.append(from.lerp(to, k / 5.0) + side * (Ink.noise(salt, k) * 2.0 - 1.0))
	pts.append(to)
	ci.draw_polyline(pts, Color(Ink.INK, life * 0.85), maxf(4.0, ts * 0.13))
	ci.draw_polyline(pts, Color(0.62, 0.82, 1.0, life), maxf(2.5, ts * 0.07))
	ci.draw_polyline(pts, Color(1, 1, 1, life), maxf(1.0, ts * 0.025))

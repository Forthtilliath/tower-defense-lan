class_name FxPainter
extends RefCounted
## Effets des tourelles élémentaires au style manga : souffle de flammes en cône, rayon ardent,
## onde autour d'une tourelle, contagion du poison, et nappes au sol (feu, nuage toxique).
## Capacités des monstres : bond (téléportation) et onde de brouillage.

const FLAME := Color(1.0, 0.62, 0.2)
const FLAME_CORE := Color(1.0, 0.9, 0.55)
const TOXIC := Color(0.55, 0.85, 0.3)


## Effet d'une tourelle élémentaire (pos et to déjà en pixels, life de 1 à 0).
static func fx(ci: CanvasItem, data: GameData, f: Dictionary, pos: Vector2, to: Vector2, ts: float) -> void:
	var life: float = f["life"]
	match f["kind"]:
		SimBoard.Fx.CONE:
			_cone(ci, pos, to, life, ts)
		SimBoard.Fx.BEAM:
			_beam(ci, pos, to, life, ts)
		SimBoard.Fx.WAVE:
			var col := Color(data.towers[data.tower_order[f["tint"]]]["color"])
			_wave(ci, pos, f["radius"] * ts, col, life, ts)
		SimBoard.Fx.SPREAD:
			_spread(ci, pos, to, life, ts)
		SimBoard.Fx.BLINK:
			_blink(ci, pos, to, life, ts)
		SimBoard.Fx.JAM:
			_jam(ci, pos, f["radius"] * ts, life, ts)


## Souffle : éventail de langues de feu cerné d'encre, qui s'étire en s'éteignant.
static func _cone(ci: CanvasItem, from: Vector2, to: Vector2, life: float, ts: float) -> void:
	var dir := to - from
	var reach := dir.length() * (1.1 - 0.3 * life)
	var a0 := dir.angle()
	var half := BoardAttacks.CONE_HALF_ANGLE
	var pts := PackedVector2Array([from])
	var salt := int(from.x * 13.0 + from.y * 7.0 + life * 10.0)
	for k in 9:
		var a := a0 - half + 2.0 * half * k / 8.0
		var r := reach * (0.75 + 0.35 * Ink.noise(salt, k))
		pts.append(from + Vector2.from_angle(a) * r)
	ci.draw_colored_polygon(pts, Color(FLAME, life * 0.55))
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color(Ink.INK, life * 0.8), Ink.width(ts) * 0.8)
	var inner := PackedVector2Array([from])
	for k in range(1, pts.size()):
		inner.append(from.lerp(pts[k], 0.5))
	ci.draw_colored_polygon(inner, Color(FLAME_CORE, life * 0.7))


## Rayon ardent : trait épais cerné d'encre, cœur blanc, éclat sur la cible.
static func _beam(ci: CanvasItem, from: Vector2, to: Vector2, life: float, ts: float) -> void:
	ci.draw_line(from, to, Color(Ink.INK, life * 0.8), maxf(5.0, ts * 0.16))
	ci.draw_line(from, to, Color(1.0, 0.55, 0.15, life), maxf(3.0, ts * 0.1))
	ci.draw_line(from, to, Color(1.0, 0.95, 0.75, life), maxf(1.2, ts * 0.035))
	ci.draw_circle(to, ts * 0.14 * (0.6 + 0.4 * life), Color(FLAME_CORE, life))


## Onde : anneau qui s'élargit jusqu'à la portée, à la couleur de la tourelle.
static func _wave(ci: CanvasItem, c: Vector2, radius: float, col: Color, life: float, ts: float) -> void:
	var r := radius * (1.0 - 0.7 * life)
	ci.draw_circle(c, r, Color(col, life * 0.15))
	ci.draw_arc(c, r, 0.0, TAU, 40, Color(Ink.INK, life * 0.8), maxf(3.0, ts * 0.09))
	ci.draw_arc(c, r, 0.0, TAU, 40, Color(col, life), maxf(1.5, ts * 0.05))


## Contagion : filet vert ondulé d'un monstre à l'autre.
static func _spread(ci: CanvasItem, from: Vector2, to: Vector2, life: float, ts: float) -> void:
	var side := (to - from).orthogonal().normalized() * ts * 0.1
	var pts := PackedVector2Array()
	for k in 7:
		pts.append(from.lerp(to, k / 6.0) + side * sin(k * 1.6 + life * 6.0))
	ci.draw_polyline(pts, Color(Ink.INK, life * 0.7), maxf(3.0, ts * 0.08))
	ci.draw_polyline(pts, Color(TOXIC, life), maxf(1.5, ts * 0.04))


## Bond d'un monstre : traits pointillés du départ à l'arrivée, bouffées violettes aux deux bouts.
static func _blink(ci: CanvasItem, from: Vector2, to: Vector2, life: float, ts: float) -> void:
	var col := Color(0.65, 0.45, 1.0, life)
	for k in 5:
		ci.draw_line(from.lerp(to, k / 5.0), from.lerp(to, (k + 0.5) / 5.0), Color(Ink.INK, life * 0.6), maxf(2.0, ts * 0.06))
	for at in [from, to]:
		ci.draw_circle(at, ts * (0.15 + 0.2 * (1.0 - life)), Color(col, life * 0.45))
		ci.draw_arc(at, ts * (0.15 + 0.2 * (1.0 - life)), 0.0, TAU, 16, Color(Ink.INK, life * 0.7), maxf(1.5, ts * 0.04))


## Brouillage : anneau en dents de scie qui s'élargit jusqu'à sa portée.
static func _jam(ci: CanvasItem, c: Vector2, radius: float, life: float, ts: float) -> void:
	var r := radius * (1.0 - 0.6 * life)
	var pts := PackedVector2Array()
	for k in 25:
		pts.append(c + Vector2.from_angle(TAU * k / 24.0) * r * (1.0 if k % 2 == 0 else 0.88))
	ci.draw_polyline(pts, Color(Ink.INK, life * 0.8), maxf(3.0, ts * 0.08))
	ci.draw_polyline(pts, Color(MonsterPainter.JAM, life), maxf(1.5, ts * 0.04))


## Nappe au sol : tache irrégulière à la couleur de la tourelle, qui pâlit en s'éteignant.
static func patch(ci: CanvasItem, data: GameData, z: Dictionary, center: Vector2, ts: float) -> void:
	var life: float = z["life"]
	var col := Color(data.towers[z["type"]]["color"])
	var r: float = z["radius"] * ts
	var salt := int(center.x * 3.0 + center.y * 5.0)
	var pts := PackedVector2Array()
	for k in 14:
		pts.append(center + Vector2.from_angle(TAU * k / 14.0) * r * (0.85 + 0.2 * Ink.noise(salt, k)))
	var alpha := 0.2 + 0.25 * life
	ci.draw_colored_polygon(pts, Color(col, alpha))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(Ink.INK, alpha), Ink.width(ts) * 0.7)
	for k in 4:  # bulles ou flammèches
		var at := center + Vector2.from_angle(TAU * Ink.noise(salt + 3, k)) * r * 0.55 * Ink.noise(salt + 5, k)
		ci.draw_circle(at, ts * 0.06, Color(col.lightened(0.4), alpha + 0.2))

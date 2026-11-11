class_name Ink
extends RefCounted
## Style manga : encre, palette terreuse et petites formes réutilisables (contours, ellipses,
## éclats d'impact). Tout est dessiné en code, sans image ni shader.

const INK := Color("#15120e")
const PAPER := Color("#f4eedf")
const STEAM := Color(0.96, 0.93, 0.88, 0.55)
const STONE := Color("#9b9384")
const STONE_DARK := Color("#6c655a")


## Épaisseur de trait d'encre adaptée à la taille des cases.
static func width(ts: float, k := 0.045) -> float:
	return maxf(1.5, ts * k)


## Disque cerné d'encre, en deux tons (ombre franche en bas à droite).
static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_circle(c, r + w, INK)
	ci.draw_circle(c, r, col.darkened(0.32))
	ci.draw_circle(c - Vector2(r, r) * 0.14, r * 0.84, col)


## Polygone plein cerné d'encre.
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, INK, w, true)


## Ellipse pleine (ombre au sol, reflets) via une transformation temporaire.
static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	ci.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	ci.draw_circle(Vector2.ZERO, rx, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Éclat d'impact façon manga : étoile aux pointes irrégulières (déterministe selon salt).
static func burst(c: Vector2, outer: float, inner: float, points: int, salt: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in points * 2:
		var jitter := 0.75 + 0.5 * noise(salt, k)
		var rad := (outer if k % 2 == 0 else inner) * jitter
		pts.append(c + Vector2.from_angle(PI * k / points) * rad)
	return pts


## Lignes de vitesse rayonnantes entre deux rayons.
static func speed_lines(ci: CanvasItem, c: Vector2, r0: float, r1: float, count: int, col: Color, w: float, salt: int) -> void:
	for k in count:
		var a := TAU * (k + 0.5 * noise(salt, k)) / count
		var d := Vector2.from_angle(a)
		ci.draw_line(c + d * r0, c + d * r1 * (0.8 + 0.3 * noise(salt + 7, k)), col, w)


## Bruit déterministe dans [0, 1[ (variations de décor stables d'une image à l'autre).
static func noise(salt: int, k: int) -> float:
	var h := (salt * 73856093) ^ (k * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h >> 8) & 0xffff) / 65536.0

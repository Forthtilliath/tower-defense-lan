class_name MapCoverage
extends RefCounted
## Valeur d'un emplacement : nombre de cases de route à portée (REACH cases, d'un centre à
## l'autre). Une case spéciale doit être un bon emplacement : dans le meilleur quart (TOP) des
## cases constructibles de sa carte, sinon son bonus ne compense pas sa mauvaise place.

const REACH := 2.5
const TOP := 0.25


static func route_cover(m: MapDef, index: int, reach := REACH) -> int:
	var c := m.cell_coords(index)
	var r := ceili(reach)
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var at := c + Vector2i(dx, dy)
			if not m.in_bounds(at) or Vector2(dx, dy).length() > reach:
				continue
			var kind := m.cell_at(at)
			if kind == MapDef.Cell.ROUTE or kind == MapDef.Cell.START or kind == MapDef.Cell.END:
				n += 1
	return n


## Couverture minimale du meilleur quart des cases constructibles de la carte.
static func threshold(m: MapDef) -> int:
	var values: Array[int] = []
	for i in m.cell_count():
		if m.is_buildable(i):
			values.append(route_cover(m, i))
	if values.is_empty():
		return 0
	values.sort()
	return values[clampi(floori(values.size() * (1.0 - TOP)), 0, values.size() - 1)]


## Cases spéciales mal placées : [[index de case, couverture], ...] sous le seuil de la carte.
static func weak_specials(m: MapDef) -> Array:
	var out := []
	var limit := threshold(m)
	for i in m.cell_count():
		if m.special_at(i) >= 0:
			var cover := route_cover(m, i)
			if cover < limit:
				out.append([i, cover])
	return out

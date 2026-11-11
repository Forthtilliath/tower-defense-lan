class_name MapPaths
extends RefCounted
## Calcul des chemins d'une carte : plus court chemin sur la route de chaque départ vers
## l'arrivée la plus proche (au sol), ligne droite (volants), et longueurs cumulées.


## Remplit ground_paths, air_paths et leurs longueurs cumulées. Renvoie "" ou un message d'erreur.
static func build(m: MapDef) -> String:
	var starts := m.find_cells(MapDef.Cell.START)
	if starts.is_empty():
		return "aucun point de départ (S)"
	if m.find_cells(MapDef.Cell.END).is_empty():
		return "aucune arrivée (E)"
	if starts.size() > 8:
		return "trop de points de départ (8 maximum)"
	for s in starts:
		var tiles := _bfs(m, s)
		if tiles.is_empty():
			return "le départ (%d, %d) n'atteint aucune arrivée" % [s.x, s.y]
		var pts := _simplify(tiles)
		m.ground_paths.append(pts)
		m.path_labels.append(int(m.start_labels.get(s.y * m.width + s.x, 0)))
		m._ground_cum.append(cumulative(pts))
		var air := PackedVector2Array([_center(tiles[0]), _center(tiles[tiles.size() - 1])])
		m.air_paths.append(air)
		m._air_cum.append(cumulative(air))
	return ""


static func cumulative(pts: PackedVector2Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	return cum


## Plus court chemin sur la route, du départ vers l'arrivée la plus proche.
static func _bfs(m: MapDef, start: Vector2i) -> Array[Vector2i]:
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if m.cell_at(cur) == MapDef.Cell.END:
			return _rebuild(prev, cur)
		for d in MapDef.DIRS:
			var nxt: Vector2i = cur + d
			if not m.in_bounds(nxt) or prev.has(nxt):
				continue
			var kind := m.cell_at(nxt)
			if kind == MapDef.Cell.ROUTE or kind == MapDef.Cell.END:
				prev[nxt] = cur
				queue.append(nxt)
	return []


static func _rebuild(prev: Dictionary, end: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [end]
	var cur := end
	while prev[cur] != cur:
		cur = prev[cur]
		out.append(cur)
	out.reverse()
	return out


## Ne garde que le départ, l'arrivée et les virages.
static func _simplify(tiles: Array[Vector2i]) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in tiles.size():
		if i == 0 or i == tiles.size() - 1:
			pts.append(_center(tiles[i]))
			continue
		if tiles[i] - tiles[i - 1] != tiles[i + 1] - tiles[i]:
			pts.append(_center(tiles[i]))
	return pts


static func _center(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)

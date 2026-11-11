class_name BoardPainter
extends RefCounted
## Surcouche du terrain : zones des joueurs (le décor des cases est dans TerrainPainter).


## Teinte d'une zone fermée (couloir sans joueur) : assombrie, on n'y construit pas.
const CLOSED := Color(0.04, 0.04, 0.05)


## Couleur de chaque zone de joueur : celle du (premier) joueur qui la tient, CLOSED si fermée.
## player_colors : couleurs des joueurs dans l'ordre de la partie.
static func zone_colors(map: MapDef, player_colors: Array[Color]) -> Array[Color]:
	var out: Array[Color] = []
	var n := maxi(1, player_colors.size())
	for z in map.zone_count:
		var i := map.zone_color_index(z, n)
		if i < 0:
			out.append(CLOSED)
		else:
			out.append(player_colors[i] if i < player_colors.size() else Color.WHITE)
	return out


## Zones de joueurs : voile de la couleur du propriétaire, et liseré là où une zone touche une
## case constructible d'une autre zone ou commune (pas le long des routes ni du bord).
static func zones(ci: CanvasItem, map: MapDef, colors: Array[Color], origin: Vector2, ts: float) -> void:
	if colors.is_empty():
		return
	var w := maxf(1.5, ts * 0.05)
	for i in map.cell_count():
		var z := map.zone_at(i)
		if z < 0 or z >= colors.size() or not map.is_buildable(i):  # décor : teinté une fois rasé
			continue
		var c := map.cell_coords(i)
		var r := Rect2(origin + Vector2(c) * ts, Vector2(ts, ts))
		if colors[z] == CLOSED:
			ci.draw_rect(r, Color(CLOSED, 0.55))
			continue
		ci.draw_rect(r, Color(colors[z], 0.16))
		var edge := Color(colors[z], 0.8)
		if c.x + 1 < map.width and _other_zone(map, i + 1, z):
			ci.draw_line(Vector2(r.end.x, r.position.y), r.end, edge, w)
		if c.x > 0 and _other_zone(map, i - 1, z):
			ci.draw_line(r.position, Vector2(r.position.x, r.end.y), edge, w)
		if c.y + 1 < map.height and _other_zone(map, i + map.width, z):
			ci.draw_line(Vector2(r.position.x, r.end.y), r.end, edge, w)
		if c.y > 0 and _other_zone(map, i - map.width, z):
			ci.draw_line(r.position, Vector2(r.end.x, r.position.y), edge, w)


static func _other_zone(map: MapDef, index: int, zone: int) -> bool:
	return map.is_buildable(index) and map.zone_at(index) != zone

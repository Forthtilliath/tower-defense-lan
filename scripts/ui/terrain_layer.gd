class_name TerrainLayer
extends Control
## Décor fixe d'un plateau (cases, zones, trajectoires, cadre), dessiné derrière son BoardView.
## Redessiné seulement quand la carte, la taille ou les zones changent : le décor n'est pas
## recalculé à chaque image, ce qui économise le processeur sur téléphone.

var view: BoardView


func _init(p_view: BoardView) -> void:
	view = p_view
	show_behind_parent = true
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)


func _draw() -> void:
	var map := view.map
	if map == null:
		return
	view.update_layout()
	var ts := view.tile_size()
	var origin := view.origin()
	var board := Rect2(origin, Vector2(map.width, map.height) * ts)
	draw_rect(Rect2(board.position + Vector2(ts, ts) * 0.12, board.size), Color(Ink.INK, 0.6))
	var rects: Array[Rect2] = []
	for i in map.cell_count():
		rects.append(Rect2(origin + Vector2(map.cell_coords(i)) * ts, Vector2(ts, ts)))
		TerrainPainter.ground(self, map, i, rects[i])
	for i in map.cell_count():
		TerrainPainter.edges(self, map, i, rects[i])
	BoardPainter.zones(self, map, view.zone_colors, origin, ts)
	for i in map.cell_count():
		TerrainPainter.props(self, map, view.data, i, rects[i])
	draw_rect(board, Ink.INK, false, Ink.width(ts, 0.08))

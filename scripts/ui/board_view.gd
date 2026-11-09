class_name BoardView
extends Control
## Dessine un plateau : cases, tourelles, monstres, projectiles. Émet la case touchée.
## Sans état (state == null), affiche seulement la carte (aperçu du salon).

signal cell_pressed(cell: int)

const TILE_COLORS := {
	MapDef.Cell.BUILD: Color("#5f8f4e"), MapDef.Cell.ROUTE: Color("#c9a66b"),
	MapDef.Cell.START: Color("#c9a66b"), MapDef.Cell.END: Color("#c9a66b"),
	MapDef.Cell.ROCK: Color("#58834a"), MapDef.Cell.WATER: Color("#3d7fb8"),
	MapDef.Cell.TREE: Color("#58834a"),
}

var data: GameData
var map: MapDef
var state: ViewState
var board_index := 0
var selected := -1
var player_colors := {}  # id joueur -> Color
## Couleur de chaque zone de joueur (vide : zones non affichées).
var zone_colors: Array[Color] = []:
	set(value):
		zone_colors = value
		queue_redraw()
## Bâtisseur d'un joueur (id -> index), pour la portée affichée des tourelles.
var builder_of := func(_id: int) -> int: return -1
var _ts := 32.0
var _origin := Vector2.ZERO


func set_map(p_map: MapDef) -> void:
	map = p_map
	queue_redraw()


func _process(_delta: float) -> void:
	if state != null:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		cell_pressed.emit(cell_at(mb.position))
		accept_event()


func cell_at(p: Vector2) -> int:
	if map == null:
		return -1
	var c := ((p - _origin) / _ts).floor()
	if c.x < 0 or c.y < 0 or c.x >= map.width or c.y >= map.height:
		return -1
	return int(c.y) * map.width + int(c.x)


func to_px(p: Vector2) -> Vector2:
	return _origin + p * _ts


func _draw() -> void:
	if map == null:
		return
	_ts = maxf(4.0, floorf(minf(size.x / map.width, size.y / map.height)))
	_origin = ((size - Vector2(map.width, map.height) * _ts) / 2.0).floor()
	for i in map.cell_count():
		BoardPainter.tile(self, map, data, i, Rect2(_origin + Vector2(map.cell_coords(i)) * _ts, Vector2(_ts, _ts)))
	BoardPainter.zones(self, map, zone_colors, _origin, _ts)
	BoardPainter.flight_paths(self, map, _origin, _ts)
	if state == null or not state.received or board_index >= state.boards.size():
		return
	var b: Dictionary = state.boards[board_index]
	_draw_selection(b)
	for cell in b["towers"]:
		var t: Dictionary = b["towers"][cell]
		var col: Color = player_colors.get(t["owner"], Color.WHITE)
		UnitPainter.tower(self, data, t, to_px(map.cell_center(cell)), _ts, col)
	for id in b["monsters"]:
		var m: Dictionary = b["monsters"][id]
		var pos := to_px(map.position_at(m["path"], state.monster_progress(m), m["flying"]))
		UnitPainter.monster(self, data.monsters[m["type"]], m, pos, _ts)
	for id in b["proj"]:
		var p := to_px(state.projectile_pos(b["proj"][id]))
		draw_circle(p, maxf(2.5, _ts * 0.07), Color(0.1, 0.1, 0.1, 0.7))
		draw_circle(p, maxf(1.5, _ts * 0.05), Color.WHITE)
	for f in b["fx"]:
		UnitPainter.fx(self, f, _origin, _ts)
	if not b["alive"]:
		draw_rect(Rect2(_origin, Vector2(map.width, map.height) * _ts), Color(0, 0, 0, 0.55))
		var font := get_theme_default_font()
		var text := "Plateau perdu"
		var fs := int(_ts * 0.8)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, size / 2.0 - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.DANGER)


func _draw_selection(b: Dictionary) -> void:
	if selected < 0 or selected >= map.cell_count():
		return
	var r := Rect2(_origin + Vector2(map.cell_coords(selected)) * _ts, Vector2(_ts, _ts))
	draw_rect(r.grow(-1), UiTheme.ACCENT, false, 3.0)
	if b["towers"].has(selected):
		var t: Dictionary = b["towers"][selected]
		var reach: float = data.tower_stats(t["type"], t["level"], map.special_at(selected), builder_of.call(t["owner"]))["range"]
		var center := to_px(map.cell_center(selected))
		draw_circle(center, reach * _ts, Color(1, 1, 1, 0.08))
		draw_arc(center, reach * _ts, 0.0, TAU, 64, Color(1, 1, 1, 0.5), 2.0)

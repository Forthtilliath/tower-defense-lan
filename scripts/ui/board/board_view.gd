class_name BoardView
extends Control
## Dessine un plateau : cases, tourelles, monstres, projectiles. Émet la case touchée.
## Sans état (state == null), affiche seulement la carte (aperçu du salon).

signal cell_pressed(cell: int)

var data: GameData:
	set(value):
		data = value
		_terrain.queue_redraw()
var map: MapDef
var state: ViewState
var board_index := 0
var selected := -1
var player_colors := {}  # id joueur -> Color
## Couleur de chaque zone de joueur (vide : zones non affichées).
var zone_colors: Array[Color] = []:
	set(value):
		zone_colors = value
		_terrain.queue_redraw()
## Kit d'un joueur (id -> PlayerKit ou null), pour la portée affichée des tourelles.
var kit_of := func(_id: int) -> Variant: return null
## Portée d'une tourelle envisagée sur la case sélectionnée vide (0 : rien à dessiner).
var preview_range := 0.0
## Chemins défendus (couloirs ouverts) ; vide : tous.
var lane_paths: Array[int] = []
## Texte de l'info-bulle d'une entrée (n° de chemin -> texte) ; non valide : pas d'info-bulle.
var entry_info := Callable()
var _ts := 32.0
var _origin := Vector2.ZERO
var _terrain: TerrainLayer
## Bulle du survol : souris immobile HOVER_DELAY s au-dessus d'un monstre ou d'une entrée.
const HOVER_DELAY := 0.3
var _tip: HoverTip
var _mouse := Vector2(-1, -1)  # x < 0 : souris hors du plateau
var _still := 0.0


func _init() -> void:
	_terrain = TerrainLayer.new(self)
	add_child(_terrain)
	_tip = HoverTip.new()
	add_child(_tip)


func set_map(p_map: MapDef) -> void:
	map = p_map
	queue_redraw()
	_terrain.queue_redraw()


## Taille des cases et coin du plateau, centrés dans le contrôle.
func update_layout() -> void:
	if map == null:
		return
	_ts = maxf(4.0, floorf(minf(size.x / map.width, size.y / map.height)))
	_origin = ((size - Vector2(map.width, map.height) * _ts) / 2.0).floor()


func tile_size() -> float:
	return _ts


func origin() -> Vector2:
	return _origin


func _process(delta: float) -> void:
	if state != null:
		queue_redraw()
		_update_tip(delta)


## Bulle recalculée à chaque image tant qu'elle est ouverte (PV qui baissent, monstre qui s'en va).
func _update_tip(delta: float) -> void:
	if _mouse.x < 0.0 or state.ended:
		_tip.visible = false
		return
	_still += delta
	if _tip.visible or _still >= HOVER_DELAY:
		_tip.show_at(_hover_text(_mouse), _mouse, size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-1, -1)
		_tip.visible = false


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm != null:
		_mouse = mm.position
		if not _tip.visible:
			_still = 0.0
		return
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
	update_layout()
	if state == null or not state.received or board_index >= state.boards.size():
		return
	var b: Dictionary = state.boards[board_index]
	for z in b["patches"]:
		FxPainter.patch(self, data, z, to_px(z["pos"]), _ts)
	if state.wave < state.total:
		EntryPainter.draw(self, map, state.wave, _origin, _ts, get_theme_default_font(), lane_paths)
	_draw_selection(b)
	for cell in b["towers"]:
		var t: Dictionary = b["towers"][cell]
		var col: Color = player_colors.get(t["owner"], Color.WHITE)
		UnitPainter.tower(self, data, t, to_px(map.cell_center(cell)), _ts, col)
	for id in b["monsters"]:
		var m: Dictionary = b["monsters"][id]
		var progress := state.monster_progress(m)
		var pos := to_px(map.position_at(m["path"], progress, m["flying"]))
		var ahead := to_px(map.position_at(m["path"], progress + 0.3, m["flying"]))
		var facing := (ahead - pos).normalized() * (-1.0 if m["to"] < m["from"] else 1.0)
		MonsterPainter.draw(self, data.monsters[m["type"]], m, pos, facing, _ts)
	for id in b["proj"]:
		var p: Dictionary = b["proj"][id]
		UnitPainter.projectile(self, data, p["kind"], to_px(p["from"]), to_px(state.projectile_pos(p)), _ts)
	for f in b["fx"]:
		UnitPainter.fx(self, data, f, _origin, _ts)
	if not b["alive"]:
		_draw_banner("Plateau perdu", UiTheme.DANGER, 0.6)
	elif state.paused and not state.ended:
		_draw_banner("Pause", UiTheme.ACCENT, 0.25)


## Voile sombre et titre façon onomatopée cernée d'encre (plateau perdu, pause).
func _draw_banner(text: String, col: Color, veil: float) -> void:
	draw_rect(Rect2(_origin, Vector2(map.width, map.height) * _ts), Color(Ink.INK, veil))
	var font := get_theme_default_font()
	var fs := int(_ts * 0.9)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := size / 2.0 - Vector2(w / 2.0, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, int(_ts * 0.18)), Ink.INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Texte de la bulle au survol : monstre sous le curseur, sinon entrée des monstres ("" : rien).
func _hover_text(at_position: Vector2) -> String:
	if map == null or state == null or not state.received or board_index >= state.boards.size():
		return ""
	var b: Dictionary = state.boards[board_index]
	var best := ""
	var best_d := INF
	for id in b["monsters"]:
		var m: Dictionary = b["monsters"][id]
		var pos := to_px(map.position_at(m["path"], state.monster_progress(m), m["flying"]))
		var d := pos.distance_to(at_position)
		var reach := maxf(_ts * 0.35, _ts * float(data.monsters[m["type"]]["size"]) * 0.6)
		if d <= reach and d < best_d:
			best_d = d
			best = MonsterText.hover_text(data, m)
	if best != "" or not entry_info.is_valid():
		return best
	for p in map.start_count():
		var center := to_px(map.cell_center(MapSpawns.path_start(map, p)))
		if center.distance_to(at_position) <= _ts * 0.7:
			return entry_info.call(p)
	return ""


func _draw_selection(b: Dictionary) -> void:
	if selected < 0 or selected >= map.cell_count():
		return
	var r := Rect2(_origin + Vector2(map.cell_coords(selected)) * _ts, Vector2(_ts, _ts))
	draw_rect(r.grow(-1), UiTheme.ACCENT, false, 3.0)
	var reach := preview_range
	if b["towers"].has(selected):
		var t: Dictionary = b["towers"][selected]
		reach = data.tower_stats(t["type"], t["level"], map.special_at(selected), kit_of.call(t["owner"]))["range"]
	if reach > 0.0:
		var center := to_px(map.cell_center(selected))
		draw_circle(center, reach * _ts, Color(Ink.PAPER, 0.1))
		draw_arc(center, reach * _ts, 0.0, TAU, 64, Color(Ink.INK, 0.55), 4.0)
		draw_arc(center, reach * _ts, 0.0, TAU, 64, Color(Ink.PAPER, 0.8), 2.0)

class_name MapDef
extends RefCounted
## Carte : grille de cases et chemins calculés de chaque départ vers l'arrivée la plus proche.
## Les coordonnées sont en cases : le centre de la case (x, y) vaut (x + 0.5, y + 0.5).

enum Cell { BUILD, ROUTE, START, END, ROCK, WATER, TREE }

const CHARS := {
	".": Cell.BUILD, "=": Cell.ROUTE, "S": Cell.START, "E": Cell.END,
	"#": Cell.ROCK, "~": Cell.WATER, "T": Cell.TREE,
}
const MIN_SIZE := 4
const MAX_SIZE := 32
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var id := ""
var name := ""
var width := 0
var height := 0
var cells := PackedInt32Array()
var waves: Array[String] = []
## Chemins au sol, un par point de départ (points de virage uniquement).
var ground_paths: Array[PackedVector2Array] = []
## Chemins des volants : ligne droite du départ à l'arrivée.
var air_paths: Array[PackedVector2Array] = []
var _ground_cum: Array[PackedFloat32Array] = []
var _air_cum: Array[PackedFloat32Array] = []


## Construit une carte depuis ses lignes de texte.
## Renvoie un MapDef, ou un message d'erreur (String) si la carte est invalide.
static func parse(p_id: String, p_name: String, rows: Array, p_waves: Array[String]) -> Variant:
	if rows.size() < MIN_SIZE or rows.size() > MAX_SIZE:
		return "nombre de lignes hors limites (%d à %d)" % [MIN_SIZE, MAX_SIZE]
	var m := MapDef.new()
	m.id = p_id
	m.name = p_name
	m.waves = p_waves
	m.height = rows.size()
	for y in rows.size():
		if typeof(rows[y]) != TYPE_STRING:
			return "ligne %d : texte attendu" % y
		var line: String = rows[y]
		if y == 0:
			m.width = line.length()
			if m.width < MIN_SIZE or m.width > MAX_SIZE:
				return "largeur hors limites (%d à %d)" % [MIN_SIZE, MAX_SIZE]
		elif line.length() != m.width:
			return "ligne %d : %d caractères au lieu de %d" % [y, line.length(), m.width]
		for x in line.length():
			var ch := line[x]
			if not CHARS.has(ch):
				return "ligne %d : caractère « %s » inconnu" % [y, ch]
			m.cells.append(CHARS[ch])
	var err := m._build_paths()
	if err != "":
		return err
	return m


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func cell_at(c: Vector2i) -> int:
	return cells[c.y * width + c.x]


func cell_coords(index: int) -> Vector2i:
	return Vector2i(index % width, index / width)


func cell_center(index: int) -> Vector2:
	return Vector2(cell_coords(index)) + Vector2(0.5, 0.5)


func cell_count() -> int:
	return cells.size()


func is_buildable(index: int) -> bool:
	return index >= 0 and index < cells.size() and cells[index] == Cell.BUILD


func start_count() -> int:
	return ground_paths.size()


func path_length(path: int, flying: bool) -> float:
	var cum: PackedFloat32Array = _air_cum[path] if flying else _ground_cum[path]
	return cum[cum.size() - 1]


## Position (en cases) après avoir parcouru `progress` cases sur le chemin.
func position_at(path: int, progress: float, flying: bool) -> Vector2:
	var pts: PackedVector2Array = air_paths[path] if flying else ground_paths[path]
	var cum: PackedFloat32Array = _air_cum[path] if flying else _ground_cum[path]
	if progress <= 0.0:
		return pts[0]
	for i in range(1, pts.size()):
		if progress <= cum[i]:
			var seg := cum[i] - cum[i - 1]
			var t := (progress - cum[i - 1]) / seg if seg > 0.0 else 1.0
			return pts[i - 1].lerp(pts[i], t)
	return pts[pts.size() - 1]


func find_cells(kind: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in cells.size():
		if cells[i] == kind:
			out.append(cell_coords(i))
	return out


func _build_paths() -> String:
	var starts := find_cells(Cell.START)
	if starts.is_empty():
		return "aucun point de départ (S)"
	if find_cells(Cell.END).is_empty():
		return "aucune arrivée (E)"
	if starts.size() > 8:
		return "trop de points de départ (8 maximum)"
	for s in starts:
		var tiles := _bfs(s)
		if tiles.is_empty():
			return "le départ (%d, %d) n'atteint aucune arrivée" % [s.x, s.y]
		var pts := _simplify(tiles)
		ground_paths.append(pts)
		_ground_cum.append(_cumulative(pts))
		var air := PackedVector2Array([_center(tiles[0]), _center(tiles[tiles.size() - 1])])
		air_paths.append(air)
		_air_cum.append(_cumulative(air))
	return ""


## Plus court chemin sur la route, du départ vers l'arrivée la plus proche.
func _bfs(start: Vector2i) -> Array[Vector2i]:
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cell_at(cur) == Cell.END:
			return _rebuild(prev, cur)
		for d in DIRS:
			var nxt: Vector2i = cur + d
			if not in_bounds(nxt) or prev.has(nxt):
				continue
			var kind := cell_at(nxt)
			if kind == Cell.ROUTE or kind == Cell.END:
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


static func _cumulative(pts: PackedVector2Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	return cum


static func _center(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)

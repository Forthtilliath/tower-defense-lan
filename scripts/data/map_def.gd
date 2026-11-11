class_name MapDef
extends RefCounted
## Carte : grille de cases et chemins calculés de chaque départ vers l'arrivée la plus proche.
## Les coordonnées sont en cases : le centre de la case (x, y) vaut (x + 0.5, y + 0.5).

enum Cell { BUILD, ROUTE, START, END, ROCK, WATER, TREE }
## Partagée : tout le monde construit partout. Zones : chaque case constructible appartient
## à une zone de joueur. Mixte : des zones de joueur et des cases communes.
enum Layout { SHARED, ZONED, MIXED }

const LAYOUT_NAMES := ["Carte partagée", "Carte en zones", "Carte mixte"]
const MAX_ZONES := 4

const CHARS := {
	".": Cell.BUILD, "=": Cell.ROUTE, "S": Cell.START, "E": Cell.END,
	"#": Cell.ROCK, "~": Cell.WATER, "T": Cell.TREE,
}
## Départs numérotés (entrées par vague) : réservés, comme CHARS, aux cases de base.
const ENTRY_CHARS := "1234"
const MIN_SIZE := 4
const MAX_SIZE := 32
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var id := ""
var name := ""
var width := 0
var height := 0
var cells := PackedInt32Array()
## Case spéciale (index dans GameData.specials) par case, -1 si aucune. Une case spéciale est constructible.
var specials := PackedInt32Array()
## Zone de joueur par case (0 à MAX_ZONES - 1), -1 pour une case commune.
var zones := PackedInt32Array()
var zone_count := 0
var waves: Array[String] = []
## Multiplicateur de vitesse des volants sur cette carte (1 = normal).
var flyer_speed := 1.0
## Nombre de joueurs conseillé (indicatif : affiché dans le salon).
var min_players := 1
var max_players := 4
## Nombre de couloirs séparés (chacun défendu par ses propres tourelles), pour le renforcement coop.
var lanes := 1
## Difficulté de la carte (index dans DataSchema.MAP_TIERS : facile, moyenne, difficile).
var tier := 1
## Multiplicateur des PV des monstres sur cette carte (s'ajoute à la difficulté choisie).
var monster_hp := 1.0
## Thème (DataSchema.THEMES) : couleurs et dessin du décor.
var theme := "prairie"
## Numéro d'entrée de chaque départ numéroté (index de case -> 1 à 4) ; un « S » n'en a pas.
var start_labels := {}
## Entrées ouvertes vague après vague, motif répété (ex. ["1", "2", "12"]) ; vide : tous les
## départs à chaque vague. Voir MapSpawns.
var entries: Array[String] = []
## Chemins au sol, un par point de départ (points de virage uniquement).
var ground_paths: Array[PackedVector2Array] = []
## Numéro d'entrée de chaque chemin (0 : départ « S », toujours ouvert).
var path_labels := PackedInt32Array()
## Chemins des volants : ligne droite du départ à l'arrivée.
var air_paths: Array[PackedVector2Array] = []
var _ground_cum: Array[PackedFloat32Array] = []
var _air_cum: Array[PackedFloat32Array] = []


## Construit une carte depuis ses lignes de texte. `special_tiles` : liste des cases spéciales
## (chacune avec son symbole « char »). Renvoie un MapDef, ou un message d'erreur (String).
static func parse(p_id: String, p_name: String, rows: Array, p_waves: Array[String], special_tiles: Array = []) -> Variant:
	var special_chars := {}
	for i in special_tiles.size():
		special_chars[special_tiles[i]["char"]] = i
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
			if special_chars.has(ch):
				m.cells.append(Cell.BUILD)
				m.specials.append(special_chars[ch])
			elif ch.is_valid_int() and int(ch) >= 1 and int(ch) <= MapSpawns.MAX_ENTRIES:
				m.start_labels[m.cells.size()] = int(ch)  # départ numéroté (entrées par vague)
				m.cells.append(Cell.START)
				m.specials.append(-1)
			elif CHARS.has(ch):
				m.cells.append(CHARS[ch])
				m.specials.append(-1)
			else:
				return "ligne %d : caractère « %s » inconnu" % [y, ch]
	m.zones.resize(m.cells.size())
	m.zones.fill(-1)
	var err := MapPaths.build(m)
	if err != "":
		return err
	return m


## Zones de joueurs : mêmes dimensions que la carte, « 1 » à « 4 » pour une zone, « . » pour
## une case commune. Seules les cases constructibles et le décor (constructible une fois rasé)
## comptent. Renvoie "" ou un message d'erreur.
func set_zones(rows: Array) -> String:
	if rows.size() != height:
		return "zones : %d lignes au lieu de %d" % [rows.size(), height]
	var used := {}
	for y in rows.size():
		if typeof(rows[y]) != TYPE_STRING or String(rows[y]).length() != width:
			return "zones, ligne %d : %d caractères attendus" % [y, width]
		var line: String = rows[y]
		for x in width:
			var ch := line[x]
			var index := y * width + x
			if ch == ".":
				continue
			if not ch.is_valid_int() or int(ch) < 1 or int(ch) > MAX_ZONES:
				return "zones, ligne %d : caractère « %s » inconnu (1 à %d ou .)" % [y, ch, MAX_ZONES]
			if cells[index] == Cell.BUILD:
				zones[index] = int(ch) - 1
				used[int(ch) - 1] = true
			elif is_decor(index):
				zones[index] = int(ch) - 1  # un arbre rasé reste dans sa zone
	zone_count = used.size()
	for z in zone_count:
		if not used.has(z):
			return "zones : numéros à suivre attendus (1 à %d)" % zone_count
	return ""


func zone_at(index: int) -> int:
	return zones[index] if index >= 0 and index < zones.size() else -1


func layout() -> int:
	if zone_count == 0:
		return Layout.SHARED
	for i in cells.size():
		if cells[i] == Cell.BUILD and zones[i] < 0:
			return Layout.MIXED
	return Layout.ZONED


## Zones ouvertes pour player_count joueurs : toutes, sauf sur une carte à plusieurs couloirs, où
## seules les zones des couloirs ouverts (un par joueur, voir open_paths) le sont. Les autres sont
## fermées : sans monstre à défendre, elles ne serviraient qu'à piller leurs bonus (filons…).
func open_zone_count(player_count: int) -> int:
	if lanes <= 1:
		return zone_count
	return mini(zone_count, clampi(player_count, 1, lanes))


func zone_closed(zone: int, player_count: int) -> bool:
	return zone >= open_zone_count(player_count)


## Le joueur n° player_index (0 = premier) sur player_count peut-il construire dans la zone ?
## Avec moins de joueurs que de zones ouvertes, chacun en reçoit plusieurs ; avec plus, ils se les partagent.
func zone_allows(zone: int, player_index: int, player_count: int) -> bool:
	if zone < 0:
		return true
	if zone_closed(zone, player_count):
		return false
	var m := mini(maxi(player_count, 1), open_zone_count(player_count))
	return player_index % m == zone % m


## Index du joueur dont la couleur représente la zone (le premier de ses propriétaires), -1 si fermée.
func zone_color_index(zone: int, player_count: int) -> int:
	if zone_closed(zone, player_count):
		return -1
	return zone % mini(maxi(player_count, 1), open_zone_count(player_count))


## Index des cartes de la plus facile à la plus difficile (ordre des données à difficulté égale).
static func by_tier(maps: Array[MapDef]) -> Array[int]:
	var out: Array[int] = []
	out.assign(range(maps.size()))
	out.sort_custom(func(a: int, b: int) -> bool:
		return maps[a].tier < maps[b].tier or (maps[a].tier == maps[b].tier and a < b))
	return out


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


## Index de la case spéciale (dans GameData.specials), -1 si case normale.
func special_at(index: int) -> int:
	return specials[index] if index >= 0 and index < specials.size() else -1


func is_buildable(index: int) -> bool:
	return index >= 0 and index < cells.size() and cells[index] == Cell.BUILD


## Arbre ou rocher : décor qu'un Terrassier peut raser (jamais la route ni l'eau).
func is_decor(index: int) -> bool:
	return index >= 0 and index < cells.size() and (cells[index] == Cell.TREE or cells[index] == Cell.ROCK)


## Copie modifiable (un plateau peut raser son décor ou poser des cases) ; les chemins, eux,
## ne changent jamais et restent partagés.
func clone() -> MapDef:
	var m := MapDef.new()
	for key in ["id", "name", "width", "height", "cells", "specials", "zones", "zone_count", "waves",
			"flyer_speed", "min_players", "max_players", "lanes", "tier", "monster_hp", "ground_paths", "air_paths", "_ground_cum", "_air_cum",
			"theme", "start_labels", "entries", "path_labels"]:
		m.set(key, get(key))
	m.cells = cells.duplicate()
	m.specials = specials.duplicate()
	return m


## Change une case : décor rasé (devenu constructible) ou case spéciale posée.
func set_cell(index: int, kind: int, special: int) -> void:
	cells[index] = kind
	specials[index] = special


## Couloirs ouverts pour `players` joueurs (voir MapSpawns.open_paths).
func open_paths(players: int) -> Array[int]:
	return MapSpawns.open_paths(self, players)


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

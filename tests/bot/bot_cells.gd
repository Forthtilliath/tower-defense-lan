extends RefCounted
## Placement des tourelles du joueur automatique : longueur de route couverte par une case à la
## portée réelle de la tourelle (au sol ou en l'air, couloir par couloir), cases spéciales qui
## profitent à la tourelle, regroupement de ses tourelles (auras, Harmonie, Bâtisseur), et
## tourelles de soutien posées là où elles touchent le plus de ses tourelles.

const STEP := 0.25
## Cases candidates : les mieux placées (à portée courante) et toutes les cases spéciales libres.
const CANDIDATES := 28
## Voisines (BoardLayout.NEIGHBOUR) : regrouper ses tourelles aide les auras et les talents.
const CLUSTER := 0.04

var _samples := {}  # "chemin/air" -> PackedVector2Array
var _coverage := {}  # "case/portée/chemin/air" -> longueur couverte
var _base := {}  # "paths" -> cases constructibles triées par couverture de base
var _candidates := {}
var _stats := {}
var _map: MapDef


func reset(map: MapDef) -> void:
	_map = map
	_samples.clear()
	_coverage.clear()
	_base.clear()
	_candidates.clear()
	_stats.clear()


## Longueur de route (en cases) à portée `reach` du centre de la case, sur le chemin `path`.
func coverage(cell: int, reach: float, path: int, air: bool) -> float:
	var r := snappedf(reach, 0.1)
	var key := "%d/%.1f/%d/%d" % [cell, r, path, 1 if air else 0]
	if _coverage.has(key):
		return _coverage[key]
	var c := _map.cell_center(cell)
	var r2 := r * r
	var n := 0
	for p in _points(path, air):
		if c.distance_squared_to(p) <= r2:
			n += 1
	_coverage[key] = n * STEP
	return _coverage[key]


## Route restante (en cases) après le dernier point couvert par la case : un effet continu posé
## trop près de la sortie n'a pas le temps d'agir. Longueur entière si rien n'est couvert.
func tail(cell: int, reach: float, path: int, air: bool) -> float:
	var r := snappedf(reach, 0.1)
	var key := "t/%d/%.1f/%d/%d" % [cell, r, path, 1 if air else 0]
	if _coverage.has(key):
		return _coverage[key]
	var c := _map.cell_center(cell)
	var r2 := r * r
	var pts := _points(path, air)
	var last := -1
	for i in pts.size():
		if c.distance_squared_to(pts[i]) <= r2:
			last = i
	_coverage[key] = _map.path_length(path, air) - (last + 1) * STEP if last >= 0 else _map.path_length(path, air)
	return _coverage[key]


func _points(path: int, air: bool) -> PackedVector2Array:
	var key := "%d/%d" % [path, 1 if air else 0]
	if not _samples.has(key):
		var pts := PackedVector2Array()
		var d := 0.0
		var length := _map.path_length(path, air)
		while d < length:
			pts.append(_map.position_at(path, d, air))
			d += STEP
		_samples[key] = pts
	return _samples[key]


## Cases constructibles de la carte (y compris occupées), de la mieux à la moins bien placée
## pour une portée moyenne, sur les chemins `paths`, au sol ou en l'air.
func base_ranking(paths: Array, air: bool) -> Array:
	var key := "%s/%d" % [str(paths), 1 if air else 0]
	if _base.has(key):
		return _base[key]
	var scores := {}
	for cell in _map.cell_count():
		if not _map.is_buildable(cell):
			continue
		var score := 0.0
		for p in paths:
			score += coverage(cell, 2.6, p, air)
		if score > 0.0:
			scores[cell] = score
	var cells := scores.keys()
	cells.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	_base[key] = cells
	return cells


## Cases où le joueur peut construire en ce moment : les CANDIDATES mieux placées au sol, les
## CANDIDATES mieux placées sous les trajets des volants, plus les cases spéciales libres.
func candidates(sim: SimMatch, id: int, paths: Array) -> Array:
	var board := sim.boards[0]
	var key := "%d/%s/%d/%d/%d" % [id, str(paths), board.towers.size(), board.edits.size(), sim.wave_index]
	if _candidates.has(key):
		return _candidates[key]
	var out := []
	for air in [false, true]:
		var n := 0
		for cell in base_ranking(paths, air):
			if n >= CANDIDATES and board.map.special_at(cell) < 0:
				continue
			if not out.has(cell) and MatchActions.can_build_for(sim, id, board, cell):
				out.append(cell)
				n += 1
	_candidates[key] = out
	return out


## Statistiques d'une tourelle au niveau maximum du joueur sur une case (mises en cache).
func _top_stats(data: GameData, type: String, special: int, kit: PlayerKit) -> Dictionary:
	var key := "%d/%s/%d" % [kit.get_instance_id(), type, special]
	if not _stats.has(key):
		_stats[key] = data.tower_stats(type, data.levels_for(type, kit).size() - 1, special, kit)
	return _stats[key]


## Meilleure case pour une tourelle qui tire : route couverte à sa portée au niveau maximum,
## pondérée par ce que chaque couloir recevra (sol et air), bonus de la case spéciale si la
## tourelle en profite, voisinage de ses tourelles. weights : {chemin -> [poids sol, poids air]}.
## Renvoie les `count` meilleures cases : [[case, score], ...] (vide si aucune).
func best_cells(sim: SimMatch, id: int, type: String, weights: Dictionary, mine: Array, jammers := false, count := 3) -> Array:
	var data := sim.data
	var def: Dictionary = data.towers[type]
	var kit: PlayerKit = sim.players[id]["kit"]
	var scored := []
	for cell in candidates(sim, id, weights.keys()):
		var special := sim.boards[0].map.special_at(cell)
		var stats := _top_stats(data, type, special, kit)
		var reach := float(stats["range"])
		var air: bool = def["air"] or int(stats.get("all_targets", 0)) > 0
		var ground: bool = def["ground"] or int(stats.get("all_targets", 0)) > 0
		var score := 0.0
		for p in weights:
			var w: Array = weights[p]
			if ground:
				score += float(w[0]) * coverage(cell, reach, p, false)
			if air:
				score += float(w[1]) * coverage(cell, reach, p, true)
		if score <= 0.0:
			continue
		score *= tile_mult(data, type, special, kit, weights)
		score *= 1.0 + cluster_bonus(sim, cell, mine, type, jammers)
		scored.append([cell, score])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return scored.slice(0, count)


## Multiplicateur d'une case spéciale pour cette tourelle (la portée compte déjà dans la couverture).
## Une case qui ne lui profite pas vaut un peu moins qu'une case normale : elle servira à une autre.
static func tile_mult(data: GameData, type: String, special: int, kit: PlayerKit, weights: Dictionary) -> float:
	if special < 0:
		return 1.0
	var s: Dictionary = data.specials[special]
	if not TileBonus.applies(data, type, s):
		return 0.85
	var boost := 1.0 + (kit.m("fertile") if kit != null else 0.0)
	var m := 1.0 + (float(s["damage"]) - 1.0) * boost
	m *= 1.0 + (float(s["rate"]) - 1.0) * boost
	m *= 1.0 + float(s["crit"]) * boost + 0.25 * float(s["vs_big"]) * boost + 0.1 * int(s["kill_gold"])
	m *= 1.0 + 0.4 * float(s["veteran_cap"]) + 0.15 * (float(s["durations"]) - 1.0) + 0.1 * int(s["chain"])
	var air_total := 0.0
	for p in weights:
		air_total += float(weights[p][1])
	if s["air"] and not data.towers[type]["air"] and air_total > 0.0:
		m *= 1.3
	if float(s["discount"]) > 0.0:
		m *= 1.1
	return m


## Bonus de voisinage : ses tourelles à côté (auras communes, Mur porteur, Pierre angulaire,
## Symétrie, Harmonie), un peu plus pour les talents qui le récompensent. Quand des Saboteurs
## (brouillage) sont à prévoir, un paquet de plus de trois tourelles devient un risque.
static func cluster_bonus(sim: SimMatch, cell: int, mine: Array, type: String, jammers := false) -> float:
	var c := sim.map.cell_center(cell)
	var kit: PlayerKit = null
	var around := 0
	var twin := false
	var elements := {}
	for t in mine:
		if t.center.distance_to(c) <= BoardLayout.NEIGHBOUR:
			around += 1
			kit = t.kit
			twin = twin or t.type == type
			var e: String = sim.data.towers[t.type]["element"]
			if DataSchema.ELEMENTS.has(e) and e != sim.data.towers[type]["element"]:
				elements[e] = true
	if around == 0:
		return 0.0
	if jammers and around >= 3:
		return -0.08 * (around - 2)
	var bonus := CLUSTER * around
	if kit != null:
		var g: Dictionary = kit._grants.get("", {}).duplicate()
		g.merge(kit._grants.get(type, {}))
		bonus += float(g.get("wall", 0.0)) * around + float(g.get("harmony", 0.0)) * elements.size()
		bonus += float(g.get("keystone", 0.0)) if around >= BoardLayout.KEYSTONE else 0.0
		bonus += float(g.get("twin", 0.0)) if twin else 0.0
	return bonus


## Meilleure case pour une tourelle de soutien ou d'imprégnation : celle dont la portée atteint
## le plus de ses tourelles qui tirent (pondérées par l'or investi), parmi celles qui en profitent
## (élément pour la gelure et l'électrifié sans le talent imbue_all). Renvoie [case, valeur couverte].
func best_support_cell(sim: SimMatch, id: int, type: String, mine: Array, paths: Array) -> Array:
	var data := sim.data
	var kit: PlayerKit = sim.players[id]["kit"]
	var def: Dictionary = data.towers[type]
	var reach := float(data.tower_stats(type, 0, -1, kit)["range"])
	var imbue := ""
	for kind in BoardAuras.IMBUE:
		if float(def["levels"][0].get(BoardAuras.KINDS[kind], 0.0)) > 0.0 and not kit.imbue_all:
			imbue = BoardAuras.IMBUE[kind]
	var best := -1
	var best_value := 0.0
	for cell in candidates(sim, id, paths):
		var special := sim.boards[0].map.special_at(cell)
		var r := reach * (float(data.specials[special]["range"]) if special >= 0 and TileBonus.applies(data, type, data.specials[special]) else 1.0)
		var c := sim.map.cell_center(cell)
		var value := 0.0
		for t in mine:
			if t.support or t.center.distance_to(c) > r:
				continue
			if imbue != "" and data.towers[t.type]["element"] != imbue:
				continue
			value += t.invested
		if value > best_value:
			best_value = value
			best = cell
	return [best, best_value]

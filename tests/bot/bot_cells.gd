extends RefCounted
## Placement des tourelles du joueur automatique (balance_bot.gd) : cases classées selon le chemin
## qu'elles couvrent, et choix d'une case dans le couloir le moins défendu.

var _lanes := {}  # cache de lane_key


## Meilleure case libre du couloir ouvert où le bot a le moins de tourelles (-1 si aucune case).
func pick_cell(sim: SimMatch, id: int, mine: Array[SimTower], ranked: Array[int]) -> int:
	var load := {}
	for t in mine:
		var z := lane_key(sim.map, t.cell, sim.open_paths)
		load[z] = int(load.get(z, 0)) + 1
	var best_cell := -1
	var best_key := INF
	var seen := {}
	for cell in ranked:
		var z := lane_key(sim.map, cell, sim.open_paths)
		if seen.has(z) or not MatchActions.can_build_for(sim, id, sim.boards[0], cell):
			continue
		seen[z] = true
		var key := float(load.get(z, 0))
		if key < best_key:
			best_key = key
			best_cell = cell
	return best_cell


## Couloir ouvert (parmi `paths`) qu'une case couvre le plus, sur une carte à plusieurs couloirs
## (-1 : aucun, ou carte à un seul couloir).
func lane_key(m: MapDef, cell: int, paths: Array[int]) -> int:
	if m.lanes <= 1:
		return -1
	var key := "%s/%d/%s" % [m.id, cell, str(paths)]
	if not _lanes.has(key):
		var c := m.cell_center(cell)
		var best := -1
		var best_hits := 0
		for p in paths:
			var hits := 0
			var d := 0.0
			while d < m.path_length(p, false):
				if c.distance_to(m.position_at(p, d, false)) <= 2.5:
					hits += 1
				d += 0.5
			if hits > best_hits:
				best_hits = hits
				best = p
		_lanes[key] = best
	return _lanes[key]


## Cases constructibles triées par longueur de chemin (au sol ou aérien) couverte à 2,5 cases,
## sur les seuls chemins ouverts (`paths`, tous si vide) ; les cases qui n'en couvrent aucun sont écartées.
## Comme un joueur, il vise les cases spéciales (`specials` : GameData.specials) : la Colline
## allonge la portée, le Cristal et la Rune multiplient la puissance, le Tableau de chasse rapporte.
## Une case réservée à une famille de tourelles (« only ») compte comme une case normale : le bot
## ne choisit pas sa tourelle d'après la case.
static func ranked_cells(m: MapDef, air: bool, paths: Array[int] = [], specials: Array = []) -> Array[int]:
	var scores := {}
	for cell in m.cell_count():
		if not m.is_buildable(cell):
			continue
		var c := m.cell_center(cell)
		var tile: Dictionary = specials[m.special_at(cell)] if m.special_at(cell) >= 0 and m.special_at(cell) < specials.size() else {}
		if String(tile.get("only", "")) != "":
			tile = {}
		var reach := 2.5 * float(tile.get("range", 1.0))
		var score := 0.0
		for p in (paths if not paths.is_empty() else range(m.start_count())):
			var d := 0.0
			while d < m.path_length(p, air):
				if c.distance_to(m.position_at(p, d, air)) <= reach:
					score += 1.0
				d += 0.25
		score *= float(tile.get("damage", 1.0)) * float(tile.get("rate", 1.0))
		score *= 1.0 + 0.15 * int(tile.get("kill_gold", 0)) + float(tile.get("crit", 0.0)) + 0.3 * float(tile.get("vs_big", 0.0))
		if score > 0.0:
			scores[cell] = score
	var cells: Array[int] = []
	cells.assign(scores.keys())
	cells.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	return cells

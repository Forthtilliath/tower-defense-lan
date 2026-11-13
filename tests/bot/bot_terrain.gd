extends RefCounted
## Terrassier automatique : rase un arbre ou un rocher quand il est mieux placé que les cases
## libres, pose un Cristal (ou à défaut une Colline, une Rune), une Butte ou un Tableau de chasse
## sous sa tourelle la plus chère sans bonus, et creuse un Fossé contre la route au milieu de ses
## tourelles. Une action par appel.

const Cells := preload("res://tests/bot/bot_cells.gd")

## Un décor se rase s'il couvre au moins cette part de la meilleure case libre.
const RAZE_WORTH := 0.9
## Rayon autour de ses tourelles où il creuse un fossé.
const NEAR := 2.5


## Joue une action de terrain si elle vaut le coup. Renvoie vrai si une commande est passée.
func act(sim: SimMatch, id: int, cells: Cells, mine: Array, paths: Array) -> bool:
	var p: Dictionary = sim.players[id]
	var board := sim.boards[int(p["board"])]
	if MatchActions.charges_left(p, "raze") > 0 and _raze(sim, id, cells, board, paths):
		return true
	for kind in ["tile", "mound", "vein"]:
		if MatchActions.charges_left(p, kind) > 0 and _place_under_tower(sim, id, board, mine, kind):
			return true
	if MatchActions.charges_left(p, "ditch") > 0 and _ditch(sim, id, cells, board, mine, paths):
		return true
	return false


## Rase le décor le mieux placé s'il vaut mieux que la meilleure case libre.
func _raze(sim: SimMatch, id: int, cells: Cells, board: SimBoard, paths: Array) -> bool:
	var best_free := 0.0
	for cell in cells.candidates(sim, id, paths):
		best_free = maxf(best_free, _ground(cells, cell, paths))
		break  # la première candidate est la mieux placée
	var best := -1
	var best_score := best_free * RAZE_WORTH
	for cell in board.map.cell_count():
		if not board.map.is_decor(cell):
			continue
		var score := _ground(cells, cell, paths)
		if score > best_score:
			best_score = score
			best = cell
	return best >= 0 and sim.apply_command(id, {"a": "raze", "cell": best}) == ""


static func _ground(cells: Cells, cell: int, paths: Array) -> float:
	var total := 0.0
	for p in paths:
		total += cells.coverage(cell, 2.6, p, false)
	return total


## Pose la case du type `kind` sous sa tourelle la plus chère qui tire et n'a pas de bonus.
func _place_under_tower(sim: SimMatch, id: int, board: SimBoard, mine: Array, kind: String) -> bool:
	var special := _special_for(sim.data, kind)
	if special < 0:
		return false
	var best: SimTower = null
	for t in mine:
		if t.support or t.special >= 0:
			continue
		if best == null or t.invested > best.invested:
			best = t
	if best == null:
		return false
	return sim.apply_command(id, {"a": "tile", "cell": best.cell, "special": special}) == ""


## Case spéciale à poser avec ce type de charge : Cristal (sinon Colline, Rune) pour la
## Géomancie, Butte, Tableau de chasse. -1 si aucune.
static func _special_for(data: GameData, kind: String) -> int:
	var wanted: Array = {"tile": ["crystal", "hill", "rune"], "mound": ["mound"], "vein": ["hunt"]}[kind]
	for want in wanted:
		for i in data.specials.size():
			if data.specials[i]["id"] == want:
				return i
	return -1


## Creuse un fossé sur la case constructible la plus collée à la route près de ses tourelles.
func _ditch(sim: SimMatch, id: int, cells: Cells, board: SimBoard, mine: Array, paths: Array) -> bool:
	var special := -1
	for i in sim.data.specials.size():
		if sim.data.specials[i]["id"] == "ditch":
			special = i
	if special < 0 or mine.is_empty():
		return false
	var best := -1
	var best_score := 0.0
	for cell in board.map.cell_count():
		if not board.map.is_buildable(cell) or board.map.special_at(cell) >= 0:
			continue
		var c := board.map.cell_center(cell)
		var near := false
		for t in mine:
			near = near or t.center.distance_to(c) <= NEAR
		if not near:
			continue
		var score := 0.0
		for p in paths:
			score += cells.coverage(cell, BoardTerrain.DITCH_REACH, p, false)
		if score > best_score:
			best_score = score
			best = cell
	return best >= 0 and sim.apply_command(id, {"a": "tile", "cell": best, "special": special}) == ""

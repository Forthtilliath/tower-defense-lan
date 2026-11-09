extends "res://tests/test_base.gd"
## Équilibrage : un joueur automatique simple doit gagner chaque carte en Normal,
## une partie sans tourelle doit être perdue, et Cauchemar doit être plus dur que Facile.

const DT := 0.05
const PLAN := [
	"crossbow", "crossbow", "cannon", "frost", "sentinel", "venom", "tesla", "ballista",
	"mortar", "crossbow", "venom", "sentinel", "cannon", "tesla", "mortar", "ballista",
]
const MAX_TOWERS := 16
const NORMAL := 1


func test_bot_wins_every_map_solo() -> void:
	var gd := load_data()
	for i in gd.maps.size():
		var sim := play(gd, i, 1, NORMAL)
		check(sim.result == "victory", "%s : %s à la vague %d, vies %d" % [gd.maps[i].id, sim.result, sim.wave_index + 1, sim.boards[0].lives])


func test_bot_wins_duo_coop() -> void:
	var gd := load_data()
	var sim := play(gd, 1, 2, NORMAL)
	check(sim.result == "victory", "duo : %s à la vague %d" % [sim.result, sim.wave_index + 1])


func test_difficulty_ordering() -> void:
	var gd := load_data()
	var easy := play(gd, 0, 1, 0)
	var nightmare := play(gd, 0, 1, 3)
	check(easy.result == "victory", "Facile gagné")
	var easy_score := _score(easy)
	var nightmare_score := _score(nightmare)
	check(nightmare_score < easy_score, "Cauchemar plus dur que Facile : %f / %f" % [nightmare_score, easy_score])


func test_no_tower_loses() -> void:
	var gd := load_data()
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "Passif", 0]])
	for i in int(900.0 / DT):
		sim.step(DT)
		if sim.ended:
			break
	check(sim.result == "defeat", "défaite attendue sans tourelle : %s" % sim.result)


## Progression : vagues franchies + part des vies restantes.
func _score(sim: SimMatch) -> float:
	return sim.wave_index + float(sim.boards[0].lives) / float(sim.difficulty["lives"])


func play(gd: GameData, map_index: int, count: int, difficulty: int) -> SimMatch:
	var roster := []
	for i in count:
		roster.append([i + 1, "Bot%d" % i, i])
	var sim := SimMatch.new(gd, map_index, SimMatch.Mode.COOP, roster, difficulty)
	var cells := ranked_cells(sim.map, false)
	var air_cells := ranked_cells(sim.map, true)
	var timer := 0.0
	for i in int(2400.0 / DT):
		timer -= DT
		if timer <= 0.0:
			timer = 0.5
			for id in sim.order:
				act(sim, id, cells, air_cells)
		sim.step(DT)
		if sim.ended:
			break
	return sim


## Le bot construit selon PLAN sur les meilleures cases (le long de la trajectoire des volants
## pour l'anti-aérien), et améliore dès que ses tourelles ont rattrapé les plus récentes.
func act(sim: SimMatch, id: int, cells: Array[int], air_cells: Array[int]) -> void:
	var board := sim.boards[0]
	var mine: Array[SimTower] = []
	for cell in board.towers:
		if board.towers[cell].owner == id:
			mine.append(board.towers[cell])
	mine.sort_custom(func(a: SimTower, b: SimTower) -> bool: return a.level < b.level)
	var lowest := mine[0].level if not mine.is_empty() else 0
	var want_build := mine.size() < 5 or (mine.size() < MAX_TOWERS and lowest >= mini(4, mine.size() / 4))
	if want_build:
		var type: String = PLAN[mine.size() % PLAN.size()]
		for cell in (air_cells if type == "sentinel" else cells):
			if board.can_build(cell):
				sim.apply_command(id, {"a": "build", "cell": cell, "tower": type})
				return
	for t in mine:
		if sim.apply_command(id, {"a": "upgrade", "cell": t.cell}) == "":
			return


## Cases constructibles triées par longueur de chemin (au sol ou aérien) couverte à 2,5 cases.
func ranked_cells(m: MapDef, air: bool) -> Array[int]:
	var scores := {}
	for cell in m.cell_count():
		if not m.is_buildable(cell):
			continue
		var c := m.cell_center(cell)
		var score := 0
		for p in m.start_count():
			var d := 0.0
			while d < m.path_length(p, air):
				if c.distance_to(m.position_at(p, d, air)) <= 2.5:
					score += 1
				d += 0.25
		scores[cell] = score
	var cells: Array[int] = []
	cells.assign(scores.keys())
	cells.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	return cells

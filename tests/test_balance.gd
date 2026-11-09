extends "res://tests/test_base.gd"
## Équilibrage : un joueur automatique simple doit pouvoir gagner chaque carte en coopération,
## et une partie sans tourelle doit être perdue.

const DT := 0.05
const PLAN := ["crossbow", "crossbow", "cannon", "frost", "ballista", "crossbow", "cannon", "ballista"]
const MAX_TOWERS := 12


func test_bot_wins_every_map_solo() -> void:
	var gd := load_data()
	for i in gd.maps.size():
		var sim := _play(gd, i, 1)
		check(sim.result == "victory", "%s : %s à la vague %d, vies %d" % [gd.maps[i].id, sim.result, sim.wave_index + 1, sim.boards[0].lives])


func test_bot_wins_duo_coop() -> void:
	var gd := load_data()
	var sim := _play(gd, 1, 2)
	check(sim.result == "victory", "duo : %s à la vague %d" % [sim.result, sim.wave_index + 1])


func test_no_tower_loses() -> void:
	var gd := load_data()
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "Passif", 0]])
	for i in int(900.0 / DT):
		sim.step(DT)
		if sim.ended:
			break
	check(sim.result == "defeat", "défaite attendue sans tourelle : %s" % sim.result)


func _play(gd: GameData, map_index: int, count: int) -> SimMatch:
	var roster := []
	for i in count:
		roster.append([i + 1, "Bot%d" % i, i])
	var sim := SimMatch.new(gd, map_index, SimMatch.Mode.COOP, roster)
	var cells := _ranked_cells(sim.map)
	var timer := 0.0
	for i in int(1800.0 / DT):
		timer -= DT
		if timer <= 0.0:
			timer = 0.5
			for id in sim.order:
				_act(sim, id, cells)
		sim.step(DT)
		if sim.ended:
			break
	return sim


## Le bot construit selon PLAN sur les meilleures cases, puis améliore ses tourelles.
func _act(sim: SimMatch, id: int, cells: Array[int]) -> void:
	var board := sim.boards[0]
	var mine: Array[SimTower] = []
	for cell in board.towers:
		if board.towers[cell].owner == id:
			mine.append(board.towers[cell])
	if mine.size() < MAX_TOWERS:
		var type: String = PLAN[mine.size() % PLAN.size()]
		for cell in cells:
			if board.can_build(cell):
				var cmd = Commands.sanitize({"a": "build", "cell": cell, "tower": sim.data.tower_order.find(type)}, sim.data, sim.map)
				sim.apply_command(id, cmd)
				return
	mine.sort_custom(func(a: SimTower, b: SimTower) -> bool: return a.level < b.level)
	for t in mine:
		if sim.apply_command(id, {"a": "upgrade", "cell": t.cell}) == "":
			return


## Cases constructibles triées par longueur de chemin couverte à 2,5 cases.
func _ranked_cells(m: MapDef) -> Array[int]:
	var scores := {}
	for cell in m.cell_count():
		if not m.is_buildable(cell):
			continue
		var c := m.cell_center(cell)
		var score := 0
		for p in m.start_count():
			var d := 0.0
			while d < m.path_length(p, false):
				if c.distance_to(m.position_at(p, d, false)) <= 2.5:
					score += 1
				d += 0.25
		scores[cell] = score
	var cells: Array[int] = []
	cells.assign(scores.keys())
	cells.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	return cells

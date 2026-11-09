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
const FIRST_WAVE_AFTER := 20.0

var _lanes := {}  # cache de lane_key


func test_bot_wins_every_map_solo() -> void:
	var gd := load_data()
	for i in gd.maps.size():
		var sim := play(gd, i, 1, NORMAL)
		check(sim.result == "victory", "%s : %s à la vague %d, vies %d" % [gd.maps[i].id, sim.result, sim.wave_index + 1, sim.boards[0].lives])


func test_bot_wins_duo_coop() -> void:
	var gd := load_data()
	var sim := play(gd, 1, 2, NORMAL)
	check(sim.result == "victory", "duo : %s à la vague %d" % [sim.result, sim.wave_index + 1])


## Grandes cartes : gagnées à 2 et à 4 ; une petite carte à 4 aussi (renforcement coop).
func test_bot_teams_win_big_maps() -> void:
	var gd := load_data()
	for entry in [[7, 2], [7, 4], [8, 2], [8, 4], [9, 2], [9, 4], [1, 4]]:
		var sim := play(gd, entry[0], entry[1], NORMAL)
		check(sim.result == "victory", "%s à %d : %s à la vague %d" % [gd.maps[entry[0]].id, entry[1], sim.result, sim.wave_index + 1])


## Chaque classe gagne aux côtés d'un Touche-à-tout, et gagne sa part d'or : même l'Enchanteur,
## qui fait peu de dégâts, est payé pour ses contrôles (prime partagée selon la contribution).
func test_every_builder_wins_in_a_duo() -> void:
	var gd := load_data()
	for b in gd.builders.size():
		var sim := play(gd, 0, 2, NORMAL, {}, [0, b])
		check(sim.result == "victory", "%s : %s à la vague %d" % [gd.builders[b]["id"], sim.result, sim.wave_index + 1])


func test_damage_builders_win_solo() -> void:
	var gd := load_data()
	for b in gd.builders.size():
		if gd.builders[b]["id"] == "enchanter":
			continue  # classe de soutien : faite pour jouer en équipe
		var sim := play(gd, 0, 1, NORMAL, {}, [b])
		check(sim.result == "victory", "%s : %s à la vague %d" % [gd.builders[b]["id"], sim.result, sim.wave_index + 1])


func test_bot_wins_between_waves_rhythm() -> void:
	var gd := load_data()
	var sim := play(gd, 0, 2, NORMAL, {"rhythm": SimMatch.Rhythm.BETWEEN})
	check(sim.result == "victory", "entre les vagues : %s à la vague %d" % [sim.result, sim.wave_index + 1])


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
	sim.apply_command(1, {"a": "ready"})
	for i in int(900.0 / DT):
		sim.step(DT)
		if sim.ended:
			break
	check(sim.result == "defeat", "défaite attendue sans tourelle : %s" % sim.result)


## Progression : vagues franchies + part des vies restantes.
func _score(sim: SimMatch) -> float:
	return sim.wave_index + float(sim.boards[0].lives) / float(sim.difficulty["lives"])


func play(gd: GameData, map_index: int, count: int, difficulty: int, options := {}, builders := []) -> SimMatch:
	var roster := []
	for i in count:
		roster.append([i + 1, "Bot%d" % i, i, builders[i] if i < builders.size() else 0])
	var sim := SimMatch.new(gd, map_index, SimMatch.Mode.COOP, roster, difficulty, options)
	var cells := ranked_cells(sim.map, false)
	var air_cells := ranked_cells(sim.map, true)
	var timer := 0.0
	for i in int(2400.0 / DT):
		timer -= DT
		if timer <= 0.0:
			timer = 0.5
			for id in sim.order:
				act(sim, id, cells, air_cells)
		# Les bots se préparent 20 s, puis lancent la première vague (elle ne part jamais seule)
		if not sim.started() and i * DT >= FIRST_WAVE_AFTER:
			for id in sim.order:
				sim.apply_command(id, {"a": "ready"})
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
		var plan := builder_plan(sim, id)
		var type: String = plan[mine.size() % plan.size()]
		var cell := pick_cell(sim, id, mine, air_cells if type == "sentinel" else cells)
		if cell >= 0 and sim.apply_command(id, {"a": "build", "cell": cell, "tower": type}) == "":
			return
		# Pas assez d'or pour la tourelle prévue : il améliore plutôt que d'attendre
	for t in mine:
		if sim.apply_command(id, {"a": "upgrade", "cell": t.cell}) == "":
			return


## Meilleure case libre de la zone où le bot a le moins de tourelles : ses propres zones
## d'abord (chacune défend un couloir), les cases communes ensuite. -1 si aucune case.
func pick_cell(sim: SimMatch, id: int, mine: Array[SimTower], ranked: Array[int]) -> int:
	var load := {}
	for t in mine:
		var z := lane_key(sim.map, t.cell)
		load[z] = int(load.get(z, 0)) + 1
	var best_cell := -1
	var best_key := INF
	var seen := {}
	for cell in ranked:
		var z := lane_key(sim.map, cell)
		if seen.has(z) or not MatchActions.can_build_for(sim, id, sim.boards[0], cell):
			continue
		seen[z] = true
		var key := float(load.get(z, 0)) + (0.5 if z < 0 and sim.map.zone_count > 0 else 0.0)
		if key < best_key:
			best_key = key
			best_cell = cell
	return best_cell


## Secteur d'une case pour répartir les tourelles : sa zone sur une carte en zones, sinon le
## couloir qu'elle couvre le plus sur une carte à plusieurs couloirs (-1 : aucun).
func lane_key(m: MapDef, cell: int) -> int:
	if m.zone_count > 0:
		return m.zone_at(cell)
	if m.lanes <= 1:
		return -1
	var key := "%s/%d" % [m.id, cell]
	if not _lanes.has(key):
		var c := m.cell_center(cell)
		var best := -1
		var best_hits := 0
		for p in m.start_count():
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


## PLAN réduit aux tourelles que le bâtisseur du joueur sait construire, suivi de ses autres
## tourelles (contrôles, soutien…) dans l'ordre de sa liste.
func builder_plan(sim: SimMatch, id: int) -> Array:
	var builder: int = sim.players[id]["builder"]
	var plan := PLAN.filter(func(type: String) -> bool: return sim.data.builder_allows(builder, type))
	for type in sim.data.builders[builder]["towers"]:
		if not PLAN.has(type):
			plan.append(type)
	return plan


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

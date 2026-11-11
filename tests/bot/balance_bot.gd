extends RefCounted
## Joueur automatique des tests d'équilibrage. Il joue comme un joueur raisonnable : il privilégie
## les tourelles que sa classe et ses talents renforcent, mais regarde la vague suivante et, si la
## plupart de ses tirs ne la toucheraient pas (fantômes, squelettes, résistance à son élément,
## volants, grosse armure), il construit la tourelle la plus efficace contre elle.
## Placement des tourelles : bot_cells.gd ; lecture de la vague suivante : bot_counters.gd.

const Cells := preload("res://tests/bot/bot_cells.gd")
const Counters := preload("res://tests/bot/bot_counters.gd")

const DT := 0.05
const PLAN := [
	"crossbow", "crossbow", "cannon", "frost", "sentinel", "venom", "tesla", "ballista",
	"mortar", "crossbow", "venom", "sentinel", "cannon", "tesla", "mortar", "ballista",
]
## Plan concentré, joué par l'utilisateur : une Arbalète (sur la meilleure case), puis Tesla, Givre,
## Venin, Brasier, chacune montée au maximum avant la suivante (le Givre ralentit, les autres en profitent).
const FOCUS_PLAN := ["crossbow", "tesla", "frost", "venom", "brazier", "tesla", "frost", "venom", "brazier"]
const MAX_TOWERS := 16
## Monstres présents à partir desquels il lance son pouvoir.
const POWER_CROWD := 5
const FIRST_WAVE_AFTER := 20.0
## Niveau des bots : un joueur qui a déjà quelques parties.
const BOT_LEVEL := 10
## Classe sans spécialisation précisée : l'Artilleur Tireur d'élite, le plus polyvalent.
const DEFAULT_SPEC := 1
## Ses tourelles renforcées tapent peu (moins que cette part d'une Arbalète, pour l'or) : il alterne
## avec des tourelles de dégâts.
const WEAK_RATIO := 0.6

## Appelle la vague suivante en avance tant qu'il ne perd pas de vie (désactivable pour comparer).
var calls_early := true
## Stratégie concentrée (> 0) : au plus `focus` tourelles, chacune montée au maximum avant la suivante.
var focus := 0
var _cells := Cells.new()
var _counters := Counters.new()


## Branches de spécialisation d'une classe (hors tronc), dans l'ordre des données.
func spec_branches(gd: GameData, builder: int) -> Array:
	return gd.builders[builder]["branches"].filter(func(br: Dictionary) -> bool: return not br["trunk"])


func spec_count(gd: GameData, builder: int) -> int:
	return spec_branches(gd, builder).size()


func spec_id(gd: GameData, builder: int, spec: int) -> String:
	return spec_branches(gd, builder)[spec]["id"]


## Talents d'un bot : le tronc d'abord, puis sa spécialisation (la `spec`-ième), palier par palier.
func auto_talents(gd: GameData, builder: int, level: int, spec := 0) -> Dictionary:
	var talents := {}
	var points := TalentRules.points(level)
	var chosen: Dictionary = spec_branches(gd, builder)[spec]
	for branch in gd.builders[builder]["branches"]:
		if not branch["trunk"] and branch != chosen:
			continue
		var sorted: Array = branch["talents"].duplicate()
		sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["tier"] < b["tier"])
		for t in sorted:
			while TalentRules.add_refusal(gd, builder, talents, t["id"], points) == "":
				talents[t["id"]] = int(talents.get(t["id"], 0)) + 1
	_take_ultimate(gd, builder, talents, chosen, points)
	return talents


## Au niveau maximum, comme un joueur, il sacrifie un rang du tronc pour prendre l'ultime (son pouvoir)
## si ses points ne suffisent pas à tout remplir.
func _take_ultimate(gd: GameData, builder: int, talents: Dictionary, spec: Dictionary, points: int) -> void:
	var ultimate := ""
	for t in spec["talents"]:
		if t["ultimate"]:
			ultimate = t["id"]
	if ultimate == "" or talents.has(ultimate) or points < TalentRules.max_points(gd):
		return
	for branch in gd.builders[builder]["branches"]:
		if not branch["trunk"]:
			continue
		var trunk: Array = branch["talents"].duplicate()
		trunk.reverse()
		for t in trunk:
			if int(talents.get(t["id"], 0)) > 0 and TalentRules.remove_refusal(gd, builder, talents, t["id"]) == "":
				talents[t["id"]] -= 1
				if talents[t["id"]] == 0:
					talents.erase(t["id"])
				if TalentRules.add_refusal(gd, builder, talents, ultimate, points) == "":
					talents[ultimate] = 1
				return


## builders : une classe par bot (index, ou [index, spécialisation]) ; Artilleur par défaut.
## heritage : classes déjà montées au niveau maximum (les mêmes pour tous les bots).
func play(gd: GameData, map_index: int, count: int, difficulty: int, options := {}, builders := [], level := BOT_LEVEL, heritage := []) -> SimMatch:
	var roster := []
	for i in count:
		var entry: Variant = builders[i] if i < builders.size() else 0
		var b: int = entry[0] if entry is Array else entry
		var s: int = entry[1] if entry is Array else DEFAULT_SPEC
		roster.append([i + 1, "Bot%d" % i, i, b, auto_talents(gd, b, level, s), heritage])
	var sim := SimMatch.new(gd, map_index, SimMatch.Mode.COOP, roster, difficulty, options)
	var cells := Cells.ranked_cells(sim.map, false, sim.open_paths, gd.specials)
	var air_cells := Cells.ranked_cells(sim.map, true, sim.open_paths, gd.specials)
	var timer := 0.0
	var wave := -1
	var lives := 0
	for i in int(2400.0 / DT):
		timer -= DT
		if timer <= 0.0:
			timer = 0.5
			for id in sim.order:
				act(sim, id, cells, air_cells)
				use_power(sim, id)
			# Comme un joueur à l'aise, il appelle la vague suivante (or d'avance) tant qu'il ne perd pas de vie
			if wave != sim.wave_index:
				wave = sim.wave_index
				lives = sim.boards[0].lives
			if calls_early and sim.started() and sim.boards[0].lives == lives and MatchFlow.can_call(sim):
				for id in sim.order:
					sim.apply_command(id, {"a": "ready"})
		# Les bots se préparent 20 s, puis lancent la première vague (elle ne part jamais seule)
		if not sim.started() and i * DT >= FIRST_WAVE_AFTER:
			for id in sim.order:
				sim.apply_command(id, {"a": "ready"})
		sim.step(DT)
		if sim.ended:
			break
	return sim


## Construit selon son plan (ou une tourelle adaptée à la vague suivante) sur les meilleures
## cases, et améliore dès que ses tourelles ont rattrapé les plus récentes.
func act(sim: SimMatch, id: int, cells: Array[int], air_cells: Array[int]) -> void:
	var board := sim.boards[0]
	var mine: Array[SimTower] = []
	for cell in board.towers:
		if board.towers[cell].owner == id:
			mine.append(board.towers[cell])
	mine.sort_custom(func(a: SimTower, b: SimTower) -> bool: return a.level < b.level)
	var lowest := mine[0].level if not mine.is_empty() else 0
	var want_build := mine.size() < 5 or (mine.size() < MAX_TOWERS and lowest >= mini(4, mine.size() / 4))
	if focus > 0:
		var top := sim.data.tower_levels(mine[0].type).size() - 1 if not mine.is_empty() else 0
		want_build = mine.size() < 3 or (mine.size() < focus and lowest >= top)
	var counter := _counters.counter_pick(sim, id, mine) if mine.size() >= 3 and focus == 0 else ""
	if want_build or counter != "":
		var type := counter
		if type == "":
			var plan := builder_plan(sim, id)
			type = plan[mine.size() % plan.size()]
		var air_only: bool = not sim.data.towers[type]["ground"]
		var cell := _cells.pick_cell(sim, id, mine, air_cells if air_only else cells)
		if cell >= 0 and sim.apply_command(id, {"a": "build", "cell": cell, "tower": type}) == "":
			return
		if cell >= 0 and (mine.size() < 5 or counter != ""):
			return  # il économise pour ses premières tourelles, ou pour la tourelle adaptée
	for t in mine:
		if sim.apply_command(id, {"a": "upgrade", "cell": t.cell}) == "":
			return


## Pouvoir de son talent ultime, lancé dès qu'il est prêt et que la vague est là (au moins
## POWER_CROWD monstres) : visé sur le monstre le plus avancé, ou sur sa meilleure tourelle (Coup de génie).
func use_power(sim: SimMatch, id: int) -> void:
	var p: Dictionary = sim.players[id]
	var board := sim.boards[int(p["board"])]
	if MatchPowers.waves_left(sim, p) != 0 or board.monsters.size() < POWER_CROWD:
		return
	var cell := 0
	if p["kit"].power == "genius":
		var best: SimTower = null
		for c in board.towers:
			var t: SimTower = board.towers[c]
			if t.owner == id and (best == null or t.invested > best.invested):
				best = t
		cell = best.cell if best != null else 0
	else:
		var lead := board.monsters[0]
		for m in board.monsters:
			if m.ratio() > lead.ratio():
				lead = m
		var at := Vector2i(lead.pos.floor())
		cell = clampi(at.y, 0, board.map.height - 1) * board.map.width + clampi(at.x, 0, board.map.width - 1)
	sim.apply_command(id, {"a": "power", "cell": maxi(0, cell)})


## Plan de construction : ouverture à deux Arbalètes, puis les tourelles qui frappent et que sa
## classe ou ses talents renforcent, à tour de rôle (des plus efficaces au niveau 1 aux moins),
## avec des places pour l'anti-aérien et ses tourelles de soutien ; à défaut (classes d'économie),
## PLAN réduit à ce qu'il sait construire, ses tourelles de spécialisation placées tôt.
func builder_plan(sim: SimMatch, id: int) -> Array:
	var kit: PlayerKit = sim.players[id]["kit"]
	var data := sim.data
	if focus > 0:
		return FOCUS_PLAN.filter(func(type: String) -> bool: return kit.allows(type))
	var hits := func(type: String) -> bool:
		return kit.allows(type) and not data.towers[type]["support"] and float(data.tower_levels(type)[0]["damage"]) > 0.0
	var boosted := data.tower_order.filter(func(type: String) -> bool:
		return hits.call(type) and (kit._bonus_towers.has(type) or kit._per.has(type)))
	var favored := boosted.filter(func(type: String) -> bool: return data.towers[type]["ground"])
	var air := boosted.filter(func(type: String) -> bool: return not data.towers[type]["ground"])
	if air.is_empty():
		air = ["sentinel"]
	favored.sort_custom(func(a: String, b: String) -> bool: return Counters.early_value(data, a) > Counters.early_value(data, b))
	var boosters := data.tower_order.filter(func(type: String) -> bool:
		return kit.allows(type) and data.towers[type]["support"] and kit._per.has(type))
	# Classe de soutien ou de contrôle : ses tourelles renforcées tapent peu, il alterne avec des
	# tourelles de dégâts du tronc commun, comme le ferait un joueur
	var mean := 0.0
	for type in favored:
		mean += Counters.early_value(data, type) / maxf(1.0, favored.size())
	var weak := mean < WEAK_RATIO * Counters.early_value(data, "crossbow")
	var damage := PLAN.filter(func(type: String) -> bool: return kit.allows(type) and type != "sentinel")
	var plan := []
	if favored.size() >= 2:
		plan = ["crossbow", "crossbow"]
		var k := 0
		var g := 2
		while plan.size() < MAX_TOWERS:
			var n := plan.size()
			if n == 4 or n == 10:
				plan.append(air[(n / 10) % air.size()])
			elif (n == 7 or n == 13) and not boosters.is_empty():
				plan.append(boosters[(n / 7 - 1) % boosters.size()])
			elif weak and n % 2 == 0:
				plan.append(damage[g % damage.size()])
				g += 1
			else:
				plan.append(favored[k % favored.size()])
				k += 1
	else:
		plan = PLAN.filter(func(type: String) -> bool: return kit.allows(type))
		var signature := data.tower_order.filter(func(type: String) -> bool: return hits.call(type) and not data.common_towers.has(type))
		plan = plan.slice(0, 3) + signature + plan.slice(3) + signature
	for type in data.tower_order:
		if kit.allows(type) and not plan.has(type):
			plan.append(type)
	return plan

extends RefCounted
## Décisions d'un joueur automatique : à chaque réflexion, il compare chaque amélioration et
## chaque construction possible (tourelles qui tirent, de soutien, d'imprégnation) par le gain
## d'objectif (BotDefense) rapporté à son prix, en tenant compte de ses talents (les statistiques
## tiennent compte de son kit), des monstres à venir et des meilleures cases ; il économise pour
## l'action choisie plutôt que de disperser son or, préfère monter ses tourelles au maximum plutôt
## qu'en semer, et garde une réserve d'intérêts quand ses talents l'y poussent.

const Foes := preload("res://tests/bot/bot_foes.gd")
const Eval := preload("res://tests/bot/bot_eval.gd")
const Cells := preload("res://tests/bot/bot_cells.gd")
const Defense := preload("res://tests/bot/bot_defense.gd")
const Terrain := preload("res://tests/bot/bot_terrain.gd")
const Trace := preload("res://tests/bot/bot_trace.gd")

## Malus par tourelle qui tire encore sous son niveau maximum quand il envisage d'en ajouter une.
const SPREAD := 0.3
const MAX_TOWERS := 20
## Secondes avant de revoir une action qu'il économise pour payer.
const REPLAN := 12.0
## Tourelles qui tirent avant sa première tourelle d'économie (Comptoir, Chantier).
const ECON_AFTER := 3
const ECON_MARGIN := 150
## Types de tourelles qui tirent envisagés à chaque réflexion (les plus forts contre la vague).
const SHOOTER_TYPES := 7
## Réserve d'intérêts par vague passée (talents d'intérêts), jusqu'au plafond.
const RESERVE_PER_WAVE := 30
## Bonus à l'amélioration de sa tourelle la plus chère (il en pousse une au maximum).
const FOCUS := 1.2

var sim: SimMatch
var id: int
var kit: PlayerKit
var cells: Cells
var defense: Defense
var foes_reader := Foes.new()
var terrain = null
var foes := []
var weights := {}  # chemin -> [poids sol, poids air]
var prefs := {}  # type -> préférence (tourelles renforcées par ses talents, signatures)
var shooter_types := []
## Des Saboteurs (brouillage) sont à prévoir : il évite les gros paquets de tourelles.
var jammers := false
var _wave := -2
var _plan := {}
var _plan_age := 0.0
var _lives_mark := 0
## Trace des actions (bilans) : affichée quand vrai.
var verbose := false


func _init(p_sim: SimMatch, p_id: int, p_cells: Cells) -> void:
	sim = p_sim
	id = p_id
	kit = sim.players[id]["kit"]
	cells = p_cells
	defense = Defense.new(sim, id, cells)
	if kit.raze_charges + kit.tile_charges + int(kit.m("vein_tiles") + kit.m("mound_tiles") + kit.m("ditch_tiles")) > 0:
		terrain = Terrain.new()
	for type in sim.data.tower_order:
		if not kit.allows(type):
			continue
		var pref := 1.0
		if kit._per.has(type) or kit._bonus_towers.has(type):
			pref = 1.15
		if not sim.data.common_towers.has(type):
			pref = 1.3
		prefs[type] = pref


func mine() -> Array:
	var out := []
	for cell in sim.boards[0].towers:
		if sim.boards[0].towers[cell].owner == id:
			out.append(sim.boards[0].towers[cell])
	return out


func act(dt: float) -> void:
	var p: Dictionary = sim.players[id]
	var board := sim.boards[int(p["board"])]
	if not MatchFlow.can_trade(sim):
		return
	var towers := mine()
	if sim.wave_index != _wave:
		_wave = sim.wave_index
		foes = foes_reader.upcoming(sim)
		defense.set_foes(foes)
		weights = _weights()
		shooter_types = _rank_shooters()
		jammers = foes.any(func(f: Dictionary) -> bool: return float(sim.data.monsters[f["type"]]["jam_radius"]) > 0.0)
		_plan = {}
		_lives_mark = board.lives
		if verbose:
			Trace.ratios(self, towers)
	if terrain != null and terrain.act(sim, id, cells, towers, weights.keys()):
		return
	_plan_age += dt
	if _plan.is_empty() or _plan_age > REPLAN:
		_plan = decide(towers)
		_plan_age = 0.0
	if _plan.is_empty():
		return
	if int(p["gold"]) - reserve(board) >= int(_plan["cost"]):
		execute(_plan)
		_plan = {}
	elif board.lives < _lives_mark and not board.monsters.is_empty():
		var cheap := decide(towers, int(p["gold"]))  # ça fuit : la meilleure action payable tout de suite
		if not cheap.is_empty():
			execute(cheap)
			_plan = {}


## Poids de chaque couloir selon ce qui y reste mal défendu : [sol, air], d'après le gain
## marginal de l'objectif (poids / (1 + r)²) de chaque groupe.
func _need_weights(ratios: PackedFloat32Array) -> Dictionary:
	var out := {}
	for e in foes.size():
		var f: Dictionary = foes[e]
		var w: Array = out.get(f["path"], [0.0, 0.0])
		var r := float(ratios[e])
		w[1 if f["flying"] else 0] += float(f["weight"]) / ((1.0 + r) * (1.0 + r))
		out[f["path"]] = w
	for p in weights:  # chaque couloir garde un minimum, pour ne jamais rester sans case
		if not out.has(p):
			out[p] = [0.001, 0.0]
	return out


## Poids de chaque couloir à venir : [PV au sol, PV en l'air].
func _weights() -> Dictionary:
	var out := {}
	for f in foes:
		var w: Array = out.get(f["path"], [0.0, 0.0])
		w[1 if f["flying"] else 0] += float(f["hp"]) * float(f["count"]) * float(f["weight"])
		out[f["path"]] = w
	var total := 0.0
	for p in out:
		total += out[p][0] + out[p][1]
	for p in out:
		out[p] = [out[p][0] / total, out[p][1] / total] if total > 0.0 else [1.0, 0.0]
	return out


## Tourelles qui tirent les plus prometteuses contre les monstres à venir (sans la case).
func _rank_shooters() -> Array:
	var scores := {}
	for type in prefs:
		if sim.data.towers[type]["support"]:
			continue
		var s := sim.data.tower_stats(type, 0, -1, kit)
		var total := 0.0
		var calibration := Defense.Calibrate.factor(sim.data, type, 0)
		for f in foes:
			var v := Eval.dps(sim.data, type, s, f) * calibration + Eval.control(sim.data, type, s, f) * 30.0 + Eval.charm_damage(s, f) * 0.5
			total += v * float(f["weight"]) / (float(f["hp"]) * float(f["speed"]))
		scores[type] = total * prefs[type] / float(s["cost"])
	var types := scores.keys()
	types.sort_custom(func(a: String, b: String) -> bool: return scores[a] > scores[b])
	return types.slice(0, SHOOTER_TYPES)


## Meilleure action : {kind: "build"/"upgrade", type, cell, cost} ou {} ; budget ≥ 0 : payable.
func decide(towers: Array, budget := -1) -> Dictionary:
	var board := sim.boards[0]
	var descs := []
	var shooters := 0
	var low := 0
	var top_invested := 0
	for t in towers:
		descs.append(defense.describe(t))
		if not t.support:
			shooters += 1
			low += 1 if t.level + 1 < sim.data.levels_for(t.type, kit).size() else 0
			top_invested = maxi(top_invested, t.invested)
	var base_ratios := defense.ratios(descs)
	var base := Eval.objective(foes, base_ratios)
	var need := _need_weights(base_ratios)
	var best := {}
	var best_score := 0.0
	var seen := []  # trace : [score, action]
	for i in towers.size():
		var t: SimTower = towers[i]
		var levels := sim.data.levels_for(t.type, kit)
		if t.level + 1 >= levels.size():
			continue
		var cost := kit.cost(int(levels[t.level + 1]["cost"]), _discount(board, t.cell, t.type))
		if budget >= 0 and cost > budget:
			continue
		var trial := descs.duplicate()
		trial[i] = defense.virtual(t.type, t.level + 1, t.cell)
		var score: float = (defense.objective(trial) - base) / cost
		score *= FOCUS if not t.support and t.invested == top_invested else 1.0
		seen.append([score, "+%s@%d" % [t.type, t.cell]])
		if score > best_score:
			best_score = score
			best = {"kind": "upgrade", "type": t.type, "cell": t.cell, "cost": cost}
	if shooters < MAX_TOWERS:
		var spread := 1.0 / (1.0 + SPREAD * low) if shooters >= 2 else 1.0
		for type in shooter_types:
			for found in cells.best_cells(sim, id, type, need, towers, jammers):
				var cost := kit.cost(int(sim.data.tower_levels(type)[0]["cost"]), MatchActions.zone_discount(board, found[0]))
				if budget >= 0 and cost > budget:
					continue
				var trial := descs.duplicate()
				trial.append(defense.virtual(type, 0, found[0]))
				var score: float = (defense.objective(trial) - base) / cost * spread * prefs[type]
				seen.append([score, "%s@%d" % [type, found[0]]])
				if score > best_score:
					best_score = score
					best = {"kind": "build", "type": type, "cell": found[0], "cost": cost}
	if shooters >= 2:
		for type in prefs:
			var def: Dictionary = sim.data.towers[type]
			if not def["support"] or _is_economy(type) or _count(towers, type) >= (2 if shooters >= 8 else 1):
				continue
			var found := cells.best_support_cell(sim, id, type, towers, weights.keys())
			if found[0] < 0:
				continue
			var cost := kit.cost(int(def["levels"][0]["cost"]), MatchActions.zone_discount(board, found[0]))
			if budget >= 0 and cost > budget:
				continue
			var trial := descs.duplicate()
			trial.append(defense.virtual(type, 0, found[0]))
			var score: float = (defense.objective(trial) - base) / cost * prefs[type]
			if score > best_score:
				best_score = score
				best = {"kind": "build", "type": type, "cell": found[0], "cost": cost}
	var econ := _economy_plan(towers, shooters, best) if budget < 0 else {}
	if verbose and budget < 0 and not best.is_empty():
		seen.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var top := seen.slice(0, 5).map(func(s: Array) -> String: return "%s %.4f" % [s[1], s[0] * 1000.0])
		print("    choix v%d : %s %s (%.4f) ; %s" % [sim.wave_index + 1, best["kind"], best["type"], best_score * 1000.0, ", ".join(top)])
	return econ if not econ.is_empty() else best


## Tourelles d'économie (Comptoir, Chantier) : la première après ECON_AFTER tourelles qui tirent,
## puis ses améliorations, seulement quand il peut les payer en plus de l'action de défense choisie
## (jamais en économisant pour elles, ni quand ça fuit).
func _economy_plan(towers: Array, shooters: int, best: Dictionary) -> Dictionary:
	var gold := int(sim.players[id]["gold"])
	var board := sim.boards[0]
	if shooters < ECON_AFTER or board.lives < _lives_mark:
		return {}
	for type in prefs:
		if not _is_economy(type):
			continue
		var owned := towers.filter(func(t: SimTower) -> bool: return t.type == type)
		var plan := {}
		if owned.is_empty():
			var found := cells.best_support_cell(sim, id, type, towers, weights.keys())
			if found[0] < 0:
				continue
			plan = {"kind": "build", "type": type, "cell": found[0], "cost": kit.cost(int(sim.data.towers[type]["levels"][0]["cost"]))}
		else:
			var t: SimTower = owned[0]
			var levels := sim.data.levels_for(type, kit)
			if t.level + 1 >= levels.size():
				continue
			plan = {"kind": "upgrade", "type": type, "cell": t.cell, "cost": kit.cost(int(levels[t.level + 1]["cost"]), _discount(board, t.cell, type))}
		if gold >= int(plan["cost"]) + int(best.get("cost", 0)) + ECON_MARGIN:
			return plan
	return {}


func _is_economy(type: String) -> bool:
	var l: Dictionary = sim.data.towers[type]["levels"][0]
	return float(l.get("aura_bounty", 0.0)) > 0.0 or float(l.get("aura_discount", 0.0)) > 0.0


static func _count(towers: Array, type: String) -> int:
	return towers.filter(func(t: SimTower) -> bool: return t.type == type).size()


func _discount(board: SimBoard, cell: int, type: String) -> float:
	return MatchActions.zone_discount(board, cell) + MatchEconomy.team_discount(sim, id) + TileBonus.discount(sim.data, board.map, cell, type)


## Or gardé pour les intérêts quand ses talents en montent le taux (Usurier) et que rien ne fuit.
func reserve(board: SimBoard) -> int:
	var rule := kit.interest_rule(sim.data, sim.difficulty)
	var base := PlayerKit.base_interest(sim.data, sim.difficulty)
	if float(rule[0]) <= float(base[0]):
		return 0
	if board.lives < _lives_mark:
		return 0
	return mini(MatchFlow.interest_cap_gold(rule), RESERVE_PER_WAVE * maxi(0, sim.wave_index))


func execute(plan: Dictionary) -> bool:
	if verbose:
		print("  [v%d %ds or %d vies %d] %s %s en %d (%d or)" % [sim.wave_index + 1, int(sim.boards[0].clock), sim.players[id]["gold"], sim.boards[0].lives, plan["kind"], plan["type"], plan["cell"], plan["cost"]])
	if plan["kind"] == "upgrade":
		return sim.apply_command(id, {"a": "upgrade", "cell": plan["cell"]}) == ""
	if sim.apply_command(id, {"a": "build", "cell": plan["cell"], "tower": plan["type"]}) != "":
		return false
	if sim.data.towers[plan["type"]].get("attack", "shot") == "beam":  # rayon : il reste sur le plus résistant
		sim.apply_command(id, {"a": "mode", "cell": plan["cell"]})
	return true

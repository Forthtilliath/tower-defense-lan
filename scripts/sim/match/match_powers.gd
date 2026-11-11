class_name MatchPowers
extends RefCounted
## Pouvoirs actifs (talents ultimes) : un bouton par joueur, rechargé en quelques vagues. Certains
## se visent (case `cell`), d'autres agissent tout de suite ; les pouvoirs à durée restent actifs
## sur le plateau (méta « powers » : [[id, joueur, fin], ...]) et sont lus par le combat.
## Les dégâts des pouvoirs suivent l'or investi par le joueur dans ses tourelles (power_base).

## id -> [nom, à viser ?, recharge (vagues), durée (s, 0 : instantané)]
const POWERS := {
	"quake": ["Séisme", false, 3, 0.0], "perfect_shot": ["Tir parfait", true, 3, 0.0],
	"carpet": ["Tapis de bombes", true, 3, 0.0], "lead_rain": ["Pluie de plomb", false, 3, 6.0],
	"meteor": ["Météore", true, 3, 0.0], "tempest": ["Tempête", false, 3, 8.0],
	"absolute_zero": ["Zéro absolu", false, 3, 0.0], "tornado": ["Tornade", false, 3, 0.0],
	"plague": ["Fléau originel", false, 3, 10.0], "feast": ["Curée", false, 3, 0.0],
	"ice_age": ["Ère glaciaire", false, 3, 8.0], "chain_lightning": ["Foudre en chaîne", false, 3, 8.0],
	"parade": ["Grande parade", false, 3, 0.0], "dissolution": ["Dissolution", false, 3, 10.0],
	"heroism": ["Héroïsme", false, 3, 6.0], "retreat": ["Repli", false, 5, 0.0],
	"gold_rush": ["Ruée vers l'or", false, 3, 12.0], "cash_in": ["Encaissement", false, 3, 0.0],
	"golden_age": ["Âge d'or", false, 3, 0.0], "all_in": ["Va-tout", false, 3, 15.0],
	"genius": ["Coup de génie", true, 3, 0.0], "remount": ["Remontage", false, 3, 15.0],
	"elbow_grease": ["Coup de collier", false, 3, 10.0], "reshape": ["Remodelage", false, 3, 0.0],
}
const POWER_SCALE := 0.15
const QUAKE_STUN := 2.0
const QUAKE_HP := 0.1
const SHOT_WIDTH := 0.5
const SHOT_MULT := 2.0
const BLASTS := 12
const BLAST_RADIUS := 1.0
const BLAST_SPREAD := 2.0
const METEOR_RADIUS := 1.5
const METEOR_PATCH := 6.0
const FREEZE := 2.5
const PUSH := 3.0
const RETREAT := 4.0
const FEAST := 0.15
const FEAST_BOSS := 0.05
const PARADE := 5
const PARADE_TIME := 4.0
const PLAGUE_TIME := 999.0
const TEMPEST_CHAIN := 15
const CHAIN_SHARE := 0.25
const GOLDEN_AGE := 100
const GOLDEN_AGE_PER_WAVE := 10
const CASH_IN_WAVES := 3


## Vagues avant que le pouvoir revienne (0 : prêt ; -1 : aucun pouvoir).
static func waves_left(sim: SimMatch, p: Dictionary) -> int:
	var id: String = p["kit"].power
	if id == "":
		return -1
	return maxi(0, int(POWERS[id][2]) - (sim.wave_index - int(p.get("power_wave", -99))))


## Lance le pouvoir du joueur (sur la case `cell` s'il se vise). "" ou la raison du refus.
static func use(sim: SimMatch, id: int, p: Dictionary, b: SimBoard, cell: int) -> String:
	var power: String = p["kit"].power
	if power == "":
		return "Aucun pouvoir : il vient avec le talent ultime"
	if not sim.started():
		return "Le pouvoir se lance pendant la partie"
	if waves_left(sim, p) > 0:
		return "Pouvoir en recharge : encore %d vague(s)" % waves_left(sim, p)
	var refusal := _fire(sim, id, p, b, power, cell)
	if refusal != "":
		return refusal
	p["power_wave"] = sim.wave_index
	var duration: float = POWERS[power][3]
	if duration > 0.0:
		var list: Array = b.get_meta("powers", [])
		list.append([power, id, b.clock + duration])
		b.set_meta("powers", list)
	return ""


## Pouvoir à durée en cours sur ce plateau (pour ce joueur, ou pour n'importe qui si owner < 0).
static func active(b: SimBoard, power: String, owner := -1) -> bool:
	for e in b.get_meta("powers", []):
		if e[0] == power and (owner < 0 or e[1] == owner):
			return true
	return false


## Fin des pouvoirs écoulés, effets continus (Ère glaciaire, Dissolution, Va-tout).
static func update(sim: SimMatch, _dt: float) -> void:
	for b in sim.boards:
		var list: Array = b.get_meta("powers", [])
		if list.is_empty():
			continue
		b.set_meta("powers", list.filter(func(e: Array) -> bool: return b.clock < float(e[2])))
		b.set_meta("leak_extra", 1 if active(b, "all_in") else 0)
		for m in b.monsters:
			if active(b, "ice_age") and m.marks.is_frostbitten():
				m.apply_slow(0.5, 0.3)
				m.marks.apply_heal_block(1.0, 0.3)
			if active(b, "dissolution"):
				m.apply_shred(0.9, 0.3)
				m.marks.apply_heal_block(1.0, 0.3)


## Cadence en plus d'une tourelle sous un pouvoir (Pluie de plomb, Héroïsme, Coup de collier).
static func rate_mult(b: SimBoard, t: SimTower) -> float:
	var mult := 1.0
	if t.type in ["dart", "gatling"] and active(b, "lead_rain", t.owner):
		mult *= 3.0
	for kind in t.buffs:
		if active(b, "heroism", int(t.buffs[kind][1])):
			mult *= 2.0
			break
	if near_own(b, t, "worksite", "elbow_grease"):
		mult *= 1.5
	return mult


## Dégâts en plus d'une tourelle sous un pouvoir (Coup de collier).
static func damage_mult(b: SimBoard, t: SimTower) -> float:
	return 1.5 if near_own(b, t, "worksite", "elbow_grease") else 1.0


## Une tourelle à portée d'une tourelle `type` d'un joueur dont le pouvoir `power` est actif.
static func near_own(b: SimBoard, t: SimTower, type: String, power: String) -> bool:
	if not b.has_meta("powers"):
		return false
	for cell in b.towers:
		var s: SimTower = b.towers[cell]
		if s.type == type and active(b, power, s.owner) and s.center.distance_to(t.center) <= float(s.stats["range"]):
			return true
	return false


## Primes multipliées par les pouvoirs (Ruée vers l'or : tous ; Va-tout : son lanceur).
static func bounty_mult(sim: SimMatch, owner: int) -> float:
	var mult := 1.0
	for b in sim.boards:
		if active(b, "gold_rush"):
			mult *= 2.0
		if active(b, "all_in", owner):
			mult *= 3.0
	return mult


## Force des pouvoirs de dégâts : part de l'or investi dans ses tourelles.
static func power_base(sim: SimMatch, id: int) -> float:
	return maxf(50.0, MatchEconomy.invested(sim, id) * POWER_SCALE)


static func _fire(sim: SimMatch, id: int, p: Dictionary, b: SimBoard, power: String, cell: int) -> String:
	var base := power_base(sim, id)
	var credit := BoardCombat.solo(id)
	var rewards := []
	var at := b.map.cell_center(cell)
	match power:
		"quake":
			for m in _in_reach_of(b, id, func(t: SimTower) -> bool: return t.type == "crusher"):
				m.apply_control(SimMonster.Crowd.STUN, QUAKE_STUN, id)
				BoardCombat.damage(b, m, m.max_hp * QUAKE_HP, true, credit, rewards)
		"perfect_shot":
			var from := _strongest(b, id, "ballista")
			if from == null:
				return "Il te faut une Baliste"
			var dir := (at - from.center).normalized()
			b.add_fx(SimBoard.Fx.BEAM, from.center, from.center + dir * 40.0)
			for m: SimMonster in b.monsters.duplicate():
				var rel: Vector2 = m.pos - from.center
				if rel.dot(dir) > 0.0 and absf(rel.cross(dir)) <= SHOT_WIDTH:
					BoardCombat.damage(b, m, base * SHOT_MULT, false, credit, rewards)
		"carpet", "meteor":
			var hits := BLASTS if power == "carpet" else 1
			for k in hits:
				var spot := at + (Vector2(b.rng.randf_range(-1, 1), b.rng.randf_range(-1, 1)) * BLAST_SPREAD if hits > 1 else Vector2.ZERO)
				var radius := BLAST_RADIUS if hits > 1 else METEOR_RADIUS
				b.add_fx(SimBoard.Fx.RING, spot, Vector2.ZERO, radius)
				for m in b.monsters.duplicate():
					if not m.flying and m.pos.distance_to(spot) <= radius:
						BoardCombat.damage(b, m, base / hits * (1.0 if hits == 1 else 3.0), false, credit, rewards)
			if power == "meteor":
				_fire_patch(b, id, at, base)
		"absolute_zero":
			for m in _in_reach_of(b, id, func(t: SimTower) -> bool: return b.data.towers[t.type]["element"] == "ice"):
				m.apply_control(SimMonster.Crowd.STUN, FREEZE, id)
		"tornado", "retreat":
			for m in b.monsters:
				m.progress = maxf(0.0, m.progress - (PUSH if power == "tornado" else RETREAT) * (0.5 if BoardFeats.is_big(m) else 1.0))
		"feast":
			for m in b.monsters.duplicate():
				if m.is_bleeding():
					BoardCombat.damage(b, m, m.max_hp * (FEAST_BOSS if BoardFeats.is_big(m) else FEAST), true, credit, rewards)
		"parade":
			var front := b.monsters.filter(func(m: SimMonster) -> bool: return not BoardFeats.is_big(m) and not m.flying and not m.mechanical)
			front.sort_custom(func(x: SimMonster, y: SimMonster) -> bool: return x.ratio() > y.ratio())
			for m in front.slice(0, PARADE):
				m.control_guard = 0.0
				m.apply_control(SimMonster.Crowd.CHARM, PARADE_TIME, id)
		"cash_in":
			p["gold"] += CASH_IN_WAVES * floori(int(p["gold"]) * p["kit"].interest_rule(sim.data)[0])
		"golden_age":
			for other in sim.order:
				if other != id:
					MatchEconomy.credit(sim, other, GOLDEN_AGE + GOLDEN_AGE_PER_WAVE * maxi(0, sim.wave_index))
		"genius":
			var t := MatchActions.own_tower(id, b, cell)
			if t == null:
				return "Vise une de tes tourelles"
			if t.level + 1 >= sim.data.levels_for(t.type, p["kit"]).size():
				return "Cette tourelle est déjà au niveau maximum"
			t.level += 1
			b.refresh_stats(t)
		"reshape":
			for kind in ["raze", "tile"] + BoardTerrain.OWN_CHARGES.values():
				p.erase("used_" + kind)
	for r in rewards:
		MatchEconomy.credit_bounty(sim, r[0], r[1], r.size() > 2 and r[2], r.size() > 3 and r[3])
	return ""


## Monstres à portée d'au moins une tourelle du joueur qui répond au filtre.
static func _in_reach_of(b: SimBoard, id: int, keep: Callable) -> Array[SimMonster]:
	var out: Array[SimMonster] = []
	for m in b.monsters:
		for cell in b.towers:
			var t: SimTower = b.towers[cell]
			if t.owner == id and keep.call(t) and t.center.distance_to(m.pos) <= BoardAuras.reach(t):
				out.append(m)
				break
	return out


static func _strongest(b: SimBoard, id: int, type: String) -> SimTower:
	var best: SimTower = null
	for cell in b.towers:
		var t: SimTower = b.towers[cell]
		if t.owner == id and t.type == type and (best == null or t.level > best.level):
			best = t
	return best


## Nappe de feu du Météore.
static func _fire_patch(b: SimBoard, id: int, at: Vector2, base: float) -> void:
	var p := SimProjectile.new()
	p.pos = at
	p.stats = {"patch_radius": METEOR_RADIUS, "patch_duration": METEOR_PATCH, "patch_dps": base * 0.1}
	p.credit = BoardCombat.solo(id)
	p.owner = id
	p.kind = maxi(0, b.data.tower_order.find("brazier"))
	p.element = "fire"
	BoardPatches.add(b, p)

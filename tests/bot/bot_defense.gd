extends RefCounted
## Modèle de la défense d'un joueur automatique : pour chaque tourelle (réelle ou envisagée),
## les dégâts qu'elle infligerait à un monstre de chaque groupe à venir sur son trajet, auras et
## imprégnations des tourelles de soutien comprises ; le temps gagné par ses contrôles ; et le
## rapport « dégâts possibles / PV » de chaque groupe, dont BotEval tire l'objectif.

const Eval := preload("res://tests/bot/bot_eval.gd")
const Cells := preload("res://tests/bot/bot_cells.gd")
const Calibrate := preload("res://tests/bot/bot_calibrate.gd")

## Distance à laquelle une tourelle de contrôle (ralentir, geler, clouer) profite à une voisine.
const SYNERGY := 3.0
const CTL_CAP := 0.7
## Part comptée des poisons et saignements non cumulables au-delà du plus fort.
const SINGLE_REST := 0.3
## Durée typique d'un effet continu (secondes) : il lui faut autant de route après la portée.
const DOT_TIME := 3.5

var sim: SimMatch
var id: int
var kit: PlayerKit
var cells: Cells
var foes := []
var _cache := {}
var _stats := {}


func _init(p_sim: SimMatch, p_id: int, p_cells: Cells) -> void:
	sim = p_sim
	id = p_id
	kit = sim.players[id]["kit"]
	cells = p_cells


func set_foes(p_foes: Array) -> void:
	foes = p_foes
	_cache.clear()


## Description d'une tourelle posée.
func describe(t: SimTower) -> Dictionary:
	return {"type": t.type, "level": t.level, "cell": t.cell, "center": t.center, "special": t.special, "support": t.support}


## Description d'une tourelle envisagée.
func virtual(type: String, level: int, cell: int) -> Dictionary:
	var board := sim.boards[0]
	return {"type": type, "level": level, "cell": cell, "center": board.map.cell_center(cell),
		"special": board.map.special_at(cell), "support": sim.data.towers[type]["support"]}


## Statistiques d'une tourelle décrite (mises en cache ; à ne pas modifier : dupliquer d'abord).
func stats(d: Dictionary) -> Dictionary:
	var key := "s/%s/%d/%d" % [d["type"], d["level"], d["special"]]
	if not _stats.has(key):
		_stats[key] = sim.data.tower_stats(d["type"], d["level"], d["special"], kit)
	return _stats[key]


## Rapport dégâts possibles / PV de chaque groupe à venir pour cette liste de tourelles.
func ratios(descs: Array) -> PackedFloat32Array:
	var n := foes.size()
	var total := PackedFloat32Array()
	total.resize(n)
	total.fill(0.0)
	var single_best := total.duplicate()
	var single_rest := total.duplicate()
	var charm := total.duplicate()
	var auras := _auras(descs)
	var ctl_vecs := []  # par tourelle : [temps gagné par groupe, dégâts des charmés] ou []
	for i in descs.size():
		var d: Dictionary = descs[i]
		ctl_vecs.append([] if d["support"] else _ctl_vec(d, auras[i]))
	for i in descs.size():
		var d: Dictionary = descs[i]
		if d["support"]:
			continue
		var v := _vec(d, auras[i], _flags(descs, d))
		var gained := _gained_near(descs, ctl_vecs, i)  # ses voisines de contrôle gardent les monstres sous son feu
		for e in n:
			total[e] += v[0][e] * (1.0 + gained[e])
			var one: float = v[1][e] * (1.0 + gained[e])
			if one > single_best[e]:  # effet non cumulable : le plus fort compte, les autres servent d'autres monstres
				single_rest[e] += single_best[e]
				single_best[e] = one
			else:
				single_rest[e] += one
		if not ctl_vecs[i].is_empty():
			for e in n:
				charm[e] += ctl_vecs[i][1][e]
	var out := PackedFloat32Array()
	out.resize(n)
	for e in n:
		out[e] = (total[e] + single_best[e] + SINGLE_REST * single_rest[e] + charm[e]) / float(foes[e]["hp"])
	return out


## Temps gagné, par groupe, grâce aux tourelles de contrôle à portée de synergie de la i-ième
## (elle comprise) : la plus forte compte en entier, les autres pour une part.
func _gained_near(descs: Array, ctl_vecs: Array, i: int) -> PackedFloat32Array:
	var n := foes.size()
	var best := PackedFloat32Array()
	best.resize(n)
	var rest := best.duplicate()
	var here: Vector2 = descs[i]["center"]
	for j in descs.size():
		if ctl_vecs[j].is_empty() or descs[j]["center"].distance_to(here) > SYNERGY:
			continue
		var v: PackedFloat32Array = ctl_vecs[j][0]
		for e in n:
			if v[e] > best[e]:
				rest[e] += best[e]
				best[e] = v[e]
			else:
				rest[e] += v[e]
	for e in n:
		best[e] = minf(CTL_CAP, best[e] + 0.4 * rest[e])
	return best


func objective(descs: Array) -> float:
	return Eval.objective(foes, ratios(descs))


## Auras reçues par chaque tourelle de la liste (même règle que BoardAuras.refresh) : kind -> valeur.
func _auras(descs: Array) -> Array:
	var out := []
	for d in descs:
		out.append({})
	for i in descs.size():
		var s: Dictionary = descs[i]
		if not s["support"]:
			continue
		var st := stats(s)
		var reach := float(st["range"])
		for j in descs.size():
			var t: Dictionary = descs[j]
			if t["support"] or t["center"].distance_to(s["center"]) > reach:
				continue
			var element: String = sim.data.towers[t["type"]]["element"]
			for kind in BoardAuras.KINDS:
				var value := float(st.get(BoardAuras.KINDS[kind], 0.0))
				if value <= 0.0 or value <= float(out[j].get(kind, 0.0)):
					continue
				if BoardAuras.IMBUE.has(kind) and not kit.imbue_all and element != BoardAuras.IMBUE[kind]:
					continue
				out[j][kind] = value
	return out


## Voisinage utile à une tourelle : [ralentie, étourdie, volants cloués au sol].
func _flags(descs: Array, d: Dictionary) -> Array:
	var slowed := false
	var stunned := false
	var grounded := false
	for o in descs:
		if o["support"] or o["center"].distance_to(d["center"]) > SYNERGY:
			continue
		var st := stats(o)
		if float(st.get("slow_factor", 1.0)) < 1.0 or float(st.get("slow", 0.0)) > 0.0:
			slowed = true
		if float(st.get("stun_chance", 0.0)) > 0.0:
			stunned = true
		if float(st.get("ground_duration", 0.0)) > 0.0:
			grounded = true
	return [slowed, stunned, grounded]


## Dégâts infligés à un monstre de chaque groupe pendant son passage à portée (mis en cache) :
## [part cumulable, part non cumulable] (voir BotEval.dps_parts).
func _vec(d: Dictionary, auras: Dictionary, flags: Array) -> Array:
	var key := "%d/%s/%d/%d/%s/%s" % [d["cell"], d["type"], d["level"], d["special"], str(auras), str(flags)]
	if _cache.has(key):
		return _cache[key]
	var s := stats(d).duplicate()
	_apply_auras(s, auras)
	var def: Dictionary = sim.data.towers[d["type"]]
	var reach := float(s["range"])
	var air: bool = def["air"] or int(s.get("all_targets", 0)) > 0 or flags[2]
	var calibration := Calibrate.factor(sim.data, d["type"], d["level"])
	var out := PackedFloat32Array()
	out.resize(foes.size())
	var single := out.duplicate()
	for e in foes.size():
		var f: Dictionary = foes[e]
		var slowed: bool = flags[0] and not f["slow_immune"]
		if f["flying"] and not air:
			continue
		var cov := cells.coverage(d["cell"], reach, f["path"], f["flying"])
		var seconds := exposure(f, cov)
		var parts := Eval.dps_parts(sim.data, d["type"], s, f, slowed, flags[1], flags[2], seconds)
		if float(parts[0]) + float(parts[1]) + float(parts[2]) <= 0.0:
			continue
		for k in 3:
			parts[k] *= calibration
		var frost := float(auras.get("frostbite", 0.0))
		if frost > 0.0 and not f["mech"]:
			parts[1] += frost * float(f["taken"].get("ice", 1.0)) * (MonsterMarks.FROSTBITE_SLOWED if slowed else 1.0)
		var shock := 1.0 + 1.5 * float(auras.get("shock", 0.0))
		var time := seconds * shock
		# Effets continus : perdus en partie si la sortie est trop proche pour qu'ils finissent d'agir
		var tail := clampf(cells.tail(d["cell"], reach, f["path"], f["flying"]) / (float(f["speed"]) * DOT_TIME), 0.25, 1.0)
		out[e] = (float(parts[0]) + float(parts[1]) * tail) * time
		single[e] = float(parts[2]) * tail * time
	_cache[key] = [out, single]
	return _cache[key]


## Secondes de tir par monstre du groupe pour une route couverte `cov` : la file entière (ses
## `count` monstres espacés de `gap`) passe sous le feu, qui se répartit entre eux ; entre deux
## monstres plus espacés que la couverture, la tourelle n'a personne à viser.
static func exposure(f: Dictionary, cov: float) -> float:
	if cov <= 0.0:
		return 0.0
	var count := maxf(1.0, float(f["count"]))
	return (cov + (count - 1.0) * minf(float(f["gap"]), cov)) / float(f["speed"]) / count


## Applique les auras aux statistiques (cadence, dégâts, contrôles, portée, critique, talents du Support).
static func _apply_auras(s: Dictionary, auras: Dictionary) -> void:
	if auras.is_empty():
		return
	GameData.scale_damage(s, 1.0 + float(auras.get("damage", 0.0)) + float(auras.get("veteran", 0.0)) * 20.0)
	GameData.scale_control(s, 1.0 + float(auras.get("cc", 0.0)))
	s["rate"] *= 1.0 + float(auras.get("rate", 0.0)) + 0.2 * float(auras.get("charge", 0.0)) + 0.3 * float(auras.get("rush", 0.0))
	s["range"] *= 1.0 + float(auras.get("range", 0.0))
	s["crit_chance"] = minf(1.0, float(s.get("crit_chance", 0.0)) + float(auras.get("crit", 0.0)))
	s["vs_late"] = float(s.get("vs_late", 0.0)) + float(auras.get("late", 0.0))
	if float(auras.get("stun", 0.0)) > 0.0:
		s["stun_chance"] = minf(1.0, float(s.get("stun_chance", 0.0)) + float(auras.get("stun", 0.0)))
		s["stun_duration"] = maxf(float(s.get("stun_duration", 0.0)), BoardSupport.AURA_STUN)
	if float(auras.get("air", 0.0)) > 0.0:
		s["all_targets"] = 1


## Temps gagné et dégâts des charmés d'une tourelle, par groupe (mis en cache) ; vide si elle
## n'a aucun contrôle.
func _ctl_vec(d: Dictionary, auras: Dictionary) -> Array:
	var key := "c/%d/%s/%d/%d/%s" % [d["cell"], d["type"], d["level"], d["special"], str(auras)]
	if _cache.has(key):
		return _cache[key]
	var s := stats(d).duplicate()
	_apply_auras(s, auras)
	var keys := ["stun_chance", "fear_chance", "charm_chance", "slow"]
	var has := float(s.get("slow_factor", 1.0)) < 1.0
	for k in keys:
		has = has or float(s.get(k, 0.0)) > 0.0
	if not has:
		_cache[key] = []
		return []
	var gained := PackedFloat32Array()
	gained.resize(foes.size())
	var charm := gained.duplicate()
	for e in foes.size():
		var f: Dictionary = foes[e]
		var c := Eval.control(sim.data, d["type"], s, f)
		var charm_dps := Eval.charm_damage(s, f)
		if c <= 0.0 and charm_dps <= 0.0:
			continue
		var cov := cells.coverage(d["cell"], float(s["range"]), f["path"], f["flying"])
		gained[e] = c * minf(1.0, cov / 2.5) * Eval.OVERLAP
		charm[e] = charm_dps * exposure(f, cov)
	_cache[key] = [gained, charm]
	return _cache[key]

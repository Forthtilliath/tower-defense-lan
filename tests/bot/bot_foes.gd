extends RefCounted
## Lecture des vagues par le joueur automatique : les monstres de la vague en cours et des
## suivantes (de moins en moins), plus le profil du reste de la carte (volants, blindés, boss à
## prévoir), tels qu'ils apparaîtront (difficulté, vague spéciale, renfort coop, entrée par vague),
## couloir par couloir. Chaque entrée est un groupe de monstres sur un chemin ; son poids est le
## nombre de vies qu'il ferait perdre, pondéré par son éloignement.

## Poids de la vague en cours, puis des suivantes.
const LOOK := [1.0, 0.8, 0.4, 0.2]
## Poids de chaque vague plus lointaine (regroupées par monstre et par chemin).
const PROFILE_WEIGHT := 0.02

var _cache := {}  # "vague/poids" -> entrées


## Entrées à venir : [{type, hp, speed, count, gap, weight, flying, armor, mech, hover, big,
## slow_immune, cc_resist, taken, path, damage}, ...]. gap : distance entre deux monstres du groupe.
func upcoming(sim: SimMatch) -> Array:
	var out := []
	var total := sim.map.waves.size()
	var first := maxi(0, sim.wave_index)
	for k in LOOK.size():
		if first + k < total:
			out.append_array(entries(sim, first + k, LOOK[k]))
	out.append_array(profile(sim, first + LOOK.size()))
	return out


## Profil des vagues à partir de `from` : un groupe par monstre et par chemin, PV moyens.
func profile(sim: SimMatch, from: int) -> Array:
	var key := "profil/%d" % from
	if _cache.has(key):
		return _cache[key]
	var merged := {}
	for w in range(from, sim.map.waves.size()):
		for f in entries(sim, w, PROFILE_WEIGHT):
			var id := "%s/%d" % [f["type"], f["path"]]
			if not merged.has(id):
				merged[id] = f.duplicate()
				merged[id]["hp"] = 0.0
				merged[id]["count"] = 0.0
				merged[id]["weight"] = 0.0
			var m: Dictionary = merged[id]
			m["hp"] += float(f["hp"]) * float(f["count"])
			m["count"] += float(f["count"])
			m["weight"] += float(f["weight"])
	var out := []
	for id in merged:
		var m: Dictionary = merged[id]
		m["hp"] /= maxf(1.0, float(m["count"]))
		out.append(m)
	_cache[key] = out
	return out


func entries(sim: SimMatch, w: int, weight: float) -> Array:
	var key := "%d/%.2f" % [w, weight]
	if _cache.has(key):
		return _cache[key]
	var map := sim.map
	var wave: Dictionary = sim.data.waves[map.waves[w]]
	var mod: Dictionary = sim.data.modifiers.get(wave.get("modifier", ""), {})
	var hp_mult := float(wave["hp"]) * sim.monster_hp_mult() * float(mod.get("hp", 1.0))
	var count_mult := float(sim.difficulty["count"])
	if sim.mode == SimMatch.Mode.COOP:
		var scaling := sim.coop_scaling(sim.order.size())
		hp_mult *= scaling[0]
		count_mult *= scaling[1]
	var spacing := maxf(count_mult, 1.0)
	count_mult *= float(mod.get("count", 1.0))
	var paths: Array = MapSpawns.wave_paths(map, w)
	if paths.is_empty():
		paths = sim.open_paths.duplicate() if not sim.open_paths.is_empty() else range(map.start_count())
	var out := []
	for g in wave["groups"]:
		var m := SimMonster.new()
		m.setup(sim.data.monsters[g["monster"]], hp_mult, 1.0, mod)
		m.armor += sim.boards[0].armor_bonus
		var count := maxi(1, roundi(int(g["count"]) * count_mult))
		var speed := m.speed * (map.flyer_speed if m.flying else 1.0)
		for p in paths:
			out.append({
				"type": g["monster"], "hp": m.max_hp, "speed": speed, "count": float(count) / paths.size(),
				"gap": maxf(0.3, speed * float(g["interval"]) / spacing), "weight": weight,
				"flying": m.flying, "armor": m.armor, "mech": m.mechanical, "hover": m.hover,
				"big": BoardFeats.is_big(m), "slow_immune": m.slow_immune, "cc_resist": m.cc_resist,
				"taken": m.element_taken, "path": int(p), "regen": m.regen, "damage": maxi(1, m.damage),
			})
	for f in out:  # poids : les vies que le groupe ferait perdre, rejetons compris
		f["weight"] = weight * float(f["count"]) * (float(f["damage"]) + spawns(sim, f))
	_cache[key] = out
	return out


## Vies que les rejetons d'un monstre coûteraient s'il traversait la carte : petits pondus en
## marchant ou par palier de PV, division à la mort, morts relevés par un nécromancien.
static func spawns(sim: SimMatch, f: Dictionary) -> float:
	var def: Dictionary = sim.data.monsters[f["type"]]
	var crossing := sim.map.path_length(f["path"], f["flying"]) / maxf(0.1, float(f["speed"]))
	var out := 0.0
	if String(def["brood_into"]) != "":
		if float(def["brood_interval"]) > 0.0:
			out += crossing / float(def["brood_interval"])
		out += float(def["brood_steps"])
	out += float(def["split_count"]) * 0.5
	if String(def["raise_into"]) != "" and float(def["raise_interval"]) > 0.0:
		out += crossing / float(def["raise_interval"]) * 0.5
	return out


## Part des points de vie à venir portée par des volants (0 à 1).
static func air_share(foes: Array) -> float:
	var total := 0.0
	var air := 0.0
	for f in foes:
		var hp: float = f["hp"] * f["count"] * f["weight"]
		total += hp
		air += hp if f["flying"] else 0.0
	return air / total if total > 0.0 else 0.0


## Nombre de monstres d'un groupe touchés d'un coup dans un rayon (file de monstres espacés de gap).
static func hits(f: Dictionary, radius: float) -> float:
	return clampf(1.0 + 2.0 * radius / float(f["gap"]), 1.0, maxf(1.0, float(f["count"])))

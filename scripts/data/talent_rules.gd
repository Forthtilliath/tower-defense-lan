class_name TalentRules
extends RefCounted
## Règles des talents et de la progression : points par niveau, paliers, validation d'un
## ensemble de talents reçu (sauvegarde ou réseau), expérience gagnée en fin de partie.
##
## Un talent de palier t n'est permis que si la branche compte déjà au moins
## talent_tiers[t - 1] points dans des talents de paliers inférieurs. Hors tronc commun, une
## seule branche (la spécialisation) peut recevoir des points ; on en change en les retirant.

const MAX_ENTRIES := 64


## 1 point de talent par niveau.
static func points(level: int) -> int:
	return maxi(0, level)


## Expérience pour passer du niveau `level` au suivant.
static func xp_to_next(data: GameData, level: int) -> int:
	var p := data.progression
	return roundi(float(p["xp_base"]) * pow(float(p["xp_growth"]), level - 1))


## Niveau atteint avec `xp` points d'expérience (1 au départ, plafonné à max_level).
static func level_for(data: GameData, xp: int) -> int:
	var level := 1
	var left := xp
	while level < int(data.progression["max_level"]) and left >= xp_to_next(data, level):
		left -= xp_to_next(data, level)
		level += 1
	return level


## Expérience déjà acquise dans le niveau en cours : [acquise, nécessaire] ([0, 0] au maximum).
static func level_progress(data: GameData, xp: int) -> Array:
	var level := level_for(data, xp)
	if level >= int(data.progression["max_level"]):
		return [0, 0]
	var left := xp
	for l in range(1, level):
		left -= xp_to_next(data, l)
	return [left, xp_to_next(data, level)]


## Expérience d'une partie : victoire = xp_per_wave × vagues × xp de la difficulté, plus
## win_bonus de cette somme ; défaite = vagues passées × xp_per_wave × part du palier atteint.
static func match_xp(data: GameData, won: bool, waves_passed: int, total_waves: int, difficulty: int) -> int:
	var d: Dictionary = data.difficulties[clampi(difficulty, 0, data.difficulties.size() - 1)]
	var per_wave := float(data.progression["xp_per_wave"]) * float(d["xp"])
	var total := maxi(1, total_waves)
	if won:
		return roundi(per_wave * total * (1.0 + float(data.progression["win_bonus"])))
	var passed := clampi(waves_passed, 0, total)
	return floori(per_wave * passed * defeat_rate(data, float(passed) / total))


## Part de l'expérience par vague gardée après une défaite, selon la progression (0 à 1) :
## palier par palier, de defeat_rate_min à defeat_rate_max.
static func defeat_rate(data: GameData, progress: float) -> float:
	var p := data.progression
	var steps := int(p["defeat_steps"])
	var step := clampi(floori(progress * steps), 0, steps - 1)
	if steps <= 1:
		return float(p["defeat_rate_max"])
	return lerpf(float(p["defeat_rate_min"]), float(p["defeat_rate_max"]), float(step) / (steps - 1))


## Talents d'un bâtisseur : id -> [index de branche, définition].
static func defs(data: GameData, builder: int) -> Dictionary:
	var out := {}
	if builder < 0 or builder >= data.builders.size():
		return out
	var branches: Array = data.builders[builder]["branches"]
	for i in branches.size():
		for t in branches[i]["talents"]:
			out[t["id"]] = [i, t]
	return out


static func spent(talents: Dictionary) -> int:
	var total := 0
	for id in talents:
		total += int(talents[id])
	return total


## Vérifie un ensemble de talents reçu tel quel. Renvoie {id: rang} ou null au moindre défaut
## (talent inconnu, rang hors limites, trop de points, palier non atteint).
static func validate(data: GameData, builder: int, raw: Variant, available: int) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY or raw.size() > MAX_ENTRIES:
		return null
	var all := defs(data, builder)
	var out := {}
	for key in raw:
		if typeof(key) != TYPE_STRING or not all.has(key):
			return null
		var rank = Check.as_int(raw[key], 1, int(all[key][1]["max_rank"]))
		if rank == null:
			return null
		out[key] = rank
	if spent(out) > available or not tiers_ok(data, out, all) or specs_used(data, builder, out).size() > 1:
		return null
	if available < max_points(data) and out.keys().any(func(id: String) -> bool: return all[id][1]["ultimate"]):
		return null  # talent ultime avant le niveau maximum
	return out


## Points de talent au niveau maximum (le talent ultime n'est permis qu'à ce niveau).
static func max_points(data: GameData) -> int:
	return points(int(data.progression["max_level"]))


## Spécialisations (index de branche hors tronc) qui ont au moins un point.
static func specs_used(data: GameData, builder: int, talents: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if builder < 0 or builder >= data.builders.size():
		return out
	var branches: Array = data.builders[builder]["branches"]
	var all := defs(data, builder)
	for id in talents:
		var i: int = all[id][0] if all.has(id) else -1
		if i >= 0 and not branches[i]["trunk"] and not out.has(i) and int(talents[id]) > 0:
			out.append(i)
	return out


static func tiers_ok(data: GameData, talents: Dictionary, all: Dictionary) -> bool:
	for id in talents:
		var branch: int = all[id][0]
		var tier: int = all[id][1]["tier"]
		var below := 0
		for other in talents:
			if all[other][0] == branch and int(all[other][1]["tier"]) < tier:
				below += int(talents[other])
		if below < data.talent_tiers[tier - 1]:
			return false
	return true


## Raison d'un refus d'ajouter un rang au talent `id` ("" si c'est permis).
static func add_refusal(data: GameData, builder: int, talents: Dictionary, id: String, available: int) -> String:
	var all := defs(data, builder)
	if not all.has(id):
		return "Talent inconnu"
	var def: Dictionary = all[id][1]
	var branch: int = all[id][0]
	var branches: Array = data.builders[builder]["branches"]
	for used in specs_used(data, builder, talents):
		if used != branch and not branches[branch]["trunk"]:
			return "Spécialisation déjà choisie : %s (retire ses points pour en changer)" % branches[used]["name"]
	if int(talents.get(id, 0)) >= int(def["max_rank"]):
		return "Rang maximum atteint"
	if def["ultimate"] and available < max_points(data):
		return "Talent ultime : seulement au niveau %d" % int(data.progression["max_level"])
	if spent(talents) >= available:
		return "Plus de point disponible : gagne des niveaux avec cette classe"
	var next := talents.duplicate()
	next[id] = int(talents.get(id, 0)) + 1
	if not tiers_ok(data, next, all):
		return "Il faut %d points dans les paliers précédents de cette branche" % data.talent_tiers[int(def["tier"]) - 1]
	return ""


## Raison d'un refus de retirer un rang ("" si c'est permis : les paliers supérieurs restent valables).
static func remove_refusal(data: GameData, builder: int, talents: Dictionary, id: String) -> String:
	if int(talents.get(id, 0)) <= 0:
		return "Aucun point dans ce talent"
	var next := talents.duplicate()
	next[id] = int(next[id]) - 1
	if next[id] == 0:
		next.erase(id)
	if not tiers_ok(data, next, defs(data, builder)):
		return "Des talents plus haut dans la branche en dépendent"
	return ""

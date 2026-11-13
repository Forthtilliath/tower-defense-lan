extends RefCounted
## Répartition des points de talent d'un joueur automatique, comme un joueur qui joue sa
## spécialisation : ses premiers points ouvrent le palier 2 de sa branche (sa tourelle signature),
## puis il alterne avec le tronc (dégâts et cadence de ses tourelles), remonte sa branche palier
## par palier, et prend son ultime (son pouvoir) au niveau maximum.

## Clés d'un talent qui en font un bonus chiffré direct (pris avant les mécaniques).
const DIRECT := ["damage", "rate", "aura", "cc", "bounty", "interest", "interest_cap", "start_gold", "build_cost",
	"sell_bonus", "team_bounty", "early_bonus", "clean_gold", "raze_charges", "tile_charges"]


## Branches de spécialisation d'une classe (hors tronc), dans l'ordre des données.
static func spec_branches(gd: GameData, builder: int) -> Array:
	return gd.builders[builder]["branches"].filter(func(br: Dictionary) -> bool: return not br["trunk"])


static func trunk(gd: GameData, builder: int) -> Dictionary:
	for br in gd.builders[builder]["branches"]:
		if br["trunk"]:
			return br
	return {}


## Talents d'un bot de ce niveau jouant la spec-ième spécialisation.
static func plan(gd: GameData, builder: int, level: int, spec := 0) -> Dictionary:
	var points := TalentRules.points(level)
	var chosen: Dictionary = spec_branches(gd, builder)[spec]
	var root := trunk(gd, builder)
	var talents := {}
	# [branche, palier, points au plus, débloquages seulement]
	var steps := [
		[chosen, 1, 3, false], [chosen, 2, 99, true], [root, 1, 3, false], [chosen, 1, 99, false],
		[chosen, 2, 99, false], [root, 1, 99, false], [chosen, 3, 99, false], [root, 2, 99, false],
		[chosen, 4, 99, false], [chosen, 5, 99, false],
	]
	for step in steps:
		_fill(gd, builder, talents, step[0], step[1], step[2], points, step[3])
	_take_ultimate(gd, builder, talents, chosen, points)
	return talents


## Place jusqu'à `budget` points dans les talents d'un palier d'une branche, par priorité
## (débloquer une tourelle, bonus directs, mécaniques, portée), tant que les règles l'acceptent.
static func _fill(gd: GameData, builder: int, talents: Dictionary, branch: Dictionary, tier: int, budget: int, points: int, unlock_only: bool) -> void:
	var list: Array = branch["talents"].filter(func(t: Dictionary) -> bool: return int(t["tier"]) == tier and not t["ultimate"])
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _priority(a) < _priority(b))
	var spent := 0
	for t in list:
		if unlock_only and String(t["unlock"]) == "":
			continue
		while spent < budget and TalentRules.add_refusal(gd, builder, talents, t["id"], points) == "":
			talents[t["id"]] = int(talents.get(t["id"], 0)) + 1
			spent += 1


static func _priority(t: Dictionary) -> int:
	if String(t["unlock"]) != "":
		return 0
	for key in DIRECT:
		if float(t.get(key, 0.0)) > 0.0:
			return 1
	if not t["grant"].is_empty() or t["imbue_all"] or float(t.get("floors", 0.0)) > 0.0:
		return 2
	return 3


## Au niveau maximum, comme un joueur, il sacrifie un rang du tronc pour prendre l'ultime (son
## pouvoir) si ses points ne suffisent pas à tout remplir.
static func _take_ultimate(gd: GameData, builder: int, talents: Dictionary, spec: Dictionary, points: int) -> void:
	var ultimate := ""
	for t in spec["talents"]:
		if t["ultimate"]:
			ultimate = t["id"]
	if ultimate == "" or talents.has(ultimate) or points < TalentRules.max_points(gd):
		return
	if TalentRules.add_refusal(gd, builder, talents, ultimate, points) == "":
		talents[ultimate] = 1
		return
	var root: Array = trunk(gd, builder)["talents"].duplicate()
	root.reverse()
	for t in root:
		if int(talents.get(t["id"], 0)) > 0 and TalentRules.remove_refusal(gd, builder, talents, t["id"]) == "":
			talents[t["id"]] -= 1
			if talents[t["id"]] == 0:
				talents.erase(t["id"])
			if TalentRules.add_refusal(gd, builder, talents, ultimate, points) == "":
				talents[ultimate] = 1
			return

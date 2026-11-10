class_name PlayerKit
extends RefCounted
## Ce qu'un joueur apporte en partie : sa classe et ses talents (déjà validés).
## Tourelles constructibles (tronc commun + celles de la classe + débloquées par la spécialisation),
## bonus par tourelle (classe × talents), économie (primes, intérêts, or de départ, coûts, revente, dons).

const STATS := ["damage", "rate", "range", "cc", "aura"]
const ECONOMY := ["bounty", "interest", "interest_cap", "start_gold", "build_cost", "sell_bonus", "gift_bonus"]
## Plafonds : réduction des prix, part de revente, part d'un don reçue par l'allié.
const MAX_DISCOUNT := 0.5
const MAX_SELL := 0.9
const MAX_GIFT := 1.0

var builder := 0
var talents := {}  # id du talent -> rang
var towers := {}  # id de tourelle -> true
## Branche de spécialisation choisie (index dans les branches de la classe), -1 : aucune encore.
var spec := -1
var bounty := 1.0
var interest := 0.0
var interest_cap := 0
var start_gold := 0
var build_cost := 0.0
var sell_bonus := 0.0
var gift_bonus := 0.0
var _base := {}  # multiplicateurs de la classe
var _bonus_towers := {}  # tourelles visées par le bonus de classe (vide : toutes)
var _all := {}  # bonus des talents sur toutes les tourelles
var _per := {}  # id de tourelle -> bonus des talents qui la visent


static func make(data: GameData, p_builder: int, p_talents := {}) -> PlayerKit:
	var k := PlayerKit.new()
	k.builder = clampi(p_builder, 0, data.builders.size() - 1)
	k.talents = p_talents
	var b: Dictionary = data.builders[k.builder]
	for id in data.common_towers + b["towers"]:
		k.towers[id] = true
	for key in STATS:
		k._base[key] = float(b[key])
	for id in b["bonus_towers"]:
		k._bonus_towers[id] = true
	k.bounty = float(b["bounty"])
	k.interest = float(b["interest"])
	k.interest_cap = int(b["interest_cap"])
	k.start_gold = int(b["start_gold"])
	var branches: Array = b["branches"]
	for i in branches.size():
		for t in branches[i]["talents"]:
			var rank := int(p_talents.get(t["id"], 0))
			if rank > 0:
				k._apply(t, rank)
				if not branches[i]["trunk"]:
					k.spec = i
	return k


func _apply(t: Dictionary, rank: int) -> void:
	if t["unlock"] != "":
		towers[t["unlock"]] = true
	bounty += float(t["bounty"]) * rank
	interest += float(t["interest"]) * rank
	interest_cap += int(t["interest_cap"]) * rank
	start_gold += int(t["start_gold"]) * rank
	build_cost += float(t["build_cost"]) * rank
	sell_bonus += float(t["sell_bonus"]) * rank
	gift_bonus += float(t["gift_bonus"]) * rank
	for s in STATS:
		var v := float(t[s]) * rank
		if v <= 0.0:
			continue
		if t["towers"].is_empty():
			_all[s] = float(_all.get(s, 0.0)) + v
		else:
			for id in t["towers"]:
				if not _per.has(id):
					_per[id] = {}
				_per[id][s] = float(_per[id].get(s, 0.0)) + v


func allows(type: String) -> bool:
	return towers.has(type)


## Nom de la spécialisation choisie ("" tant qu'aucun point n'est placé dans une spécialisation).
func spec_name(data: GameData) -> String:
	return data.builders[builder]["branches"][spec]["name"] if spec >= 0 else ""


## « Arcaniste », ou « Arcaniste · Mage de feu » une fois la spécialisation choisie.
func title(data: GameData) -> String:
	var name: String = data.builders[builder]["name"]
	return name if spec < 0 else "%s · %s" % [name, spec_name(data)]


## Multiplicateur d'une statistique pour une tourelle : classe × (1 + bonus des talents).
func mult(type: String, stat: String) -> float:
	var extra := float(_all.get(stat, 0.0)) + float(_per.get(type, {}).get(stat, 0.0))
	var base := float(_base.get(stat, 1.0)) if _bonus_towers.is_empty() or _bonus_towers.has(type) else 1.0
	return base * (1.0 + extra)


func boost(stats: Dictionary, type: String) -> void:
	stats["range"] *= mult(type, "range")
	stats["rate"] *= mult(type, "rate")
	GameData.scale_damage(stats, mult(type, "damage"))
	GameData.scale_control(stats, mult(type, "cc"))
	var aura := mult(type, "aura")
	for key in ["aura_rate", "aura_damage", "aura_cc"]:
		stats[key] *= aura


## Intérêts : [taux, plafond], bonus de la classe et des talents compris.
func interest_rule(data: GameData) -> Array:
	return [float(data.player["interest"]) + interest, int(data.player["interest_cap"]) + interest_cap]


## Prix payé pour une construction ou une amélioration affichée à `base` or.
func cost(base: int) -> int:
	return maxi(1, roundi(base * (1.0 - minf(build_cost, MAX_DISCOUNT))))


## Total payé pour une tourelle arrivée au niveau `level`, réductions comprises.
func invested(data: GameData, type: String, level: int) -> int:
	var total := 0
	var levels := data.tower_levels(type)
	for i in mini(level + 1, levels.size()):
		total += cost(int(levels[i]["cost"]))
	return total


## Part de l'or investi rendue à la revente.
func sell_ratio() -> float:
	return minf(MAX_SELL, SimMatch.SELL_RATIO + sell_bonus)


## Part d'un don reçue par l'allié.
func gift_ratio(data: GameData) -> float:
	return minf(MAX_GIFT, float(data.player["gift_ratio"]) + gift_bonus)

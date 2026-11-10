class_name PlayerKit
extends RefCounted
## Ce qu'un joueur apporte en partie : son bâtisseur et ses talents (déjà validés).
## Tourelles constructibles (de base + débloquées), bonus par tourelle (bâtisseur × talents),
## économie (part des primes, intérêts, or de départ).

const STATS := ["damage", "rate", "range", "cc", "aura"]

var builder := 0
var talents := {}  # id du talent -> rang
var towers := {}  # id de tourelle -> true
var bounty := 1.0
var interest := 0.0
var interest_cap := 0
var start_gold := 0
var _base := {}  # multiplicateurs du bâtisseur
var _all := {}  # bonus des talents sur toutes les tourelles
var _per := {}  # id de tourelle -> bonus des talents qui la visent


static func make(data: GameData, p_builder: int, p_talents := {}) -> PlayerKit:
	var k := PlayerKit.new()
	k.builder = clampi(p_builder, 0, data.builders.size() - 1)
	k.talents = p_talents
	var b: Dictionary = data.builders[k.builder]
	for id in b["towers"]:
		k.towers[id] = true
	for key in ["damage", "rate", "range", "cc"]:
		k._base[key] = float(b[key])
	k.bounty = float(b["bounty"])
	k.interest = float(b["interest"])
	k.interest_cap = int(b["interest_cap"])
	for branch in b["branches"]:
		for t in branch["talents"]:
			var rank := int(p_talents.get(t["id"], 0))
			if rank > 0:
				k._apply(t, rank)
	return k


func _apply(t: Dictionary, rank: int) -> void:
	if t["unlock"] != "":
		towers[t["unlock"]] = true
	bounty += float(t["bounty"]) * rank
	interest += float(t["interest"]) * rank
	interest_cap += int(t["interest_cap"]) * rank
	start_gold += int(t["start_gold"]) * rank
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


## Multiplicateur d'une statistique pour une tourelle : bâtisseur × (1 + bonus des talents).
func mult(type: String, stat: String) -> float:
	var extra := float(_all.get(stat, 0.0)) + float(_per.get(type, {}).get(stat, 0.0))
	return float(_base.get(stat, 1.0)) * (1.0 + extra)


func boost(stats: Dictionary, type: String) -> void:
	stats["range"] *= mult(type, "range")
	stats["rate"] *= mult(type, "rate")
	GameData.scale_damage(stats, mult(type, "damage"))
	GameData.scale_control(stats, mult(type, "cc"))
	var aura := mult(type, "aura")
	for key in ["aura_rate", "aura_damage", "aura_cc"]:
		stats[key] *= aura


## Intérêts : [taux, plafond], bonus du bâtisseur et des talents compris.
func interest_rule(data: GameData) -> Array:
	return [float(data.player["interest"]) + interest, int(data.player["interest_cap"]) + interest_cap]

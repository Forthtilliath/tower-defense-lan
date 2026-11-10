extends "res://tests/test_base.gd"
## Talents et progression : niveaux, expérience, validation des talents (réseau, sauvegarde),
## effets sur les tourelles et l'économie, relecture du fichier de progression.


func _arcanist(gd: GameData) -> int:
	for i in gd.builders.size():
		if gd.builders[i]["id"] == "arcanist":
			return i
	return -1


func test_levels_and_match_xp() -> void:
	var gd := load_data()
	check(TalentRules.level_for(gd, 0) == 1 and TalentRules.level_for(gd, 99) == 1, "niveau 1 au départ")
	check(TalentRules.level_for(gd, 100) == 2 and TalentRules.level_for(gd, 220) == 3, "100 puis 120 XP")
	check(TalentRules.level_for(gd, 100000000) == 15, "plafonné au niveau 15")
	check(TalentRules.level_progress(gd, 150) == [50, 120], "50 / 120 XP dans le niveau 2")
	check(TalentRules.match_xp(gd, true, 20, 20, 1) == 250, "victoire en Normal : 10 XP par vague + 25 %")
	check(TalentRules.match_xp(gd, true, 20, 20, 3) == 400, "Cauchemar : x1,6")
	check(TalentRules.match_xp(gd, false, 2, 20, 1) == 2, "défaite au 1er palier : 10 % par vague")
	check(TalentRules.match_xp(gd, false, 5, 20, 1) == 17, "2e palier dès 25 % : 35 % par vague")
	check(TalentRules.match_xp(gd, false, 10, 20, 1) == 60, "3e palier à mi-partie : 60 % par vague")
	check(TalentRules.match_xp(gd, false, 19, 20, 1) == 161, "dernier palier : 85 % par vague")
	check(TalentRules.match_xp(gd, false, 0, 15, 1) == 0, "défaite immédiate : rien")


func test_validation_of_received_talents() -> void:
	var gd := load_data()
	var a := _arcanist(gd)
	check(TalentRules.validate(gd, a, {"ar_conductive": 2, "ar_tesla": 1}, 3) != null, "palier 2 atteint avec 2 points")
	check(TalentRules.validate(gd, a, {"ar_conductive": 1, "ar_tesla": 1}, 5) == null, "palier 2 non atteint")
	check(TalentRules.validate(gd, a, {"ar_conductive": 3}, 2) == null, "plus de points que le niveau")
	check(TalentRules.validate(gd, a, {"ar_conductive": 4}, 10) == null, "rang au-delà du maximum")
	check(TalentRules.validate(gd, a, {"va_powder": 1}, 10) == null, "talent d'une autre classe")
	check(TalentRules.validate(gd, a, {"ar_conductive": 1.5}, 10) == null, "rang non entier")
	check(TalentRules.validate(gd, a, {1: 1}, 10) == null, "clé non texte")
	check(TalentRules.validate(gd, a, "texte", 10) == null, "pas un dictionnaire")
	check(TalentRules.validate(gd, a, {}, 0) == {}, "aucun talent : valable")


func test_add_and_remove_rules() -> void:
	var gd := load_data()
	var a := _arcanist(gd)
	check(TalentRules.add_refusal(gd, a, {}, "ar_tesla", 5).contains("paliers"), "palier verrouillé")
	check(TalentRules.add_refusal(gd, a, {"ar_conductive": 1}, "ar_conductive", 1).contains("point"), "plus de point")
	var built := {"ar_conductive": 2, "ar_tesla": 1}
	check(TalentRules.remove_refusal(gd, a, built, "ar_conductive").contains("dépendent"), "retrait qui casserait le palier refusé")
	check(TalentRules.remove_refusal(gd, a, built, "ar_tesla") == "", "retrait du talent du haut permis")


func test_kit_bonuses_and_economy() -> void:
	var gd := load_data()
	var goblin := -1
	for i in gd.builders.size():
		if gd.builders[i]["id"] == "goblin":
			goblin = i
	var kit := PlayerKit.make(gd, goblin, {"go_greed": 3, "go_stocking": 1, "go_chest": 1, "go_nest": 2})
	check(is_equal_approx(kit.bounty, 1.25 + 0.15), "primes : classe + Âpreté")
	var rule := kit.interest_rule(gd)
	check(is_equal_approx(rule[0], 0.07) and rule[1] == 70, "intérêts : 4 + 2 + 1 %%, plafond 30 + 20 + 20 : %s" % str(rule))
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "G", 0, goblin, kit.talents]])
	check(sim.players[1]["gold"] == 150 + 80, "or de départ : +2 x 40")
	var gunner := PlayerKit.make(gd, 1, {"gu_drill": 2, "gu_banner": 1, "gu_drum": 1, "gu_fanfare": 1})
	var banner := gd.tower_stats("banner", 0, -1, gunner)
	check(is_equal_approx(banner["aura_damage"], 0.12 * 1.15), "Fanfare renforce l'aura : %f" % banner["aura_damage"])
	var crossbow := gd.tower_stats("crossbow", 0, -1, gunner)
	check(is_equal_approx(crossbow["rate"], 1.2 * 1.08), "Discipline : +4 %% de cadence par rang : %f" % crossbow["rate"])


func test_progress_file_validation() -> void:
	var gd := load_data()
	var good := ProgressFile.serialize(gd, {"arcanist": {"xp": 300, "talents": {"ar_conductive": 2, "ar_tesla": 1}}}, 2)
	var parsed = ProgressFile.parse(gd, good)
	check(parsed != null and parsed[0]["arcanist"]["xp"] == 300 and parsed[1] == 2, "fichier relu")
	check(parsed != null and parsed[0]["arcanist"]["talents"].size() == 2, "talents relus")
	var bad := [
		"pas du json", "[]", "{\"v\": 2, \"classes\": {}}", "{\"v\": 1}",
		"{\"v\": 1, \"classes\": {\"arcanist\": {\"xp\": -5, \"talents\": {}}}}",
		"{\"v\": 1, \"classes\": {\"arcanist\": {\"xp\": 1.5, \"talents\": {}}}}",
		"{\"v\": 1, \"classes\": {\"arcanist\": {\"xp\": 10}}}",
		"{\"v\": 1, \"classes\": {\"Arc Niste\": {\"xp\": 10, \"talents\": {}}}}",
		"{\"v\": 1, \"last\": 3, \"classes\": {}}",
	]
	for text in bad:
		check(ProgressFile.parse(gd, text) == null, "fichier rejeté : " + text)
	var old = ProgressFile.parse(gd, "{\"v\": 1, \"classes\": {\"retiree\": {\"xp\": 5, \"talents\": {}}, \"arcanist\": {\"xp\": 50, \"talents\": {\"ar_conductive\": 3}}}}")
	check(old != null and not old[0].has("retiree"), "classe inconnue ignorée")
	check(old != null and old[0]["arcanist"]["xp"] == 50 and old[0]["arcanist"]["talents"].is_empty(), "talents trop nombreux pour le niveau : remis à zéro, XP gardée")


func test_tree_data_validation() -> void:
	var text := FileAccess.get_file_as_string(GameData.DEFAULT_PATH)
	var cases := {
		"tourelle à débloquer inconnue": ["\"unlock\": \"tesla\" },", "\"unlock\": \"laser\" },", "débloquer"],
		"palier inexistant": ["\"tier\": 4, \"max_rank\": 2, \"towers\": [\"cannon\", \"ballista\", \"mortar\"]", "\"tier\": 9, \"max_rank\": 2, \"towers\": [\"cannon\", \"ballista\", \"mortar\"]", "tier"],
		"talent sans effet": ["\"description\": \"+1 % d'intérêts.\", \"tier\": 2, \"interest\": 0.01", "\"description\": \"rien\", \"tier\": 2", "ne fait rien"],
		"paliers décroissants": ["\"talent_tiers\": [0, 2, 4, 5]", "\"talent_tiers\": [0, 4, 2, 5]", "talent_tiers"],
	}
	for label in cases:
		var c: Array = cases[label]
		check(text.contains(c[0]), "motif introuvable : " + label)
		var gd := GameData.from_text(text.replace(c[0], c[1]))
		check(not gd.is_valid() and gd.error.contains(c[2]), "%s refusé : %s" % [label, gd.error])

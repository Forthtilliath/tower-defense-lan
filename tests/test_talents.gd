extends "res://tests/test_base.gd"
## Talents et progression : niveaux, expérience, validation des talents (réseau, sauvegarde),
## spécialisation exclusive, effets sur les tourelles et l'économie, relecture du fichier de
## progression (et migration des anciennes classes).


func _builder(gd: GameData, id: String) -> int:
	for i in gd.builders.size():
		if gd.builders[i]["id"] == id:
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


## Chaque classe : un tronc de 5 points et 4 spécialisations de 10 points (niveau 15 = 15 points).
func test_every_class_has_a_trunk_and_four_specs() -> void:
	var gd := load_data()
	for b in gd.builders:
		var trunk := 0
		var specs := 0
		for branch in b["branches"]:
			var points := 0
			for t in branch["talents"]:
				points += int(t["max_rank"])
			if branch["trunk"]:
				trunk += 1
				check(points == 5, "%s : tronc de 5 points (%d)" % [b["id"], points])
			else:
				specs += 1
				check(points == 10, "%s / %s : 10 points (%d)" % [b["id"], branch["id"], points])
		check(trunk == 1 and specs == 4, "%s : 1 tronc et 4 spécialisations" % b["id"])


func test_validation_of_received_talents() -> void:
	var gd := load_data()
	var a := _builder(gd, "arcanist")
	check(TalentRules.validate(gd, a, {"ar_conductive": 2, "ar_pylon": 1}, 3) != null, "palier 2 atteint avec 2 points")
	check(TalentRules.validate(gd, a, {"ar_conductive": 1, "ar_pylon": 1}, 5) == null, "palier 2 non atteint")
	check(TalentRules.validate(gd, a, {"ar_conductive": 3}, 2) == null, "plus de points que le niveau")
	check(TalentRules.validate(gd, a, {"ar_conductive": 4}, 10) == null, "rang au-delà du maximum")
	check(TalentRules.validate(gd, a, {"gu_powder": 1}, 10) == null, "talent d'une autre classe")
	check(TalentRules.validate(gd, a, {"ar_conductive": 1.5}, 10) == null, "rang non entier")
	check(TalentRules.validate(gd, a, {1: 1}, 10) == null, "clé non texte")
	check(TalentRules.validate(gd, a, "texte", 10) == null, "pas un dictionnaire")
	check(TalentRules.validate(gd, a, {}, 0) == {}, "aucun talent : valable")
	check(TalentRules.validate(gd, a, {"ar_conductive": 1, "ar_embers": 1}, 10) == null, "deux spécialisations refusées")
	check(TalentRules.validate(gd, a, {"ar_focus": 3, "ar_flow": 2, "ar_embers": 1}, 10) != null, "tronc + une spécialisation")


func test_add_and_remove_rules() -> void:
	var gd := load_data()
	var a := _builder(gd, "arcanist")
	check(TalentRules.add_refusal(gd, a, {}, "ar_pylon", 5).contains("paliers"), "palier verrouillé")
	check(TalentRules.add_refusal(gd, a, {"ar_conductive": 1}, "ar_conductive", 1).contains("point"), "plus de point")
	check(TalentRules.add_refusal(gd, a, {"ar_conductive": 1}, "ar_embers", 5).contains("Mage de foudre"), "autre spécialisation fermée")
	check(TalentRules.add_refusal(gd, a, {"ar_conductive": 1}, "ar_focus", 5) == "", "le tronc reste ouvert")
	var built := {"ar_conductive": 2, "ar_pylon": 1}
	check(TalentRules.remove_refusal(gd, a, built, "ar_conductive").contains("dépendent"), "retrait qui casserait le palier refusé")
	check(TalentRules.remove_refusal(gd, a, built, "ar_pylon") == "", "retrait du talent du haut permis")


func test_kit_bonuses_and_economy() -> void:
	var gd := load_data()
	var goblin := _builder(gd, "goblin")
	var kit := PlayerKit.make(gd, goblin, {"go_thrift": 2, "go_stocking": 3, "go_chest": 1})
	check(is_equal_approx(kit.bounty, 1.15 + 0.06), "primes : classe + Pingrerie : %f" % kit.bounty)
	var rule := kit.interest_rule(gd)
	check(is_equal_approx(rule[0], 0.055) and rule[1] == 40, "intérêts : 4 + 1,5 %%, plafond 30 + 10 : %s" % str(rule))
	check(kit.spec_name(gd) == "Usurier" and kit.title(gd) == "Gobelin · Usurier", "spécialisation reconnue")
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "G", 0, goblin, {"go_purse": 2}]])
	check(sim.players[1]["gold"] == 150 + 40, "or de départ : +2 x 20")
	var support := _builder(gd, "support")
	var warlord := PlayerKit.make(gd, support, {"su_orders": 3, "su_drum": 1, "su_fanfare": 1})
	check(warlord.allows("drum") and not warlord.allows("banner"), "Tambour débloqué, Étendard pas encore")
	var drum := gd.tower_stats("drum", 0, -1, warlord)
	check(is_equal_approx(drum["aura_rate"], 0.12 * 1.15 * 1.08), "aura : classe +15 %%, Fanfare +8 %% : %f" % drum["aura_rate"])
	var crossbow := gd.tower_stats("crossbow", 0, -1, warlord)
	check(is_equal_approx(crossbow["damage"], 4 * 1.09), "Ordres : +3 %% de dégâts par rang : %f" % crossbow["damage"])


## Bâtisseur : tourelles du tronc commun seulement, prix réduits, revente bonifiée.
func test_mason_costs_and_refunds() -> void:
	var gd := load_data()
	var mason := _builder(gd, "mason")
	var plain := PlayerKit.make(gd, mason)
	check(plain.allows("cannon") and not plain.allows("ballista"), "tronc commun seulement")
	var architect := PlayerKit.make(gd, mason, {"bu_tools": 3, "bu_quote": 3})
	check(architect.cost(100) == 85, "−6 %% (Outils) −9 %% (Devis) : %d" % architect.cost(100))
	var scrapper := PlayerKit.make(gd, mason, {"bu_salvage": 3})
	check(is_equal_approx(scrapper.sell_ratio(), 0.79), "revente 70 + 9 %%")
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "B", 0, mason, {"bu_tools": 3, "bu_quote": 3}]])
	var start: int = sim.players[1]["gold"]
	check(start == 150 + 50, "+50 or de départ (classe)")
	var cell := 2 * sim.map.width + 2
	check(sim.apply_command(1, {"a": "build", "cell": cell, "tower": "crossbow"}) == "", "construction")
	check(sim.players[1]["gold"] == start - architect.cost(50), "prix réduit payé")
	check(sim.boards[0].towers[cell].invested == architect.cost(50), "investi = prix payé")


func test_patron_gifts_lose_less() -> void:
	var gd := load_data()
	var goblin := _builder(gd, "goblin")
	var patron := PlayerKit.make(gd, goblin, {"go_generous": 3})
	check(MatchActions.gift_received(gd, 100) == 50 and MatchActions.gift_received(gd, 100, patron) == 80, "don : 50 %% puis 80 %%")


func test_progress_file_validation() -> void:
	var gd := load_data()
	var good := ProgressFile.serialize(gd, {"arcanist": {"xp": 300, "talents": {"ar_conductive": 2, "ar_pylon": 1}}}, 1)
	var parsed = ProgressFile.parse(gd, good)
	check(parsed != null and parsed[0]["arcanist"]["xp"] == 300 and parsed[1] == 1, "fichier relu")
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


## Refonte des classes : l'expérience de l'Enchanteur passe au Support, ses talents sont remis à zéro ;
## Touche-à-tout et Éclaireur disparaissent ; les anciens talents des classes gardées sont remis à zéro.
func test_progress_file_migrates_old_classes() -> void:
	var gd := load_data()
	var text := "{\"v\": 1, \"last\": \"enchanter\", \"classes\": {\"enchanter\": {\"xp\": 400, \"talents\": {\"en_lure\": 1}}, \"versatile\": {\"xp\": 900, \"talents\": {}}, \"gunner\": {\"xp\": 300, \"talents\": {\"gu_banner\": 1}}}}"
	var parsed = ProgressFile.parse(gd, text)
	check(parsed != null, "ancien fichier accepté")
	if parsed == null:
		return
	check(parsed[0].has("support") and parsed[0]["support"]["xp"] == 400 and parsed[0]["support"]["talents"].is_empty(), "Enchanteur → Support, talents remis à zéro")
	check(not parsed[0].has("versatile") and not parsed[0].has("enchanter"), "anciennes classes retirées")
	check(parsed[0]["gunner"]["xp"] == 300 and parsed[0]["gunner"]["talents"].is_empty(), "Artilleur : XP gardée, anciens talents remis à zéro")
	check(parsed[1] == _builder(gd, "support"), "dernière classe : Support")
	var both = ProgressFile.parse(gd, "{\"v\": 1, \"classes\": {\"enchanter\": {\"xp\": 400, \"talents\": {}}, \"support\": {\"xp\": 10, \"talents\": {}}}}")
	check(both != null and both[0]["support"]["xp"] == 10, "un Support déjà présent n'est pas écrasé")


func test_tree_data_validation() -> void:
	var text := FileAccess.get_file_as_string(GameData.DEFAULT_PATH)
	var cases := {
		"tourelle à débloquer inconnue": ["\"unlock\": \"pylon\" },", "\"unlock\": \"laser\" },", "débloquer"],
		"palier inexistant": ["\"tier\": 4, \"max_rank\": 2, \"towers\": [\"cannon\", \"mortar\"]", "\"tier\": 9, \"max_rank\": 2, \"towers\": [\"cannon\", \"mortar\"]", "tier"],
		"talent sans effet": ["\"tier\": 1, \"max_rank\": 3, \"interest\": 0.005", "\"tier\": 1, \"max_rank\": 3", "ne fait rien"],
		"paliers décroissants": ["\"talent_tiers\": [0, 2, 4, 5]", "\"talent_tiers\": [0, 4, 2, 5]", "talent_tiers"],
		"deux troncs": ["\"description\": \"Intérêts.\", \"talents\"", "\"description\": \"Intérêts.\", \"trunk\": true, \"talents\"", "tronc"],
		"tronc commun inconnu": ["\"common_towers\": [\"crossbow\",", "\"common_towers\": [\"laser\",", "common_towers"],
		"tronc commun sans anti-aérien": ["\"common_towers\": [\"crossbow\", \"sentinel\", \"dart\", \"cannon\", \"frost\", \"tesla\", \"brazier\", \"salamander\", \"venom\", \"thorns\", \"gong\"]", "\"common_towers\": [\"cannon\", \"gong\"]", "l'air"],
	}
	for label in cases:
		var c: Array = cases[label]
		check(text.contains(c[0]), "motif introuvable : " + label)
		var gd := GameData.from_text(text.replace(c[0], c[1]))
		check(not gd.is_valid() and gd.error.contains(c[2]), "%s refusé : %s" % [label, gd.error])

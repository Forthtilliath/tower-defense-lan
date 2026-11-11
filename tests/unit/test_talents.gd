extends "res://tests/unit/test_base.gd"
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
	check(TalentRules.level_for(gd, 0) == 1 and TalentRules.level_for(gd, 199) == 1, "niveau 1 au départ")
	check(TalentRules.level_for(gd, 200) == 2 and TalentRules.level_for(gd, 420) == 3, "200 puis 220 XP")
	check(TalentRules.level_for(gd, 100000000) == 30, "plafonné au niveau 30")
	check(TalentRules.level_progress(gd, 250) == [50, 220], "50 / 220 XP dans le niveau 2")
	check(TalentRules.match_xp(gd, true, 20, 20, 1) == 250, "victoire en Normal : 10 XP par vague + 25 %")
	check(TalentRules.match_xp(gd, true, 20, 20, 3) == 500, "Cauchemar : x2")
	check(TalentRules.match_xp(gd, false, 2, 20, 1) == 2, "défaite au 1er palier : 10 % par vague")
	check(TalentRules.match_xp(gd, false, 5, 20, 1) == 17, "2e palier dès 25 % : 35 % par vague")
	check(TalentRules.match_xp(gd, false, 10, 20, 1) == 60, "3e palier à mi-partie : 60 % par vague")
	check(TalentRules.match_xp(gd, false, 19, 20, 1) == 161, "dernier palier : 85 % par vague")
	check(TalentRules.match_xp(gd, false, 0, 15, 1) == 0, "défaite immédiate : rien")


## Chaque classe : un tronc de 12 rangs sans ultime, et 4 spécialisations de 16 à 18 rangs plus
## un ultime d'un point qui donne un pouvoir (niveau 30 : de quoi remplir le tronc et presque toute
## la spécialisation).
func test_every_class_has_a_trunk_and_four_specs() -> void:
	var gd := load_data()
	for b in gd.builders:
		var trunk := 0
		var specs := 0
		for branch in b["branches"]:
			var points := 0
			var ultimates := []
			for t in branch["talents"]:
				if t["ultimate"]:
					ultimates.append(int(t["max_rank"]))
					check(MatchPowers.POWERS.has(t["power"]), "%s : l'ultime donne un pouvoir" % t["id"])
				else:
					points += int(t["max_rank"])
			if branch["trunk"]:
				trunk += 1
				check(points == 12 and ultimates.is_empty(), "%s : tronc de 12 rangs, sans ultime (%d)" % [b["id"], points])
			else:
				specs += 1
				check(points >= 16 and points <= 18, "%s / %s : 16 à 18 rangs (%d)" % [b["id"], branch["id"], points])
				check(ultimates == [1], "%s / %s : un ultime d'un point" % [b["id"], branch["id"]])
		check(trunk == 1 and specs == 4, "%s : 1 tronc et 4 spécialisations" % b["id"])


func test_ultimate_only_at_max_level() -> void:
	var gd := load_data()
	var a := _builder(gd, "arcanist")
	var full := {"ar_conduction": 3, "ar_stable": 3, "ar_pylon": 1, "ar_static": 3, "ar_railgun": 1, "ar_short": 3, "ar_surge": 3}
	var with_ult := full.duplicate()
	with_ult["ar_tempest"] = 1
	check(TalentRules.validate(gd, a, with_ult, 29) == null, "ultime refusé au niveau 29")
	check(TalentRules.validate(gd, a, with_ult, 30) != null, "ultime permis au niveau 30")
	check(TalentRules.add_refusal(gd, a, full, "ar_tempest", 29).contains("ultime"), "refus expliqué")
	check(TalentRules.add_refusal(gd, a, full, "ar_tempest", 30) == "", "ajout permis au niveau 30")
	var kit := PlayerKit.make(gd, a, with_ult)
	var base := int(gd.tower_levels("tesla")[0]["chain"])
	check(int(gd.tower_stats("tesla", 0, -1, kit)["chain"]) == base + 3, "Conduction : la Tesla rebondit 3 fois de plus")
	check(kit.power == "tempest", "l'ultime donne le pouvoir Tempête")
	var gunner := _builder(gd, "gunner")
	var sniper := PlayerKit.make(gd, gunner, {"gu_pierce": 2})
	check(int(gd.tower_stats("ballista", 0, -1, sniper)["pierce"]) == 2, "Carreau perçant : la Baliste traverse 2 monstres")
	var belt := PlayerKit.make(gd, gunner, {"gu_belt": 1})
	var shots := int(gd.tower_levels("gatling")[0]["multishot"])
	check(int(gd.tower_stats("gatling", 0, -1, belt)["multishot"]) == shots + 1, "Rafale : une cible de plus")
	check(int(gd.tower_stats("crossbow", 0, -1, belt)["multishot"]) == 1, "l'Arbalète n'est pas concernée")


func test_validation_of_received_talents() -> void:
	var gd := load_data()
	var a := _builder(gd, "arcanist")
	check(TalentRules.validate(gd, a, {"ar_conduction": 2, "ar_stable": 1, "ar_pylon": 1}, 4) != null, "palier 2 atteint avec 3 points")
	check(TalentRules.validate(gd, a, {"ar_conduction": 2, "ar_pylon": 1}, 5) == null, "palier 2 non atteint")
	check(TalentRules.validate(gd, a, {"ar_conduction": 3}, 2) == null, "plus de points que le niveau")
	check(TalentRules.validate(gd, a, {"ar_conduction": 4}, 10) == null, "rang au-delà du maximum")
	check(TalentRules.validate(gd, a, {"gu_powder": 1}, 10) == null, "talent d'une autre classe")
	check(TalentRules.validate(gd, a, {"ar_conduction": 1.5}, 10) == null, "rang non entier")
	check(TalentRules.validate(gd, a, {1: 1}, 10) == null, "clé non texte")
	check(TalentRules.validate(gd, a, "texte", 10) == null, "pas un dictionnaire")
	check(TalentRules.validate(gd, a, {}, 0) == {}, "aucun talent : valable")
	check(TalentRules.validate(gd, a, {"ar_conduction": 1, "ar_embers": 1}, 10) == null, "deux spécialisations refusées")
	check(TalentRules.validate(gd, a, {"ar_focus": 3, "ar_power": 1, "ar_embers": 1}, 10) != null, "tronc + une spécialisation")


func test_add_and_remove_rules() -> void:
	var gd := load_data()
	var a := _builder(gd, "arcanist")
	check(TalentRules.add_refusal(gd, a, {}, "ar_pylon", 5).contains("paliers"), "palier verrouillé")
	check(TalentRules.add_refusal(gd, a, {"ar_conduction": 1}, "ar_conduction", 1).contains("point"), "plus de point")
	check(TalentRules.add_refusal(gd, a, {"ar_conduction": 1}, "ar_embers", 5).contains("Mage de foudre"), "autre spécialisation fermée")
	check(TalentRules.add_refusal(gd, a, {"ar_conduction": 1}, "ar_focus", 5) == "", "le tronc reste ouvert")
	var built := {"ar_conduction": 3, "ar_pylon": 1}
	check(TalentRules.remove_refusal(gd, a, built, "ar_conduction").contains("dépendent"), "retrait qui casserait le palier refusé")
	check(TalentRules.remove_refusal(gd, a, built, "ar_pylon") == "", "retrait du talent du haut permis")


func test_kit_bonuses_and_economy() -> void:
	var gd := load_data()
	var goblin := _builder(gd, "goblin")
	var kit := PlayerKit.make(gd, goblin, {"go_greed": 2, "go_stocking": 3, "go_rate": 1})
	check(is_equal_approx(kit.bounty, 1.15 + 0.12), "primes : classe + Avarice : %f" % kit.bounty)
	var rule := kit.interest_rule(gd)
	check(is_equal_approx(rule[0], 0.05) and rule[1] == 60, "intérêts : 4 + 1 %%, plafond 30 + 30 : %s" % str(rule))
	check(kit.spec_name(gd) == "Usurier" and kit.title(gd) == "Gobelin · Usurier", "spécialisation reconnue")
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "G", 0, goblin, {"go_smuggle": 2}]])
	check(sim.players[1]["gold"] == 150 + 80, "or de départ : Contrebande 2 x 40")
	var support := _builder(gd, "support")
	var warlord := PlayerKit.make(gd, support, {"su_orders": 3, "su_drum": 1, "su_presence": 3})
	check(warlord.allows("drum") and not warlord.allows("banner"), "Tambour débloqué, Étendard pas encore")
	var drum := gd.tower_stats("drum", 0, -1, warlord)
	var base := float(gd.tower_levels("drum")[0]["aura_rate"])
	check(is_equal_approx(drum["aura_rate"], base * 1.15 * 1.18 + 0.15), "aura : classe +15 %%, Présence +18 %%, Ordres +0,15 : %f" % drum["aura_rate"])
	check(is_equal_approx(gd.tower_stats("crossbow", 0, -1, warlord)["damage"], 4.0), "l'Arbalète n'est pas une tourelle du Support")


## Héritage : chaque classe au niveau maximum donne son bonus aux autres (pas à elle-même).
func test_heritage_of_maxed_classes() -> void:
	var gd := load_data()
	var gunner := _builder(gd, "gunner")
	var goblin := _builder(gd, "goblin")
	var arcanist := _builder(gd, "arcanist")
	var heir := PlayerKit.make(gd, arcanist, {}, [gunner, goblin])
	check(heir.heritage == [gunner, goblin], "deux héritages")
	check(is_equal_approx(gd.tower_stats("crossbow", 0, -1, heir)["damage"], 4 * 1.2), "Artilleur hérité : +20 % sur l'Arbalète")
	check(heir.start_gold == 100 and is_equal_approx(heir.bounty, 1.15), "Gobelin hérité : or de départ et primes")
	var own := PlayerKit.make(gd, gunner, {}, [gunner])
	check(own.heritage.is_empty() and is_equal_approx(gd.tower_stats("crossbow", 0, -1, own)["damage"], 4 * 1.2), "pas d'héritage de sa propre classe")
	check(TalentRules.parse_heritage(gd, [3, 1]) == [1, 3], "héritage trié")
	for bad in [[1, 1], [99], ["x"], "tout", [0, 1, 2, 3, 4, 5, 0]]:
		check(TalentRules.parse_heritage(gd, bad) == null, "héritage refusé : %s" % str(bad))
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0, arcanist, {}, [goblin]]])
	check(sim.players[1]["gold"] == 150 + 100, "l'héritage passe dans la partie")


## Bâtisseur : tourelles du tronc commun seulement, prix réduits, revente bonifiée.
func test_mason_costs_and_refunds() -> void:
	var gd := load_data()
	var mason := _builder(gd, "mason")
	var plain := PlayerKit.make(gd, mason)
	check(plain.allows("cannon") and not plain.allows("ballista"), "tronc commun seulement")
	var architect := PlayerKit.make(gd, mason, {"ma_thrifty": 2})
	check(architect.cost(100) == 90, "−10 %% (Économe) : %d" % architect.cost(100))
	var scrapper := PlayerKit.make(gd, mason, {"ma_resale": 3})
	check(is_equal_approx(scrapper.sell_ratio(), 0.85), "revente 70 + 15 %%")
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "B", 0, mason, {"ma_thrifty": 2}]])
	var start: int = sim.players[1]["gold"]
	check(start == 150 + 50, "+50 or de départ (classe)")
	var cell := 2 * sim.map.width + 2
	check(sim.apply_command(1, {"a": "build", "cell": cell, "tower": "crossbow"}) == "", "construction")
	check(sim.players[1]["gold"] == start - architect.cost(50), "prix réduit payé")
	check(sim.boards[0].towers[cell].invested == architect.cost(50), "investi = prix payé")


func test_patron_gifts_lose_less() -> void:
	var gd := load_data()
	var goblin := _builder(gd, "goblin")
	var patron := PlayerKit.make(gd, goblin, {"go_generosity": 3})
	check(MatchActions.gift_received(gd, 100) == 50 and MatchActions.gift_received(gd, 100, patron) == 74, "don : 50 %% puis 74 %%")


func test_progress_file_validation() -> void:
	var gd := load_data()
	var good := ProgressFile.serialize(gd, "Forth", {"arcanist": {"xp": 700, "talents": {"ar_conduction": 2, "ar_stable": 1, "ar_pylon": 1}}}, 1)
	var parsed = ProgressFile.parse(gd, good)
	check(parsed != null and parsed[0]["arcanist"]["xp"] == 700 and parsed[1] == 1 and parsed[2] == "Forth", "fichier relu")
	check(parsed != null and parsed[0]["arcanist"]["talents"].size() == 3, "talents relus")
	var bad := [
		"pas du json", "[]", "{\"v\": 2, \"classes\": {}}", "{\"v\": 1}",
		"{\"v\": 1, \"classes\": {\"arcanist\": {\"xp\": -5, \"talents\": {}}}}",
		"{\"v\": 1, \"classes\": {\"arcanist\": {\"xp\": 1.5, \"talents\": {}}}}",
		"{\"v\": 1, \"classes\": {\"arcanist\": {\"xp\": 10}}}",
		"{\"v\": 1, \"classes\": {\"Arc Niste\": {\"xp\": 10, \"talents\": {}}}}",
		"{\"v\": 1, \"last\": 3, \"classes\": {}}",
		"{\"v\": 3, \"name\": \"Bob\", \"classes\": {}}",
		"{\"v\": 2, \"name\": \"\", \"classes\": {}}",
		"{\"v\": 2, \"name\": 12, \"classes\": {}}",
		"{\"v\": 2, \"name\": \"  Bob\", \"classes\": {}}",
		"{\"v\": 2, \"name\": \"abcdefghijklmnopqrstuvwxyz\", \"classes\": {}}",
	]
	for text in bad:
		check(ProgressFile.parse(gd, text) == null, "fichier rejeté : " + text)
	var old = ProgressFile.parse(gd, "{\"v\": 1, \"classes\": {\"retiree\": {\"xp\": 5, \"talents\": {}}, \"arcanist\": {\"xp\": 50, \"talents\": {\"ar_conduction\": 3}}}}")
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
		"talent sans effet": ["\"tier\": 1, \"max_rank\": 3, \"interest\": 0.01", "\"tier\": 1, \"max_rank\": 3", "ne fait rien"],
		"paliers décroissants": ["\"talent_tiers\": [0, 3, 7, 11, 15]", "\"talent_tiers\": [0, 7, 3, 11, 15]", "talent_tiers"],
		"deux troncs": ["\"description\": \"L'or qui dort rapporte.\", \"talents\"", "\"description\": \"L'or qui dort rapporte.\", \"trunk\": true, \"talents\"", "tronc"],
		"tronc commun inconnu": ["\"common_towers\": [\"crossbow\",", "\"common_towers\": [\"laser\",", "common_towers"],
		"tronc commun sans anti-aérien": ["\"common_towers\": [\"crossbow\", \"sentinel\", \"dart\", \"cannon\", \"frost\", \"tesla\", \"brazier\", \"salamander\", \"venom\", \"thorns\", \"gong\"]", "\"common_towers\": [\"cannon\", \"gong\"]", "l'air"],
	}
	for label in cases:
		var c: Array = cases[label]
		check(text.contains(c[0]), "motif introuvable : " + label)
		var gd := GameData.from_text(text.replace(c[0], c[1]))
		check(not gd.is_valid() and gd.error.contains(c[2]), "%s refusé : %s" % [label, gd.error])

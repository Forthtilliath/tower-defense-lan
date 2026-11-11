extends "res://tests/unit/test_base.gd"
## Données reçues par le réseau : instantanés, messages de salon, annonces LAN.


func _sim_and_view(mode: int) -> Array:
	var gd := load_data()
	var roster := [[1, "Hôte", 0], [7, "Invité", 1]]
	var sim := SimMatch.new(gd, 0, mode, roster)
	var view := ViewState.new(gd, sim.map, sim.boards.size())
	return [sim, view]


func test_host_snapshot_is_accepted() -> void:
	var pair := _sim_and_view(SimMatch.Mode.COOP)
	var sim: SimMatch = pair[0]
	var view: ViewState = pair[1]
	sim.apply_command(1, {"a": "build", "cell": 2 * sim.map.width + 2, "tower": "crossbow"})
	sim.launch_next_wave()
	for i in 60:
		sim.step(0.05)
	var snap := sim.snapshot()
	snap["speed"] = 1
	snap["iv"] = 0.1
	check(view.apply(snap), "instantané de l'hôte accepté")
	check(view.boards[0]["towers"].size() == 1, "tourelle reçue")
	check(not view.boards[0]["monsters"].is_empty(), "monstres reçus")
	check(view.players[7]["gold"] == sim.players[7]["gold"], "or du joueur")


func test_snapshot_survives_network_encoding() -> void:
	var pair := _sim_and_view(SimMatch.Mode.VERSUS)
	var sim: SimMatch = pair[0]
	var view: ViewState = pair[1]
	sim.launch_next_wave()
	for i in 40:
		sim.step(0.05)
	var bytes := var_to_bytes(sim.snapshot())
	check(view.apply(bytes_to_var(bytes)), "instantané encodé/décodé accepté")
	check(view.boards.size() == 2, "deux plateaux en versus")


func test_corrupted_snapshots_are_ignored() -> void:
	var pair := _sim_and_view(SimMatch.Mode.COOP)
	var sim: SimMatch = pair[0]
	var view: ViewState = pair[1]
	sim.apply_command(1, {"a": "build", "cell": 2 * sim.map.width + 2, "tower": "crossbow"})
	var good := sim.snapshot()
	check(view.apply(good), "base valide")
	var cases := {
		"tourelle sur la route": func(s): s["b"][0]["t"][0][0] = sim.map.width + 1,
		"niveau hors limites": func(s): s["b"][0]["t"][0][2] = 9,
		"or négatif": func(s): s["pl"][0][1] = -1,
		"trop de plateaux": func(s): s["b"].append(s["b"][0]),
		"résultat inconnu": func(s): s["res"] = "hack",
		"vies en texte": func(s): s["b"][0]["lives"] = "20",
		"appel de vague absent": func(s): s.erase("nx"),
		"achats en texte": func(s): s["tr"] = "oui",
		"pas un dictionnaire": func(s): s.clear(),
	}
	for label in cases:
		var bad: Dictionary = good.duplicate(true)
		cases[label].call(bad)
		check(not view.apply(bad), "refus attendu : " + label)
	check(view.boards[0]["towers"].size() == 1, "l'état précédent est conservé")


## Un projectile transmet la tourelle qui l'a tiré (son aspect) ; un index inconnu est refusé.
func test_projectiles_carry_their_tower() -> void:
	var pair := _sim_and_view(SimMatch.Mode.COOP)
	var sim: SimMatch = pair[0]
	var view: ViewState = pair[1]
	var cannon := sim.data.tower_order.find("cannon")
	var snap := sim.snapshot()
	snap["b"][0]["p"] = [[3, 1.5, 1.5, cannon]]
	check(view.apply(snap), "projectile accepté")
	check(view.boards[0]["proj"][3]["kind"] == cannon, "tourelle du projectile reçue")
	for bad_kind in [-1, sim.data.tower_order.size(), "canon"]:
		var bad := sim.snapshot()
		bad["b"][0]["p"] = [[3, 1.5, 1.5, bad_kind]]
		check(not view.apply(bad), "tourelle de projectile refusée : %s" % str(bad_kind))
	var short := sim.snapshot()
	short["b"][0]["p"] = [[3, 1.5, 1.5]]
	check(not view.apply(short), "projectile sans tourelle refusé")


func test_lobby_payloads() -> void:
	var gd := load_data()
	var talents := {"ar_conduction": 2, "ar_stable": 1, "ar_pylon": 1}
	var good := {"players": [[1, "Hôte", 0, 0, 1, 1, {}, []], [4, "Bob", 1, 1, 3, 5, talents, [4, 0]]], "mode": 1, "map": 8, "rhythm": 1, "launch": 1, "heritage": 1}
	var ok = NetPayloads.parse_lobby(good, gd, 2, 4)
	check(ok != null and ok["players"].size() == 2 and ok["rhythm"] == 1 and ok["launch"] == 1, "salon valide")
	check(ok != null and ok["heritage"] == SimMatch.Heritage.OFF, "héritage désactivé reçu")
	check(ok != null and ok["players"][4]["builder"] == 1 and ok["players"][4]["vote"] == 3, "bâtisseur et vote reçus")
	check(ok != null and ok["players"][4]["level"] == 5 and ok["players"][4]["talents"] == talents, "niveau et talents reçus")
	check(ok != null and ok["players"][4]["heritage"] == [0, 4], "héritage reçu (trié)")
	var cases := {
		"héritage d'une classe inconnue": func(d): d["players"][1][7] = [9],
		"héritage en double": func(d): d["players"][1][7] = [0, 0],
		"héritage qui n'est pas une liste": func(d): d["players"][1][7] = "tout",
		"héritage absent": func(d): d["players"][1].remove_at(7),
		"niveau hors limites": func(d): d["players"][1][5] = 99,
		"plus de points que le niveau": func(d): d["players"][1][5] = 2,
		"talent inconnu": func(d): d["players"][1][6] = {"triche": 1},
		"talent d'une autre classe": func(d): d["players"][1][6] = {"gu_powder": 1},
		"palier non atteint": func(d): d["players"][1][6] = {"ar_pylon": 1},
		"rang trop élevé": func(d): d["players"][1][6] = {"ar_conduction": 9},
		"deux spécialisations": func(d): d["players"][1][6] = {"ar_conduction": 1, "ar_embers": 1},
		"talents absents": func(d): d["players"][1].remove_at(6),
		"sans hôte": func(d): d["players"].remove_at(0),
		"id en double": func(d): d["players"][1][0] = 1,
		"pseudo vide": func(d): d["players"][0][1] = "",
		"mode inconnu": func(d): d["mode"] = 5,
		"carte inconnue": func(d): d["map"] = 99,
		"rythme inconnu": func(d): d["rhythm"] = 2,
		"lancement absent": func(d): d.erase("launch"),
		"option d'héritage absente": func(d): d.erase("heritage"),
		"option d'héritage inconnue": func(d): d["heritage"] = 2,
		"couleur hors limites": func(d): d["players"][0][2] = 9,
		"bâtisseur inconnu": func(d): d["players"][1][3] = 9,
		"vote hors limites": func(d): d["players"][1][4] = 4,
		"vote absent": func(d): d["players"][1].remove_at(4),
	}
	for label in cases:
		var bad: Dictionary = good.duplicate(true)
		cases[label].call(bad)
		check(NetPayloads.parse_lobby(bad, gd, 2, 4) == null, "salon refusé : " + label)
	check(NetPayloads.parse_lobby("texte", gd, 2, 4) == null, "salon refusé : texte")


func test_match_config() -> void:
	var gd := load_data()
	var good := {"roster": [[1, "Hôte", 0, 1, {}, []], [3, "Ana", 1, 3, {"su_presence": 1}, [0]]], "mode": 0, "map": 8, "rhythm": 0, "launch": 1, "difficulty": 2, "heritage": 0}
	var ok = NetPayloads.parse_config(good, gd, 2, 4)
	check(ok != null and ok["difficulty"] == 2 and ok["roster"][1][3] == 3 and ok["roster"][1][5] == [0], "configuration valide")
	var fair: Dictionary = good.duplicate(true)
	fair["heritage"] = SimMatch.Heritage.OFF
	fair["roster"][1][5] = []
	check(NetPayloads.parse_config(fair, gd, 2, 4) != null, "configuration valide sans héritage")
	for change in [["difficulty", 9], ["difficulty", null], ["launch", -1], ["roster", [[1, "Hôte", 0, 1, {}]]], ["roster", [[1, "Hôte", 0, -1, {}, []]]],
			["roster", [[1, "Hôte", 0, 1, {"triche": 1}, []]]], ["roster", [[1, "Hôte", 0, 1, {}, ["x"]]]], ["heritage", 5], ["heritage", null],
			["heritage", SimMatch.Heritage.OFF]]:  # désactivé alors qu'Ana a encore un héritage
		var bad: Dictionary = good.duplicate(true)
		bad[change[0]] = change[1]
		check(NetPayloads.parse_config(bad, gd, 2, 4) == null, "configuration refusée : %s" % str(change))


func test_heritage_option() -> void:
	var players := {1: {"name": "Hôte", "color": 0, "builder": 0, "talents": {}, "heritage": [2]},
		5: {"name": "Bob", "color": 1, "builder": 1, "talents": {}, "heritage": [0, 3]}}
	var on := NetPayloads.match_roster(players, [1, 5], {"mode": 0, "heritage": SimMatch.Heritage.ON})
	check(on[0][5] == [2] and on[1][5] == [0, 3], "héritage activé : transmis à la partie")
	check(NetPayloads.heritage_on({"mode": 1}), "héritage actif si l'option manque (salon d'avant)")
	var off := NetPayloads.match_roster(players, [1, 5], {"mode": 0, "heritage": SimMatch.Heritage.OFF})
	check(off[0][5].is_empty() and off[1][5].is_empty(), "héritage désactivé : aucun joueur n'en reçoit")
	check(players[5]["heritage"] == [0, 3], "le salon garde l'héritage annoncé (la liste reste affichable)")
	var gd := load_data()
	var kit := PlayerKit.make(gd, off[1][3], off[1][4], off[1][5])
	check(kit.heritage.is_empty(), "kit de partie sans héritage")


func test_difficulty_vote() -> void:
	check(NetPayloads.voted_difficulty({1: {"vote": 2}, 2: {"vote": 2}, 3: {"vote": 0}}, 4) == 2, "majorité")
	check(NetPayloads.voted_difficulty({1: {"vote": 3}, 2: {"vote": 1}}, 4) == 1, "égalité : la plus facile")
	check(NetPayloads.voted_difficulty({1: {"vote": 3}}, 4) == 3, "seul : son vote")
	check(NetPayloads.voted_difficulty({1: {"vote": 9}}, 4) == 0, "vote invalide ignoré")


func test_lan_announces() -> void:
	var good := JSON.stringify({"g": "tdlan", "v": "1.0.0", "n": "Salon", "m": 0, "p": 1, "x": 4, "s": false})
	check(LanDiscovery.parse_announce(good) != null, "annonce valide")
	var bad := [
		"pas du json",
		JSON.stringify({"g": "autre", "v": "1.0.0", "n": "Salon", "m": 0, "p": 1, "x": 4, "s": false}),
		JSON.stringify({"g": "tdlan", "v": "1.0.0", "n": "", "m": 0, "p": 1, "x": 4, "s": false}),
		JSON.stringify({"g": "tdlan", "v": "1.0.0", "n": "Salon", "m": 7, "p": 1, "x": 4, "s": false}),
		JSON.stringify({"g": "tdlan", "v": "1.0.0", "n": "Salon", "m": 0, "p": 1, "x": 4, "s": "non"}),
	]
	for text in bad:
		check(LanDiscovery.parse_announce(text) == null, "annonce refusée : " + text)

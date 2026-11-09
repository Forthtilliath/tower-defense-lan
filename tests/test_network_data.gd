extends "res://tests/test_base.gd"
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
		"pas un dictionnaire": func(s): s.clear(),
	}
	for label in cases:
		var bad: Dictionary = good.duplicate(true)
		cases[label].call(bad)
		check(not view.apply(bad), "refus attendu : " + label)
	check(view.boards[0]["towers"].size() == 1, "l'état précédent est conservé")


func test_lobby_payloads() -> void:
	var ok = NetPayloads.parse_lobby({"players": [[1, "Hôte", 0], [4, "Bob", 1]], "mode": 1, "map": 2}, 3, 2, 4)
	check(ok != null and ok["players"].size() == 2, "salon valide")
	var bad := [
		{"players": [[4, "Bob", 1]], "mode": 0, "map": 0},
		{"players": [[1, "Hôte", 0], [1, "Double", 1]], "mode": 0, "map": 0},
		{"players": [[1, "", 0]], "mode": 0, "map": 0},
		{"players": [[1, "Hôte", 0]], "mode": 5, "map": 0},
		{"players": [[1, "Hôte", 0]], "mode": 0, "map": 3},
		{"players": [[1, "Hôte", 9]], "mode": 0, "map": 0},
		"texte",
	]
	for raw in bad:
		check(NetPayloads.parse_lobby(raw, 3, 2, 4) == null, "salon refusé : %s" % str(raw))


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

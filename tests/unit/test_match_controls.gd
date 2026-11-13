extends "res://tests/unit/test_base.gd"
## Commandes de partie et informations affichées : pause de l'hôte, effectifs annoncés des
## vagues, bestiaire, tracé de la Sylve profonde.


func _map_index(gd: GameData, id: String) -> int:
	for i in gd.maps.size():
		if gd.maps[i].id == id:
			return i
	return -1


func test_host_pause_freezes_the_match() -> void:
	var gd := load_data()
	var loop := HostLoop.new(SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "Hôte", 0], [7, "Invité", 1]]))
	loop.sim.launch_next_wave()
	var sent := []
	var on_tick := func(snap: Dictionary, net: bool) -> void: sent.append([snap, net])
	loop.advance(0.5, on_tick)
	check(loop.handle(7, {"a": "pause", "on": true}) != "" and not loop.paused, "un invité ne met pas en pause")
	check(loop.handle(1, {"a": "pause", "on": true}) == "" and loop.paused, "l'hôte met en pause")
	var tick := loop.sim.tick
	var clock := loop.sim.boards[0].clock
	sent.clear()
	for i in 20:
		loop.advance(0.1, on_tick)
	check(loop.sim.tick == tick and is_equal_approx(loop.sim.boards[0].clock, clock), "rien n'avance en pause")
	check(sent.size() >= 4 and sent[-1][1] and sent[-1][0]["ps"] == true, "l'état part encore, marqué en pause : %d" % sent.size())
	var gold: int = loop.sim.players[1]["gold"]
	loop.handle(1, {"a": "build", "cell": 2 * loop.sim.map.width + 2, "tower": gd.tower_order.find("crossbow")})
	check(loop.sim.players[1]["gold"] < gold, "construire reste possible en pause")
	loop.handle(1, {"a": "pause", "on": false})
	loop.advance(0.2, on_tick)
	check(loop.sim.tick > tick and sent[-1][0]["ps"] == false, "la partie repart")


func test_pause_command_format() -> void:
	var gd := load_data()
	var map: MapDef = gd.maps[0]
	check(Commands.sanitize({"a": "pause", "on": true}, gd, map) is Dictionary, "pause valide")
	for bad in [{"a": "pause"}, {"a": "pause", "on": 1}, {"a": "pause", "on": "oui"}, {"a": "pause", "on": true, "x": 0}]:
		check(Commands.sanitize(bad, gd, map) is String, "pause mal formée rejetée : %s" % str(bad))


func test_paused_flag_reaches_the_view() -> void:
	var gd := load_data()
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "Hôte", 0]])
	var view := ViewState.new(gd, sim.map, 1)
	var snap := sim.snapshot()
	snap["ps"] = true
	check(view.apply(snap) and view.paused, "pause reçue")
	snap["ps"] = "oui"
	check(not view.apply(snap), "pause en texte : instantané ignoré")
	snap.erase("ps")
	check(view.apply(snap) and not view.paused, "ancien hôte sans pause : pas en pause")


## Les effectifs annoncés (bulle des entrées, panneau coop) sont ceux que la simulation envoie.
func test_announced_counts_match_the_simulation() -> void:
	var gd := load_data()
	for setup in [[0, 1, 1], [0, 3, 2], [_map_index(gd, "sylve"), 2, 3], [_map_index(gd, "quatre_fiefs"), 4, 1]]:
		var roster := []
		for i in setup[1]:
			roster.append([i + 1, "J%d" % i, i])
		var sim := SimMatch.new(gd, setup[0], SimMatch.Mode.COOP, roster, setup[2])
		var mult := WaveScaling.count_mult(gd, sim.map, sim.difficulty, true, setup[1])
		for n in [0, 4, 9]:
			var wave: Dictionary = gd.waves[sim.map.waves[n]]
			var expected := 0
			for g in wave["groups"]:
				expected += WaveScaling.group_count(gd, wave, g, mult)
			var before := sim.boards[0]._queue.size()
			while sim.wave_index < n:
				before = sim.boards[0]._queue.size()
				sim.launch_next_wave()
			var queued := sim.boards[0]._queue.size() - before
			check(queued == expected, "%s, %d joueur(s), vague %d : %d annoncés, %d envoyés" % [sim.map.id, setup[1], n + 1, expected, queued])
	var text := MonsterText.wave_text(gd, gd.waves["w1"], 1.0)
	check(text.begins_with("• 8 × Gobelin"), "nombre en tête de ligne : " + text)


func test_bestiary_lists_every_monster_somewhere() -> void:
	var gd := load_data()
	var where := BestiaryData.maps_by_monster(gd)
	var parents := BestiaryData.parents(gd)
	check(where["spiderling"].has("sylve") and parents["spiderling"].has("Araignée"), "les petits d'araignée naissent sur la Sylve")
	for id in gd.monster_order:
		check(not where[id].is_empty(), "%s : on le croise sur au moins une carte" % id)
		check(MonsterText.stats_text(gd, gd.monsters[id]).begins_with("PV "), "%s : caractéristiques" % id)


## La Sylve profonde : deux entrées qui se rejoignent vers une seule sortie, chemins assez longs.
func test_sylve_paths_merge() -> void:
	var gd := load_data()
	var m: MapDef = gd.maps[_map_index(gd, "sylve")]
	check(m.start_count() == 2, "deux entrées")
	var ends := []
	for p in m.start_count():
		check(m.path_length(p, false) >= 35.0, "chemin %d assez long : %.1f" % [p, m.path_length(p, false)])
		ends.append(m.ground_paths[p][-1])
	check(ends[0] == ends[1], "une seule sortie commune")

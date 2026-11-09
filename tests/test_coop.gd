extends "res://tests/test_base.gd"
## Coopération : rythmes, lancement des vagues, zones, bâtisseurs, intérêts, dons, vagues
## spéciales et cartes à plusieurs couloirs.

const DT := 0.05
const PLAINE := 7
const FIEFS := 8
const BASTION := 9


func _sim(players := 1, map := 0, options := {}, builders := []) -> SimMatch:
	var roster := []
	for i in players:
		roster.append([i + 1, "J%d" % (i + 1), i, builders[i] if i < builders.size() else 0])
	return SimMatch.new(load_data(), map, SimMatch.Mode.COOP, roster, 1, options)


func _build(sim: SimMatch, id: int, cell: int, tower := "crossbow") -> String:
	return sim.apply_command(id, {"a": "build", "cell": cell, "tower": tower})


## Première case constructible de la zone (-1 : case commune).
func _cell_in_zone(m: MapDef, zone: int) -> int:
	for i in m.cell_count():
		if m.is_buildable(i) and m.zone_at(i) == zone:
			return i
	return -1


func test_free_rhythm_calls_a_wave_during_a_wave() -> void:
	var sim := _sim()
	sim.launch_next_wave()
	sim.step(DT)
	check(sim.boards[0].pending_waves() == 1, "vague 1 en cours d'apparition")
	var gold: int = sim.players[1]["gold"]
	check(sim.apply_command(1, {"a": "ready"}) == "", "vague suivante appelée pendant la vague")
	check(sim.wave_index == 1, "vague 2 lancée")
	var expected := gold + MatchFlow.interest(sim.data, gold) + 15 + int(SimMatch.BETWEEN_WAVES)
	check(sim.players[1]["gold"] == expected, "intérêts, vague et bonus complet : %d / %d" % [sim.players[1]["gold"], expected])
	check(sim.apply_command(1, {"a": "ready"}) == "Une vague est déjà en attente", "une seule vague d'avance")
	check(_build(sim, 1, 2 * sim.map.width + 2) == "", "construction libre pendant la vague")


func test_between_rhythm_locks_trading_during_waves() -> void:
	var sim := _sim(1, 0, {"rhythm": SimMatch.Rhythm.BETWEEN})
	check(is_equal_approx(sim.countdown, SimMatch.FIRST_BUILD_PHASE), "première phase de construction : %f" % sim.countdown)
	var cell := 2 * sim.map.width + 2
	check(_build(sim, 1, cell) == "", "construction pendant la phase")
	sim.launch_next_wave()
	sim.step(DT)
	check(_build(sim, 1, cell + 1) == MatchActions.LOCKED, "construction bloquée pendant la vague")
	check(sim.apply_command(1, {"a": "upgrade", "cell": cell}) == MatchActions.LOCKED, "amélioration bloquée")
	check(sim.apply_command(1, {"a": "sell", "cell": cell}) == MatchActions.LOCKED, "vente bloquée")
	check(sim.apply_command(1, {"a": "ready"}) == "Impossible pendant une vague", "aucune vague appelée pendant une vague")
	check(sim.apply_command(1, {"a": "mode", "cell": cell}) == "", "le changement de cible reste permis")
	var snap := sim.snapshot()
	check(not snap["tr"] and not snap["nx"], "instantané : achats et appel bloqués")
	for i in int(120.0 / DT):
		sim.step(DT)
		if sim.countdown >= 0.0:
			break
	check(sim.boards[0].is_clear() and sim.countdown > SimMatch.BUILD_PHASE - 1.0, "nouvelle phase quand la carte est vide : %f" % sim.countdown)
	check(_build(sim, 1, cell + 1) == "", "construction de nouveau permise")


func test_host_only_launch() -> void:
	var sim := _sim(2, 0, {"launch": SimMatch.Launch.HOST})
	sim.step(DT)
	check(sim.apply_command(2, {"a": "ready"}) == "Seul l'hôte lance les vagues", "l'invité ne lance pas")
	check(sim.wave_index == -1, "pas de vague lancée")
	check(sim.apply_command(1, {"a": "ready"}) == "", "l'hôte lance seul")
	check(sim.wave_index == 0, "vague lancée sans vote")


func test_versus_ignores_coop_options() -> void:
	var sim := SimMatch.new(load_data(), 0, SimMatch.Mode.VERSUS, [[1, "A", 0], [2, "B", 1]], 1, {"rhythm": 1, "launch": 1})
	check(sim.rhythm == SimMatch.Rhythm.FREE and sim.launch == SimMatch.Launch.VOTE, "versus : rythme libre, vote")


func test_zones_restrict_building() -> void:
	var sim := _sim(2, FIEFS)
	var z0 := _cell_in_zone(sim.map, 0)
	var z1 := _cell_in_zone(sim.map, 1)
	var z2 := _cell_in_zone(sim.map, 2)
	check(_build(sim, 2, z0) == "Cette zone appartient à un autre joueur", "zone d'un autre refusée")
	check(_build(sim, 1, z0) == "", "sa propre zone acceptée")
	check(_build(sim, 1, z2) == "", "à deux, chacun a deux zones")
	check(_build(sim, 1, z1) != "", "zone de l'allié refusée")
	sim.player_left(2)
	check(_build(sim, 1, z1) == "", "zone d'un joueur parti : devenue commune")


func test_zone_distribution() -> void:
	var m: MapDef = load_data().maps[FIEFS]
	for n in range(1, 5):
		for z in m.zone_count:
			var owners := 0
			for i in n:
				if m.zone_allows(z, i, n):
					owners += 1
			check(owners == 1, "%d joueurs : zone %d a un seul propriétaire (%d)" % [n, z, owners])
		for i in n:
			var owned := 0
			for z in m.zone_count:
				if m.zone_allows(z, i, n):
					owned += 1
			check(owned >= 1, "%d joueurs : le joueur %d a au moins une zone" % [n, i])
	check(m.zone_allows(0, 0, 3) and m.zone_allows(3, 0, 3), "à trois, le premier joueur tient deux zones")


func test_mixed_map_has_common_cells() -> void:
	var sim := _sim(2, BASTION)
	check(sim.map.layout() == MapDef.Layout.MIXED, "Bastion est une carte mixte")
	var common := _cell_in_zone(sim.map, -1)
	check(common >= 0 and _build(sim, 2, common) == "", "case commune ouverte à tous")


func test_builder_restricts_towers_and_boosts_them() -> void:
	var gd := load_data()
	var arcanist := -1
	for i in gd.builders.size():
		if gd.builders[i]["id"] == "arcanist":
			arcanist = i
	var sim := _sim(1, 0, {}, [arcanist])
	var cell := 2 * sim.map.width + 2
	check(_build(sim, 1, cell, "cannon").contains("bâtisseur"), "canon interdit à l'arcaniste")
	check(_build(sim, 1, cell, "tesla") == "", "tesla permise")
	var t: SimTower = sim.boards[0].towers[cell]
	var base: float = gd.tower_levels("tesla")[0]["rate"]
	check(is_equal_approx(t.stats["rate"], base * 1.25), "cadence +25 %% : %f" % t.stats["rate"])


func test_interest_is_capped() -> void:
	var gd := load_data()
	check(MatchFlow.interest(gd, 0) == 0 and MatchFlow.interest(gd, 100) == 4, "4 %% de l'or gardé")
	check(MatchFlow.interest(gd, 5000) == 30, "plafonné à 30")


func test_gift_costs_twice_what_the_ally_gets() -> void:
	var sim := _sim(2)
	check(sim.apply_command(1, {"a": "give", "to": 1, "amount": 50}) == "", "don accepté")
	check(sim.players[1]["gold"] == 100 and sim.players[2]["gold"] == 175, "50 donnés, 25 reçus : %d / %d" % [sim.players[1]["gold"], sim.players[2]["gold"]])
	check(sim.notices.size() == 1 and sim.notices[0][0] == 2, "l'allié est prévenu")
	check(sim.apply_command(1, {"a": "give", "to": 0, "amount": 50}) != "", "don à soi-même refusé")
	check(sim.apply_command(1, {"a": "give", "to": 1, "amount": 5}).contains("minimum"), "don trop petit refusé")
	check(sim.apply_command(1, {"a": "give", "to": 1, "amount": 500}) == "Or insuffisant", "don au-delà de son or refusé")
	check(sim.apply_command(1, {"a": "give", "to": 3, "amount": 50}) == "Joueur inconnu", "allié inexistant refusé")
	var versus := SimMatch.new(load_data(), 0, SimMatch.Mode.VERSUS, [[1, "A", 0], [2, "B", 1]])
	check(versus.apply_command(1, {"a": "give", "to": 1, "amount": 50}) != "", "pas de don en versus")
	for raw in [{"a": "give", "to": 1}, {"a": "give", "to": -1, "amount": 10}, {"a": "give", "to": 1, "amount": 0}, {"a": "give", "to": "1", "amount": 10}]:
		check(typeof(Commands.sanitize(raw, sim.data, sim.map)) == TYPE_STRING, "don mal formé refusé : %s" % str(raw))


func test_special_waves_strengthen_monsters() -> void:
	var gd := load_data()
	var b := SimBoard.new(gd, gd.maps[0], 20)
	b.queue_wave(gd.waves["w5"], 1.0)
	b.step(1.0)
	var bat: SimMonster = b.monsters[0]
	check(bat.is_elite() and is_equal_approx(bat.speed, 1.8 * 1.4), "Ruée : chauves-souris plus rapides (%f)" % bat.speed)
	check(is_equal_approx(bat.max_hp, 16.0 * 0.85), "Ruée : un peu plus fragiles (%f)" % bat.max_hp)
	var giants := SimBoard.new(gd, gd.maps[0], 20)
	giants.queue_wave(gd.waves["w10"], 1.0)
	check(giants._queue.size() == 1 + 5, "Colosses : moitié moins de monstres (%d)" % giants._queue.size())
	var armored := SimBoard.new(gd, gd.maps[0], 20)
	armored.queue_wave(gd.waves["w15"], 1.0)
	armored.step(1.0)
	check(is_equal_approx(armored.monsters[0].armor, 2.0), "Cuirassés : +2 d'armure (%f)" % armored.monsters[0].armor)
	var normal := SimBoard.new(gd, gd.maps[0], 20)
	normal.queue_wave(gd.waves["w1"], 1.0)
	normal.step(1.0)
	check(not normal.monsters[0].is_elite(), "vague normale : monstres normaux")
	var view := ViewState.new(gd, gd.maps[0], 1)
	var snap := {"wave": 5, "total": 15, "cd": -1.0, "end": false, "res": "", "win": 0, "nx": true, "tr": true, "pl": [], "b": [b.snapshot()]}
	check(view.apply(snap) and view.boards[0]["monsters"][bat.id]["elite"], "halo de vague spéciale transmis")


func test_lanes_scale_lives_gold_and_count() -> void:
	var solo := _sim(1, FIEFS)
	check(solo.boards[0].lives == 80, "4 couloirs : 4 fois plus de vies (%d)" % solo.boards[0].lives)
	check(solo.players[1]["gold"] == 600, "seul pour 4 couloirs : 4 fois plus d'or (%d)" % solo.players[1]["gold"])
	check(solo.coop_scaling(1) == [1.0, 4.0, 4.0], "une vague solo par couloir : %s" % str(solo.coop_scaling(1)))
	var trio := _sim(3, FIEFS)
	check(trio.players[1]["gold"] == 300 and trio.players[2]["gold"] == 150, "or selon les zones tenues : %d / %d" % [trio.players[1]["gold"], trio.players[2]["gold"]])
	var full := _sim(4, FIEFS)
	check(full.coop_scaling(4) == [1.0, 4.0, 1.0] and full.players[4]["gold"] == 150, "un joueur par couloir : règles solo")
	var prairie := _sim(3)
	var s := prairie.coop_scaling(3)
	check(is_equal_approx(s[0], 1.3) and is_equal_approx(s[1], 1.7) and prairie.boards[0].lives == 20, "carte à un couloir : renforcement habituel %s" % str(s))


func test_big_maps() -> void:
	var gd := load_data()
	var expected := {PLAINE: [MapDef.Layout.SHARED, 1, 133.0], FIEFS: [MapDef.Layout.ZONED, 4, 46.0], BASTION: [MapDef.Layout.MIXED, 4, 53.0]}
	for i in expected:
		var m: MapDef = gd.maps[i]
		var e: Array = expected[i]
		check(m.layout() == e[0] and m.lanes == e[1], "%s : disposition et couloirs" % m.id)
		for p in m.start_count():
			check(is_equal_approx(m.path_length(p, false), e[2]), "%s : chemin %d de %f cases" % [m.id, p, m.path_length(p, false)])
		check(m.max_players == 4, "%s : conseillée jusqu'à 4" % m.id)

extends "res://tests/test_base.gd"
## Coopération : rythmes, lancement des vagues, zones, bâtisseurs, intérêts, dons, vagues
## spéciales et cartes à plusieurs couloirs.

const DT := 0.05
const PLAINE := 6
const FIEFS := 7
const BASTION := 8


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
	for i in int(60.0 / DT):
		sim.step(DT)
	check(sim.wave_index == -1, "la première phase de construction dure jusqu'au lancement")
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
	check(_build(sim, 1, z2) == MatchActions.CLOSED, "à deux, la zone d'un couloir fermé est refusée")
	check(_build(sim, 1, z1) != "", "zone de l'allié refusée")
	sim.player_left(2)
	check(_build(sim, 1, z1) == "", "zone d'un joueur parti : devenue commune")
	check(_build(sim, 1, _cell_in_zone(sim.map, 3)) == MatchActions.CLOSED, "une zone fermée le reste")


## Seul sur une carte à couloirs : seule la zone de son couloir est ouverte (pas de pillage des
## filons des autres zones), même pour raser du décor ou poser une case.
func test_solo_lanes_close_other_zones() -> void:
	var sim := _sim(1, FIEFS)
	check(_build(sim, 1, _cell_in_zone(sim.map, 0)) == "", "sa zone acceptée")
	for z in [1, 2, 3]:
		check(_build(sim, 1, _cell_in_zone(sim.map, z)) == MatchActions.CLOSED, "zone %d fermée" % z)
	var rock := -1
	for i in sim.map.cell_count():
		if sim.map.is_decor(i) and sim.map.zone_at(i) == 1:
			rock = i
	check(rock >= 0 and sim.map.zone_closed(1, 1), "le décor garde sa zone")
	var colors := BoardPainter.zone_colors(sim.map, [Color.RED] as Array[Color])
	check(str(colors) == str([Color.RED, BoardPainter.CLOSED, BoardPainter.CLOSED, BoardPainter.CLOSED]), "zones fermées assombries : %s" % str(colors))
	check(is_equal_approx(sim.monster_hp_mult(), sim.map.monster_hp) and sim.map.monster_hp > 1.0, "route longue : monstres renforcés (x%f)" % sim.monster_hp_mult())
	var plaine := _sim(1, PLAINE)
	check(_build(plaine, 1, _cell_in_zone(plaine.map, -1)) == "", "carte sans zones : rien de fermé")


func test_lobby_sorts_maps_from_easy_to_hard() -> void:
	var maps := load_data().maps
	var order := MapDef.by_tier(maps)
	check(order.size() == maps.size() and order[0] == 0, "toutes les cartes, Prairie en tête : %s" % str(order))
	for k in range(1, order.size()):
		check(maps[order[k - 1]].tier <= maps[order[k]].tier, "%s avant %s" % [maps[order[k - 1]].id, maps[order[k]].id])


func test_zone_distribution() -> void:
	var m: MapDef = load_data().maps[FIEFS]
	for n in range(1, 5):
		for z in m.zone_count:
			var owners := 0
			for i in n:
				if m.zone_allows(z, i, n):
					owners += 1
			var expected := 0 if z >= n else 1
			check(owners == expected, "%d joueurs : zone %d a %d propriétaire(s) (%d)" % [n, z, expected, owners])
		for i in n:
			var owned := 0
			for z in m.zone_count:
				if m.zone_allows(z, i, n):
					owned += 1
			check(owned == 1, "%d joueurs : le joueur %d tient sa zone, une seule" % [n, i])


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
	var beginner := _sim(1, 0, {}, [arcanist])
	var cell := 2 * beginner.map.width + 2
	check(_build(beginner, 1, cell, "mortar").contains("bâtisseur"), "mortier interdit à l'arcaniste")
	check(_build(beginner, 1, cell, "pylon").contains("bâtisseur"), "pylône à débloquer par la spécialisation")
	var talents := {"ar_conductive": 3, "ar_pylon": 1, "ar_overload": 1}
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0, arcanist, talents]])
	check(_build(sim, 1, cell, "pylon") == "", "pylône débloqué")
	var t: SimTower = sim.boards[0].towers[cell]
	var base: float = gd.tower_levels("pylon")[0]["rate"]
	check(is_equal_approx(t.stats["rate"], base * 1.06), "cadence : Surcharge +6 %% : %f" % t.stats["rate"])
	var dmg: float = gd.tower_levels("pylon")[0]["damage"]
	check(is_equal_approx(t.stats["damage"], dmg * 1.1 * 1.15), "dégâts : classe +10 %%, Conductivité 3 x 5 %% : %f" % t.stats["damage"])
	var arrow := _build(sim, 1, cell + 1, "crossbow")
	check(arrow == "" and is_equal_approx(sim.boards[0].towers[cell + 1].stats["damage"], gd.tower_levels("crossbow")[0]["damage"]), "bonus de classe réservé aux tourelles élémentaires")


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


## Carte à 4 couloirs : un couloir ouvert par joueur, celui de sa zone, avec une vague solo complète.
func test_lanes_open_one_per_player() -> void:
	var solo := _sim(1, FIEFS)
	check(solo.open_paths.size() == 1 and solo.boards[0].lives == 20, "seul : un couloir, vies normales (%d)" % solo.boards[0].lives)
	check(solo.players[1]["gold"] == 150 and solo.coop_scaling(1) == [1.0, 1.0, 1.0], "seul : or et vague solo")
	solo.apply_command(1, {"a": "ready"})
	for i in 200:
		solo.step(0.05)
	var paths := {}
	for m in solo.boards[0].monsters:
		paths[m.path] = true
	check(paths.keys() == solo.open_paths, "les monstres n'arrivent que par le couloir ouvert : %s" % str(paths.keys()))
	var trio := _sim(3, FIEFS)
	check(trio.open_paths.size() == 3 and trio.boards[0].lives == 60, "à trois : 3 couloirs, 3 fois plus de vies")
	check(trio.players[1]["gold"] == 150 and trio.players[3]["gold"] == 150, "chacun son couloir : or normal")
	for p in trio.open_paths.size():
		check(trio.map._start_zone(trio.open_paths[p]) == p, "le joueur %d défend le couloir de sa zone" % (p + 1))
	var full := _sim(4, FIEFS)
	check(full.coop_scaling(4) == [1.0, 4.0, 1.0] and full.players[4]["gold"] == 150, "un joueur par couloir : règles solo")
	check(full.coop_scaling(2) == [1.0, 4.0, 2.0], "deux joueurs partis : les couloirs restent, l'or double")
	var prairie := _sim(3)
	var s := prairie.coop_scaling(3)
	check(is_equal_approx(s[0], 1.3) and is_equal_approx(s[1], 1.7) and prairie.boards[0].lives == 20, "carte à un couloir : renforcement habituel %s" % str(s))


func test_big_maps() -> void:
	var gd := load_data()
	var expected := {PLAINE: [MapDef.Layout.SHARED, 1, 133.0], FIEFS: [MapDef.Layout.ZONED, 4, 46.0], BASTION: [MapDef.Layout.MIXED, 4, 41.0]}
	for i in expected:
		var m: MapDef = gd.maps[i]
		var e: Array = expected[i]
		check(m.layout() == e[0] and m.lanes == e[1], "%s : disposition et couloirs" % m.id)
		for p in m.start_count():
			check(is_equal_approx(m.path_length(p, false), e[2]), "%s : chemin %d de %f cases" % [m.id, p, m.path_length(p, false)])
		check(m.max_players == 4, "%s : conseillée jusqu'à 4" % m.id)

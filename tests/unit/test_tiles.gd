extends "res://tests/unit/test_base.gd"
## Cartes : entrées par vague, placement et variété des cases spéciales, effets des cases.


func _map(gd: GameData, id: String) -> int:
	for i in gd.maps.size():
		if gd.maps[i].id == id:
			return i
	return -1


func _special(gd: GameData, id: String) -> int:
	for i in gd.specials.size():
		if gd.specials[i]["id"] == id:
			return i
	return -1


func _solo(map_id := "prairie") -> SimMatch:
	var gd := load_data()
	var sim := SimMatch.new(gd, _map(gd, map_id), SimMatch.Mode.COOP, [[1, "A", 0]])
	sim.players[1]["gold"] = 100000
	return sim


## Pose une case spéciale sur une case libre de la carte du plateau, et y construit `tower`.
func _tower_on(sim: SimMatch, special: String, tower: String) -> SimTower:
	var b := sim.boards[0]
	var cell := -1
	for i in b.map.cell_count():
		if b.map.is_buildable(i) and b.map.special_at(i) < 0 and MapCoverage.route_cover(b.map, i) > 4:
			cell = i
			break
	b.map.set_cell(cell, MapDef.Cell.BUILD, _special(sim.data, special))
	check(sim.apply_command(1, {"a": "build", "cell": cell, "tower": tower}) == "", "%s construite sur %s" % [tower, special])
	return b.towers[cell]


func test_every_special_tile_is_well_placed() -> void:
	var gd := load_data()
	for m in gd.maps:
		for w in MapCoverage.weak_specials(m):
			var c := m.cell_coords(w[0])
			check(false, "%s : case spéciale (%d, %d) mal placée (%d cases de route, seuil %d)" % [m.id, c.x, c.y, w[1], MapCoverage.threshold(m)])


func test_maps_pick_a_few_special_kinds() -> void:
	var gd := load_data()
	for m in gd.maps:
		var kinds := {}
		var count := 0
		for i in m.cell_count():
			if m.special_at(i) >= 0:
				kinds[m.special_at(i)] = true
				count += 1
		check(kinds.size() >= 2 and kinds.size() <= 3, "%s : %d types de cases spéciales (2 ou 3)" % [m.id, kinds.size()])
		var most := 3 * m.lanes if m.lanes > 1 else 7  # 4 à 7, ou 3 par couloir sur une carte à couloirs
		check(count >= 4 and count <= most, "%s : %d cases spéciales (%d au plus)" % [m.id, count, most])


func test_entries_open_by_wave() -> void:
	var gd := load_data()
	var m: MapDef = gd.maps[_map(gd, "trois_portes")]
	check(m.entries.size() == 7 and m.start_count() == 3, "trois entrées, motif de 7 vagues")
	check(MapSpawns.wave_paths(m, 0).size() == 1 and MapSpawns.wave_paths(m, 6).size() == 3, "une entrée, puis les trois")
	check(MapSpawns.wave_entries(m, 7) == "1", "le motif recommence")
	check(EntryPainter.text(m, 3) == "Entrées : 1 et 2", "texte des entrées : %s" % EntryPainter.text(m, 3))
	var plain: MapDef = gd.maps[_map(gd, "prairie")]
	check(MapSpawns.wave_paths(plain, 3).is_empty() and EntryPainter.text(plain, 0) == "", "carte sans entrées par vague")


func test_monsters_use_the_entries_of_their_wave() -> void:
	var sim := _solo("trois_portes")
	var b := sim.boards[0]
	var first := MapSpawns.wave_paths(sim.map, 0)
	sim.launch_next_wave()
	for i in 200:
		sim.step(0.05)
	check(not b.monsters.is_empty(), "des monstres sont arrivés")
	check(b.monsters.all(func(x: SimMonster) -> bool: return x.path == first[0]), "vague 1 : tous par l'entrée 1")


func test_entries_are_checked() -> void:
	var gd := load_data()
	var rows := ["1===E", ".....", "2===E", "....."]
	var m = MapDef.parse("t", "T", rows, [] as Array[String])
	check(m is MapDef and m.path_labels == PackedInt32Array([1, 2]), "départs numérotés")
	check(MapSpawns.check(m, []) != "", "départs numérotés sans motif refusés")
	check(MapSpawns.check(m, ["1"]) != "", "entrée 2 jamais utilisée refusée")
	check(MapSpawns.check(m, ["1", "3"]) != "", "entrée absente refusée")
	check(MapSpawns.check(m, ["1", "12", 5]) != "", "motif invalide refusé")
	check(MapSpawns.check(m, ["2", "12"]) == "", "motif valide accepté")
	m.lanes = 2
	check(MapSpawns.check(m, ["2", "12"]) != "", "pas d'entrées sur une carte à couloirs")
	check(gd.is_valid(), "les données du jeu restent valides")


func test_family_tiles_only_help_their_towers() -> void:
	var gd := load_data()
	var fire := _special(gd, "campfire")
	var base_fire: float = gd.tower_stats("brazier", 0)["damage"]
	var base_bow: float = gd.tower_stats("crossbow", 0)["damage"]
	check(is_equal_approx(gd.tower_stats("brazier", 0, fire)["damage"], base_fire * 1.4), "feu de camp : +40 % au Brasier")
	check(is_equal_approx(gd.tower_stats("crossbow", 0, fire)["damage"], base_bow), "rien pour l'Arbalète")
	var bell := _special(gd, "bell")
	check(gd.tower_stats("banner", 0, bell)["range"] > gd.tower_stats("banner", 0)["range"], "cloche : aura plus large")
	check(is_equal_approx(gd.tower_stats("crossbow", 0, bell)["range"], gd.tower_stats("crossbow", 0)["range"]), "cloche : rien pour une tourelle qui tire")
	var menhir := gd.tower_stats("tesla", 0, _special(gd, "menhir"))
	check(int(menhir["chain"]) == int(gd.tower_stats("tesla", 0)["chain"]) + 1, "menhir : un rebond de plus")
	check(int(gd.tower_stats("cannon", 0, _special(gd, "crowsnest"))["all_targets"]) == 1, "nid de corbeaux : le Canon vise les volants")


func test_hunt_tile_pays_per_kill() -> void:
	var sim := _solo()
	var t := _tower_on(sim, "hunt", "crossbow")
	var b := sim.boards[0]
	var m := b.spawn("goblin", 1.0, 0, 1.0)
	m.speed = 0.0
	m.pos = t.center
	m.hp = 0.5
	var p := SimProjectile.new()
	p.stats = BoardAuras.effective_stats(t)
	p.credit = BoardCombat.solo(1)
	p.owner = 1
	BoardFeats.on_shot(b, t, p)
	var rewards := []
	BoardCombat.damage(b, m, 5.0, false, p.credit, rewards)
	BoardFeats.after_hit(b, m, p, 5.0, rewards)
	check(rewards.any(func(r: Array) -> bool: return r.size() == 2 and r[0] == 1 and r[1] == 1), "+1 or pour le monstre tué : %s" % str(rewards))


func test_unstable_tile_wears_out() -> void:
	var sim := _solo("spirale")  # Filon instable en (4, 4)
	var b := sim.boards[0]
	var cell := 4 * sim.map.width + 4
	check(sim.data.specials[sim.map.special_at(cell)]["id"] == "unstable", "Filon instable sur la Spirale")
	check(sim.apply_command(1, {"a": "build", "cell": cell, "tower": "crossbow"}) == "", "Arbalète dessus")
	var t: SimTower = b.towers[cell]
	var boosted: float = t.stats["damage"]
	for i in 5:
		BoardTiles.on_wave(b)
	check(BoardTiles.waves_left(b, cell) == 1 and t.special >= 0, "encore une vague")
	BoardTiles.on_wave(b)
	check(t.special < 0 and b.map.special_at(cell) < 0, "case épuisée")
	check(t.stats["damage"] < boosted, "la tourelle perd son bonus")
	var view := ViewState.new(sim.data, sim.map, sim.boards.size())
	var snap := sim.snapshot()
	snap["speed"] = 1
	snap["iv"] = 0.1
	check(view.apply(snap), "un client accepte la case épuisée")


func test_forge_discounts_upgrades() -> void:
	var sim := _solo()
	var t := _tower_on(sim, "forge", "crossbow")
	var before: int = sim.players[1]["gold"]
	check(sim.apply_command(1, {"a": "upgrade", "cell": t.cell}) == "", "amélioration")
	var full: int = sim.data.tower_levels("crossbow")[1]["cost"]
	check(before - int(sim.players[1]["gold"]) == sim.players[1]["kit"].cost(full, 0.25), "25 %% moins cher : %d" % (before - int(sim.players[1]["gold"])))


func test_islet_cannot_be_jammed() -> void:
	var sim := _solo()
	var t := _tower_on(sim, "islet", "crossbow")
	var b := sim.boards[0]
	var near := -1
	for d in [1, -1, sim.map.width, -sim.map.width]:
		if b.can_build(t.cell + d) and b.map.special_at(t.cell + d) < 0:
			near = t.cell + d
			break
	check(near >= 0 and sim.apply_command(1, {"a": "build", "cell": near, "tower": "crossbow"}) == "", "tourelle voisine sans îlot")
	var m := b.spawn("saboteur", 1.0, 0, 1.0)
	m.pos = t.center
	MonsterAbilities._jam(b, m, m.jam_interval)
	check(not t.is_jammed(), "îlot : pas de brouillage")
	check(near >= 0 and b.towers[near].is_jammed(), "la voisine est brouillée")

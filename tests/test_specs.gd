extends "res://tests/test_base.gd"
## Mécaniques des spécialisations : gelure et électrifié (tourelles d'imprégnation), soins coupés,
## volants cloués au sol, tir multiple, aura de portée, Comptoir, Chantier, primes d'équipe,
## or des vagues lancées en avance et des vagues sans fuite, et leur transmission.

const DT := 0.05
const AT := Vector2(5, 5)


func _board() -> SimBoard:
	var gd := load_data()
	return SimBoard.new(gd, gd.maps[0], 20)


## Tourelle posée sur une case libre puis déplacée en `at` ; auras recalculées.
func _tower(b: SimBoard, type: String, at: Vector2, owner := 7, kit: PlayerKit = null) -> SimTower:
	var cell := 0
	while not b.can_build(cell):
		cell += 1
	var t := b.add_tower(cell, type, owner, 0, kit)
	t.center = at
	BoardAuras.refresh(b)
	return t


func _mob(b: SimBoard, type: String, at: Vector2) -> SimMonster:
	var m := b.spawn(type, 1.0, 0, 1.0)
	m.speed = 0.0
	m.pos = at
	return m


func _fire(b: SimBoard, t: SimTower) -> void:
	t.cooldown = 0.0
	BoardCombat.fire_towers(b, 0.001, [])
	for i in 40:
		BoardCombat.move_projectiles(b, DT, [])


func _kit(gd: GameData, builder: String, talents: Dictionary) -> PlayerKit:
	for i in gd.builders.size():
		if gd.builders[i]["id"] == builder:
			return PlayerKit.make(gd, i, talents)
	return null


func test_frost_stele_imbues_ice_neighbours_only() -> void:
	var b := _board()
	var frost := _tower(b, "frost", AT)
	var arrow := _tower(b, "crossbow", AT + Vector2(0, 1))
	_tower(b, "frost_stele", AT + Vector2(1, 0), 3)
	check(frost.buff("frostbite") == 3.0 and arrow.buff("frostbite") == 0.0, "gelure pour le Givre seulement")
	var orc := _mob(b, "orc", AT + Vector2(1.5, 0))
	_fire(b, frost)
	check(orc.marks.is_frostbitten() and orc.marks.frost_owner == 3, "gelure posée, créditée au poseur de la Stèle")
	var before := orc.hp
	MonsterEffects.update(b, 1.0, [])
	var lost := before - orc.hp
	check(is_equal_approx(lost, 3.0 * MonsterMarks.FROSTBITE_SLOWED), "×1,5 sur un ralenti, sans armure : %f" % lost)


func test_imbue_all_talent_reaches_every_neighbour() -> void:
	var b := _board()
	var kit := _kit(b.data, "scourge", {"fl_numb": 3, "fl_frost_stele": 1, "fl_chilblains": 2, "fl_black_frost": 2, "fl_spread_frost": 1})
	var arrow := _tower(b, "crossbow", AT)
	_tower(b, "frost_stele", AT + Vector2(1, 0), 3, kit)
	check(arrow.buff("frostbite") > 3.0, "avec le talent, l'Arbalète imprégnée (gelure renforcée) : %f" % arrow.buff("frostbite"))


func test_lightning_rod_shock_raises_damage_taken() -> void:
	var b := _board()
	var tesla := _tower(b, "tesla", AT)
	_tower(b, "lightning_rod", AT + Vector2(1, 0))
	var orc := _mob(b, "orc", AT + Vector2(1.5, 0))
	_fire(b, tesla)
	check(orc.marks.is_shocked() and is_equal_approx(orc.marks.vulnerability(), 0.08), "électrifié : +8 %")
	var before := orc.hp
	BoardCombat.damage(b, orc, 10.0, true, [[1, 1.0]], [])
	check(is_equal_approx(before - orc.hp, 10.8), "10 dégâts → 10,8 : %f" % (before - orc.hp))


func test_alembic_cuts_healing() -> void:
	var b := _board()
	var alembic := _tower(b, "alembic", AT)
	var troll := _mob(b, "troll", AT + Vector2(1, 0))
	troll.hp = 100.0
	_fire(b, alembic)
	troll.poison_timer = 0.0  # on ne mesure que la régénération
	var before := troll.hp
	MonsterEffects.update(b, 1.0, [])
	check(is_equal_approx(troll.hp - before, 2.0 * 0.7), "régénération réduite de 30 %% : %f" % (troll.hp - before))


func test_whirlwind_grounds_flyers_for_ground_towers() -> void:
	var b := _board()
	var bat := _mob(b, "bat", AT + Vector2(1, 0))
	check(not BoardCombat.can_hit(false, true, bat), "un canon ne touche pas un volant")
	_fire(b, _tower(b, "whirlwind", AT))
	check(bat.marks.is_grounded() and BoardCombat.can_hit(false, true, bat), "cloué au sol : le canon le touche")
	check(BoardCombat.can_hit(true, false, bat), "la Sentinelle le touche toujours")


func test_gatling_shoots_several_targets() -> void:
	var b := _board()
	var gatling := _tower(b, "gatling", AT)  # 2 cibles au niveau 1
	var a := _mob(b, "orc", AT + Vector2(1, 0))
	var c := _mob(b, "orc", AT + Vector2(0, 1))
	var d := _mob(b, "orc", AT + Vector2(-1, 0))
	_fire(b, gatling)
	var hit := [a, c, d].filter(func(m: SimMonster) -> bool: return m.hp < 40.0).size()
	check(hit == 2, "deux monstres touchés : %d" % hit)


func test_beacon_extends_range() -> void:
	var b := _board()
	var arrow := _tower(b, "crossbow", AT)
	_tower(b, "beacon", AT + Vector2(1, 0))
	check(is_equal_approx(BoardAuras.reach(arrow), 2.5 * 1.08), "portée +8 %% : %f" % BoardAuras.reach(arrow))
	var far := _mob(b, "orc", AT + Vector2(2.6, 0))
	check(BoardCombat.find_target(b, arrow, b.data.towers["crossbow"]) == far, "cible juste hors de la portée normale")


func test_counter_raises_bounty_where_monsters_die() -> void:
	var b := _board()
	_tower(b, "counter", AT, 3)
	var near := _mob(b, "orc", AT + Vector2(1, 0))
	var rewards := []
	b.kill(near, 1, rewards)
	var by := {}
	for r in rewards:
		by[r[0]] = int(by.get(r[0], 0)) + int(r[1])
	var gold: int = near.gold
	check(by.get(1, 0) == roundi(gold * 1.1) and by.get(3, 0) >= 1, "prime +10 %% au tueur, part au Gobelin : %s" % str(rewards))
	var far := _mob(b, "orc", AT + Vector2(5, 0))
	var plain := []
	b.kill(far, 1, plain)
	check(plain.size() == 1 and plain[0][1] == far.gold, "hors de portée : prime normale")


func test_worksite_discounts_nearby_builds_for_allies() -> void:
	var gd := load_data()
	var mason := _kit(gd, "mason", {})
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "B", 0, mason.builder, {}], [2, "A", 1, 0, {}]])
	var b := sim.boards[0]
	var w := sim.map.width
	b.add_tower(2 * w + 2, "worksite", 1, 70)
	var start: int = sim.players[2]["gold"]
	check(sim.apply_command(2, {"a": "build", "cell": 2 * w + 3, "tower": "crossbow"}) == "", "construction près du Chantier")
	check(start - sim.players[2]["gold"] == roundi(50 * 0.95), "l'allié paie 5 %% de moins : %d" % (start - sim.players[2]["gold"]))


func test_patron_team_bounty_and_gambler_gold() -> void:
	var gd := load_data()
	var goblin := 0
	for i in gd.builders.size():
		if gd.builders[i]["id"] == "goblin":
			goblin = i
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0, 0, {}], [2, "G", 1, goblin, {"go_generous": 3, "go_patronage": 2}]])
	var before: int = sim.players[1]["gold"]
	MatchEconomy.credit_bounty(sim, 1, 100)
	check(sim.players[1]["gold"] - before == 106, "l'allié touche +6 %% grâce au Mécène : %d" % (sim.players[1]["gold"] - before))
	var gambler := PlayerKit.make(gd, goblin, {"go_stake": 3, "go_bet": 2, "go_double": 1})
	check(is_equal_approx(gambler.early_bonus, 1.0) and gambler.clean_gold == 6, "Parieur : avance ×2, +6 or sans fuite")
	var solo := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "P", 0, goblin, gambler.talents]])
	solo.apply_command(1, {"a": "ready"})  # vague 1, sans bonus
	var g0: int = solo.players[1]["gold"]
	solo.countdown = 10.0
	solo.launch_next_wave()  # vague 2 lancée en avance, aucune vie perdue
	var wave: Dictionary = gd.waves[solo.map.waves[1]]
	var expected := int(wave["gold"]) + 10 * 2 + 6
	var got: int = solo.players[1]["gold"] - g0
	check(got - MatchFlow.interest(gd, g0, gambler) == expected, "or de vague + avance ×2 + vague propre : %d" % got)


func test_snapshot_carries_new_marks_and_invested() -> void:
	var gd := load_data()
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0, 0, {}]])
	var b := sim.boards[0]
	var w := sim.map.width
	sim.apply_command(1, {"a": "build", "cell": 2 * w + 2, "tower": "crossbow"})
	var m := _mob(b, "orc", AT)
	m.marks.apply_shock(0.1)
	m.marks.apply_frostbite(2.0, 1)
	var view := ViewState.new(gd, sim.map, 1)
	check(view.apply(sim.snapshot()), "instantané accepté")
	var vm: Dictionary = view.boards[0]["monsters"][m.id]
	check(vm["shocked"] and vm["frostbitten"] and not vm["grounded"], "électrifié et gelure transmis")
	check(view.boards[0]["towers"][2 * w + 2]["invested"] == 50, "or investi transmis")


func _mason_sim(talents: Dictionary) -> SimMatch:
	var gd := load_data()
	var mason := _kit(gd, "mason", talents)
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "T", 0, mason.builder, talents]])
	sim.players[1]["gold"] = 5000
	return sim


func test_digger_razes_decor_to_build_on_it() -> void:
	var sim := _mason_sim({"bu_survey": 1})  # 2 charges
	var b := sim.boards[0]
	var tree := 2  # Prairie : « ..T... » sur la première ligne
	var route := sim.map.width  # deuxième ligne : départ et route
	check(b.map.is_decor(tree) and not b.can_build(tree), "un arbre ne se construit pas")
	check(sim.apply_command(1, {"a": "raze", "cell": route}) != "", "la route ne se rase pas")
	check(sim.apply_command(1, {"a": "raze", "cell": tree}) == "", "arbre rasé")
	check(b.can_build(tree) and sim.apply_command(1, {"a": "build", "cell": tree, "tower": "crossbow"}) == "", "on construit dessus")
	check(sim.data.maps[0].is_decor(tree), "la carte d'origine n'est pas touchée")
	check(MatchActions.charges_left(sim.players[1], "raze") == 1, "une charge restante")
	var rock := sim.map.cells.find(MapDef.Cell.ROCK)
	check(sim.apply_command(1, {"a": "raze", "cell": rock}) == "", "rocher rasé")
	var other := sim.map.cells.find(MapDef.Cell.TREE, tree + 1)
	check(sim.apply_command(1, {"a": "raze", "cell": other}).contains("Plus"), "plus de charge")


func test_digger_places_bonus_tiles() -> void:
	var sim := _mason_sim({"bu_survey": 3, "bu_foundations": 1, "bu_terrace": 1})  # 1 case
	var b := sim.boards[0]
	var cell := 2 * sim.map.width + 2
	check(sim.apply_command(1, {"a": "build", "cell": cell, "tower": "crossbow"}) == "", "tourelle posée")
	var before: float = b.towers[cell].stats["damage"]
	check(sim.apply_command(1, {"a": "tile", "cell": cell, "special": 3}) != "", "pas de Filon d'or")
	check(sim.apply_command(1, {"a": "tile", "cell": cell, "special": 1}) == "", "Cristal posé sous la tourelle")
	check(is_equal_approx(b.towers[cell].stats["damage"], before * 1.3), "la tourelle en profite : %f" % b.towers[cell].stats["damage"])
	check(sim.apply_command(1, {"a": "tile", "cell": cell + 1, "special": 0}).contains("Plus"), "plus de case à poser")
	check(Commands.sanitize({"a": "tile", "cell": 5, "special": 99}, sim.data, sim.map) is String, "case spéciale inconnue refusée")
	check(Commands.sanitize({"a": "raze", "cell": 5}, sim.data, sim.map) is Dictionary, "commande « raser » reconnue")


func test_terrain_changes_reach_the_view_and_are_checked() -> void:
	var sim := _mason_sim({"bu_survey": 3, "bu_foundations": 1, "bu_terrace": 1})
	var tree := 2
	sim.apply_command(1, {"a": "raze", "cell": tree})
	sim.apply_command(1, {"a": "build", "cell": tree, "tower": "crossbow"})
	sim.apply_command(1, {"a": "tile", "cell": 2 * sim.map.width + 2, "special": 2})
	var view := ViewState.new(sim.data, sim.map, 1)
	var snap := sim.snapshot()
	check(view.apply(snap), "instantané accepté (tourelle sur l'arbre rasé)")
	check(view.map_version > 0 and view.maps[0].is_buildable(tree), "carte du client à jour")
	check(view.maps[0].special_at(2 * sim.map.width + 2) == 2, "Rune transmise")
	check(view.players[1]["raze"] == 5 and view.players[1]["tile"] == 0, "charges restantes transmises")
	var bad: Dictionary = sim.snapshot()
	bad["b"][0]["e"].append([sim.map.width, MapDef.Cell.BUILD, -1])  # la route « rasée »
	check(not view.apply(bad), "changement sur la route refusé")

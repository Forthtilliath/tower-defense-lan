extends "res://tests/unit/test_base.gd"
## Capacités des monstres des thèmes (MonsterExtras) : meute, piétinement, rôdeur, bosquet,
## enfouissement, ponte (à intervalles et par paliers de PV) et relève des morts.

const DT := 0.05


func _board(map_id := "prairie") -> SimBoard:
	var gd := load_data()
	for m in gd.maps:
		if m.id == map_id:
			return SimBoard.new(gd, m, 20)
	return null


func _still(b: SimBoard, type: String, progress: float, path := 0) -> SimMonster:
	var m := b.spawn(type, 1.0, path, progress)
	m.speed = 0.0
	return m


func _run(b: SimBoard, seconds: float) -> void:
	for i in int(seconds / DT):
		b.step(DT)


func test_pack_and_trample_change_pace() -> void:
	var b := _board()
	var lone := _still(b, "snow_wolf", 2.0)
	var pack := [_still(b, "snow_wolf", 10.0), _still(b, "snow_wolf", 10.3), _still(b, "snow_wolf", 10.6)]
	var goblin := _still(b, "goblin", 20.0)
	_still(b, "mammoth", 20.5)
	MonsterExtras.update(b, DT)
	check(is_equal_approx(lone.marks.pace, 1.0), "loup seul : vitesse normale")
	check(pack[1].marks.pace > 1.3, "loup en meute : plus rapide (%f)" % pack[1].marks.pace)
	check(is_equal_approx(goblin.marks.pace, 1.25), "gobelin près du mammouth : +25 %% (%f)" % goblin.marks.pace)


func test_vulture_lurks_and_sylvan_heals_by_trees() -> void:
	var b := _board()
	_still(b, "goblin", 3.0)
	var vulture := _still(b, "vulture", 12.0)
	var sylvan := _still(b, "sylvan", 1.0)
	sylvan.pos = Vector2(2.5, 0.5)  # Prairie : arbre en (2, 0)
	MonsterExtras.update(b, DT)
	check(is_equal_approx(vulture.marks.pace, MonsterExtras.LURK_PACE), "le vautour attend derrière le gobelin")
	check(sylvan.marks.regen_mult > 1.0, "le sylvain se régénère plus vite à côté d'un arbre")


func test_sandworm_burrows_out_of_reach() -> void:
	var b := _board()
	var worm := _still(b, "sandworm", 5.0)
	_run(b, 6.1)
	check(worm.marks.burrowed, "enfoui après 6 s")
	check(not BoardCombat.can_hit(true, true, worm), "aucune tourelle ne le vise")
	var hp := worm.hp
	BoardCombat.damage(b, worm, 50.0, true, BoardCombat.solo(1), [])
	check(is_equal_approx(worm.hp, hp), "ni touché")
	_run(b, 2.1)
	check(not worm.marks.burrowed, "ressorti après 2 s")


func test_brood_by_steps_and_by_time() -> void:
	var b := _board()
	var hydra := _still(b, "hydra", 8.0)
	hydra.hp = hydra.max_hp * 0.5
	_run(b, DT * 2)
	check(b.monsters.filter(func(x: SimMonster) -> bool: return x.type == "hydra_head").size() == 1, "une tête par tiers de PV perdu")
	var c := _board()
	_still(c, "spider", 8.0)
	_run(c, 4.1)
	check(c.monsters.filter(func(x: SimMonster) -> bool: return x.type == "spiderling").size() == 1, "une araignée naine toutes les 4 s")


func test_necromancer_raises_the_dead() -> void:
	var b := _board()
	_still(b, "necromancer", 8.0)
	var goblin := _still(b, "goblin", 8.5)
	BoardCombat.damage(b, goblin, 100.0, true, BoardCombat.solo(1), [])
	_run(b, 5.1)
	check(b.monsters.any(func(x: SimMonster) -> bool: return x.type == "skeleton"), "le gobelin revient en squelette")


func test_burrowed_flag_reaches_clients() -> void:
	var gd := load_data()
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]])
	var worm := sim.boards[0].spawn("sandworm", 1.0, 0, 3.0)
	worm.marks.burrowed = true
	var view := ViewState.new(gd, sim.map, 1)
	var snap := sim.snapshot()
	snap["speed"] = 1
	snap["iv"] = 0.1
	check(view.apply(snap), "instantané accepté")
	var seen: Dictionary = view.boards[0]["monsters"].values()[0]
	check(seen.get("burrowed", false), "le client voit le ver enfoui")

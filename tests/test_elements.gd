extends "res://tests/test_base.gd"
## Tourelles élémentaires : onde, trait, souffle, rayon, nappes au sol, bonus contre les
## monstres gelés, armure rongée, poison contagieux, coups critiques, et leur transmission.

const DT := 0.05
const AT := Vector2(5, 5)


func _board() -> SimBoard:
	var gd := load_data()
	return SimBoard.new(gd, gd.maps[0], 20)


## Tourelle posée sur la première case libre, puis déplacée en `at` (géométrie maîtrisée).
func _tower(b: SimBoard, type: String, level := 0, at := AT) -> SimTower:
	var cell := 0
	while not b.can_build(cell):
		cell += 1
	var t := b.add_tower(cell, type, 7, 0)
	t.level = level
	b.refresh_stats(t)
	t.center = at
	return t


## Monstre immobile placé en `at`.
func _mob(b: SimBoard, type: String, at: Vector2) -> SimMonster:
	var m := b.spawn(type, 1.0, 0, 1.0)
	m.speed = 0.0
	m.pos = at
	return m


func _fire(b: SimBoard, t: SimTower) -> void:
	t.cooldown = 0.0
	BoardCombat.fire_towers(b, 0.001, [])


func test_pylon_pulse_hits_everything_around() -> void:
	var b := _board()
	var t := _tower(b, "pylon")  # 6 dégâts, portée 1,6
	var near := _mob(b, "goblin", AT + Vector2(0.5, 0))
	var bat := _mob(b, "bat", AT + Vector2(0, 1))
	var far := _mob(b, "goblin", AT + Vector2(3, 0))
	_fire(b, t)
	check(is_equal_approx(near.hp, 6.0) and is_equal_approx(bat.hp, 10.0), "sol et air touchés : %f / %f" % [near.hp, bat.hp])
	check(is_equal_approx(far.hp, 12.0), "hors de portée : intact")


func test_obelisk_slows_without_damage() -> void:
	var b := _board()
	var t := _tower(b, "obelisk")
	var orc := _mob(b, "orc", AT + Vector2(1, 0))
	var bat := _mob(b, "bat", AT + Vector2(0, -1))
	_fire(b, t)
	check(orc.is_slowed() and bat.is_slowed(), "ralentis, volant compris")
	check(is_equal_approx(orc.hp, 40.0), "aucun dégât : %f" % orc.hp)


func test_railgun_line_pierces_monsters_and_armor() -> void:
	var b := _board()
	var t := _tower(b, "railgun")  # 16 dégâts, la moitié de l'armure ignorée, portée 4
	var first := _mob(b, "skeleton", AT + Vector2(1, 0))  # armure 3, 30 PV
	var second := _mob(b, "skeleton", AT + Vector2(2, 0))
	var third := _mob(b, "skeleton", AT + Vector2(3.5, 0.2))
	var aside := _mob(b, "skeleton", AT + Vector2(2, 1.5))
	var beyond := _mob(b, "skeleton", AT + Vector2(4.5, 0))
	_fire(b, t)
	for m in [first, second, third]:
		check(is_equal_approx(m.hp, 30.0 - (16.0 - 1.5)), "aligné : 16 - 1,5 d'armure (%f)" % m.hp)
	check(is_equal_approx(aside.hp, 30.0) and is_equal_approx(beyond.hp, 30.0), "hors du trait : intacts")


func test_salamander_cone_burns_in_front_only() -> void:
	var b := _board()
	var t := _tower(b, "salamander")  # portée 1,6, cône de 100°
	var target := _mob(b, "goblin", AT + Vector2(1, 0))
	var beside := _mob(b, "goblin", AT + Vector2(1, 0.6))
	var behind := _mob(b, "goblin", AT + Vector2(-1, 0))
	_fire(b, t)
	check(target.is_burning() and beside.is_burning(), "le groupe devant s'enflamme")
	check(not behind.is_burning() and is_equal_approx(behind.hp, 12.0), "derrière : intact")


func test_lens_beam_heats_up_and_resets_on_new_target() -> void:
	var b := _board()
	var t := _tower(b, "lens")  # 1,2 dégât, +20 % par coup sur la même cible
	var first := _mob(b, "orc", AT + Vector2(1, 0))
	var second := _mob(b, "orc", AT + Vector2(0, 1.5))
	for k in 3:
		_fire(b, t)
	check(is_equal_approx(first.hp, 40.0 - 1.2 * (1.0 + 1.2 + 1.4)), "chauffe : 1,2 + 1,44 + 1,68 (%f)" % first.hp)
	check(is_equal_approx(second.hp, 40.0), "le rayon reste accroché à sa cible")
	first.pos = AT + Vector2(20, 0)  # sort de portée
	_fire(b, t)
	check(is_equal_approx(second.hp, 40.0 - 1.2), "nouvelle cible : la chaleur repart de zéro (%f)" % second.hp)


func test_greek_fire_leaves_burning_patch_on_the_ground() -> void:
	var b := _board()
	var t := _tower(b, "greek_fire")  # 8 dégâts en zone, nappe de 5 dégâts/s pendant 3 s
	var orc := _mob(b, "orc", AT + Vector2(2, 0))
	_fire(b, t)
	t.cooldown = 100.0
	var bat := _mob(b, "bat", AT + Vector2(2, 0))
	for k in 100:
		if b.projectiles.is_empty():
			break
		BoardCombat.move_projectiles(b, DT, [])
	check(b.patches.size() == 1, "une nappe posée")
	check(is_equal_approx(orc.hp, 32.0), "impact : 8 dégâts (%f)" % orc.hp)
	for k in int(1.0 / DT) + 1:
		BoardPatches.update(b, DT, [])
	check(is_equal_approx(orc.hp, 27.0), "1 s dans la nappe : 5 dégâts de plus (%f)" % orc.hp)
	check(is_equal_approx(bat.hp, 16.0), "les volants passent au-dessus")
	for k in int(2.5 / DT):
		BoardPatches.update(b, DT, [])
	check(b.patches.is_empty(), "la nappe s'éteint")


func test_icebreaker_hits_harder_slowed_and_frozen() -> void:
	var b := _board()
	var t := _tower(b, "icebreaker")  # 9 dégâts, +60 % ralenti, +100 % gelé
	var def: Dictionary = b.data.towers["icebreaker"]
	var normal := _mob(b, "orc", AT)
	var slowed := _mob(b, "orc", AT)
	var frozen := _mob(b, "orc", AT)
	slowed.apply_slow(0.5, 3.0)
	frozen.apply_control(SimMonster.Crowd.STUN, 1.0, 1)
	for m in [normal, slowed, frozen]:
		BoardCombat.hit(b, m, BoardCombat.shot(b, t, def), 9.0, [])
	check(is_equal_approx(normal.hp, 31.0), "normal : 9 (%f)" % normal.hp)
	check(is_equal_approx(slowed.hp, 40.0 - 14.4), "ralenti : 14,4 (%f)" % slowed.hp)
	check(is_equal_approx(frozen.hp, 22.0), "gelé : 18 (%f)" % frozen.hp)


func test_acid_shreds_armor_for_a_while() -> void:
	var b := _board()
	var m := _mob(b, "skeleton", AT)  # armure 3
	m.apply_shred(0.5, 2.0)
	BoardCombat.damage(b, m, 4.0, false, BoardCombat.solo(7), [])
	check(is_equal_approx(m.hp, 27.5), "armure rongée de moitié : 4 - 1,5 (%f)" % m.hp)
	for k in int(2.1 / DT):
		MonsterEffects.update(b, DT, [])
	BoardCombat.damage(b, m, 4.0, false, BoardCombat.solo(7), [])
	check(is_equal_approx(m.hp, 26.5), "l'armure revient : 4 - 3 (%f)" % m.hp)


func test_plague_spreads_to_neighbours_in_reach() -> void:
	var b := _board()
	var sick := _mob(b, "orc", AT)
	var near := _mob(b, "orc", AT + Vector2(0.8, 0))
	var far := _mob(b, "orc", AT + Vector2(4, 0))
	sick.apply_poison(3.0, 4.0, 7, 1.2)
	for k in int(1.05 / DT):
		MonsterEffects.update(b, DT, [])
	check(near.is_poisoned() and near.poison_spread > 0.0, "le voisin est contaminé (et contagieux)")
	check(near.poison_timer < 3.1, "avec la durée restante : %f" % near.poison_timer)
	check(not far.is_poisoned(), "le monstre éloigné est épargné")


func test_scythe_crits_every_third_blow() -> void:
	var b := _board()
	var t := _tower(b, "scythe")  # 5 dégâts, critique ×2,5 un coup sur 3
	var def: Dictionary = b.data.towers["scythe"]
	var hits := []
	for k in 6:
		hits.append(BoardCombat.shot(b, t, def).stat("damage"))
	check(hits == [5.0, 5.0, 12.5, 5.0, 5.0, 12.5], "coups : %s" % str(hits))


func test_lower_burn_cap_keeps_existing_stacks() -> void:
	var b := _board()
	var m := _mob(b, "troll", AT)
	for k in 6:
		m.apply_burn(2.0, 3.0, 6, 1)
	m.apply_burn(1.5, 2.5, 3, 2)
	check(m.burn_stacks == 6, "6 charges gardées : %d" % m.burn_stacks)


func test_every_tower_can_be_unlocked() -> void:
	var gd := load_data()
	var reachable := {}
	for id in gd.common_towers:
		reachable[id] = true
	for builder in gd.builders:
		for id in builder["towers"]:
			reachable[id] = true
		for branch in builder["branches"]:
			for talent in branch["talents"]:
				if talent["unlock"] != "":
					reachable[talent["unlock"]] = true
	for id in gd.tower_order:
		check(reachable.has(id), "« %s » n'est accessible à aucune classe" % id)


func test_snapshot_carries_patches_and_new_fx() -> void:
	var gd := load_data()
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]])
	var b := sim.boards[0]
	var t := _tower(b, "miasma")
	BoardPatches.add(b, BoardCombat.shot(b, t, gd.towers["miasma"]))
	b.add_fx(SimBoard.Fx.WAVE, Vector2(2, 2), Vector2.ZERO, 1.5, gd.tower_order.find("pylon"))
	b.add_fx(SimBoard.Fx.CONE, Vector2(2, 2), Vector2(3, 2))
	b.add_fx(SimBoard.Fx.BEAM, Vector2(2, 2), Vector2(4, 3))
	var view := ViewState.new(gd, sim.map, 1)
	var snap := sim.snapshot()
	check(view.apply(snap), "instantané accepté")
	var vb: Dictionary = view.boards[0]
	check(vb["patches"].size() == 1 and vb["patches"][0]["type"] == "miasma", "nappe transmise")
	var kinds: Array = vb["fx"].map(func(f: Dictionary) -> int: return f["kind"])
	check(kinds == [SimBoard.Fx.WAVE, SimBoard.Fx.CONE, SimBoard.Fx.BEAM], "effets transmis : %s" % str(kinds))
	check(vb["fx"][0]["tint"] == gd.tower_order.find("pylon"), "teinte de l'onde transmise")
	snap["b"][0]["fx"][0][4] = 999
	check(not ViewState.new(gd, sim.map, 1).apply(snap), "teinte inconnue refusée")
	snap["b"][0]["fx"][0][4] = 0
	snap["b"][0]["z"][0][4] = -1
	check(not ViewState.new(gd, sim.map, 1).apply(snap), "nappe d'une tourelle inconnue refusée")

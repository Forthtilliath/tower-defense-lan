extends "res://tests/test_base.gd"
## Moteur de combat : brûlure, saignement, contrôles (étourdi, peur, charme), résistance des
## boss, auras de soutien, partage des primes selon la contribution, économie des classes.

const DT := 0.05


func _board() -> SimBoard:
	var gd := load_data()
	return SimBoard.new(gd, gd.maps[0], 20)


func _monster(b: SimBoard, type: String, progress := 10.0, moving := false) -> SimMonster:
	var m := b.spawn(type, 1.0, 0, progress)
	if not moving:
		m.speed = 0.0
	return m


func _shot(stats: Dictionary, owner := 7) -> SimProjectile:
	var p := SimProjectile.new()
	p.stats = stats
	p.credit = BoardCombat.solo(owner)
	p.owner = owner
	return p


func _hit(b: SimBoard, m: SimMonster, p: SimProjectile, rewards := []) -> void:
	p.target_id = m.id
	p.pos = m.pos
	p.target_pos = m.pos
	b.projectiles.append(p)
	BoardCombat.move_projectiles(b, DT, rewards)


func _builder(gd: GameData, id: String) -> int:
	for i in gd.builders.size():
		if gd.builders[i]["id"] == id:
			return i
	return -1


func test_burn_stacks_and_ignores_armor() -> void:
	var b := _board()
	var m := _monster(b, "skeleton")  # armure 3
	for i in 3:
		_hit(b, m, _shot({"burn_dps": 2.0, "burn_duration": 3.0, "burn_stacks": 2}))
	check(m.burn_stacks == 2, "charges plafonnées à 2 : %d" % m.burn_stacks)
	var before := m.hp
	MonsterEffects.update(b, 1.0, [])
	check(is_equal_approx(before - m.hp, 4.0), "2 charges x 2/s, sans armure : %f" % (before - m.hp))


func test_bleed_scales_with_max_hp_and_bosses_resist() -> void:
	var b := _board()
	var orc := _monster(b, "orc")
	var lich := _monster(b, "lich", 20.0)
	lich.regen = 0.0
	for m in [orc, lich]:
		m.apply_bleed(0.1, 5.0, 3)
	MonsterEffects.update(b, 1.0, [])
	check(is_equal_approx(orc.max_hp - orc.hp, 4.0), "10 %% des PV max par seconde : %f" % (orc.max_hp - orc.hp))
	var expected: float = lich.max_hp * 0.1 * (1.0 - 0.7 * MonsterEffects.BLEED_RESIST)
	check(is_equal_approx(lich.max_hp - lich.hp, expected), "la liche résiste en partie : %f" % (lich.max_hp - lich.hp))


func test_stun_stops_and_guard_prevents_chains() -> void:
	var b := _board()
	var m := _monster(b, "goblin", 10.0, true)
	check(m.apply_control(SimMonster.Crowd.STUN, 1.0, 1) > 0.0, "étourdi")
	m.move(0.5)
	check(is_equal_approx(m.progress, 10.0), "immobile pendant l'étourdissement")
	m.move(0.6)
	check(m.apply_control(SimMonster.Crowd.STUN, 1.0, 1) == 0.0, "immunité juste après")
	m.move(1.0)
	check(m.progress > 10.0 and m.apply_control(SimMonster.Crowd.STUN, 1.0, 1) > 0.0, "repart, puis de nouveau contrôlable")


func test_fear_walks_back_and_charm_fights() -> void:
	var b := _board()
	var feared := _monster(b, "goblin", 10.0, true)
	feared.apply_control(SimMonster.Crowd.FEAR, 1.0, 1)
	feared.move(1.0)
	check(feared.progress < 10.0, "la peur fait reculer : %f" % feared.progress)
	var charmed := _monster(b, "orc", 15.0)
	var victim := _monster(b, "goblin", 15.3)
	charmed.apply_control(SimMonster.Crowd.CHARM, 3.0, 5)
	var rewards := []
	MonsterEffects.update(b, 1.0, rewards)
	check(victim.hp < victim.max_hp, "le monstre charmé frappe son voisin")
	check(BoardCombat.find_target(b, _tower_at(b, 15.0), b.data.towers["crossbow"]) != charmed, "les tourelles ignorent le monstre charmé")
	check(victim.contrib.get(5, 0.0) > 0.0, "ses coups sont crédités au charmeur")


func _tower_at(b: SimBoard, progress: float) -> SimTower:
	var t := SimTower.new()
	t.center = b.map.position_at(0, progress, false)
	t.stats = {"range": 3.0}
	t.owner = 1
	return t


func test_bosses_resist_controls() -> void:
	var b := _board()
	var lich := _monster(b, "lich")
	check(is_equal_approx(lich.apply_control(SimMonster.Crowd.STUN, 1.0, 1), 0.3), "étourdissement réduit de 70 %")
	var golem := _monster(b, "golem", 20.0)
	check(golem.apply_control(SimMonster.Crowd.CHARM, 2.0, 1) == 0.0, "le golem ne se laisse pas charmer")
	var bat := _monster(b, "bat", 25.0)
	check(bat.apply_control(SimMonster.Crowd.CHARM, 2.0, 1) == 0.0, "les volants non plus")


func test_auras_buff_neighbours_and_share_credit() -> void:
	var gd := load_data()
	var b := SimBoard.new(gd, gd.maps[0], 20)
	var w := gd.maps[0].width
	var shooter := b.add_tower(2 * w + 2, "crossbow", 1, 50)
	b.add_tower(2 * w + 3, "banner", 2, 100)
	b.add_tower(3 * w + 6, "drum", 3, 90)  # trop loin
	check(is_equal_approx(shooter.buff("damage"), 0.12) and shooter.buff("rate") == 0.0, "étendard voisin seulement")
	check(is_equal_approx(BoardAuras.effective_stats(shooter)["damage"], 4.0 * 1.12), "dégâts renforcés")
	var credit := BoardAuras.credit(shooter)
	var shares := {}
	for c in credit:
		shares[c[0]] = c[1]
	check(is_equal_approx(shares[2], 0.12 / 1.12) and is_equal_approx(shares[1], 1.0 / 1.12), "crédit partagé : %s" % str(credit))
	b.add_tower(2 * w + 1, "banner", 4, 100)
	b.towers[2 * w + 1].level = 2
	b.refresh_stats(b.towers[2 * w + 1])
	check(is_equal_approx(shooter.buff("damage"), 0.2) and shooter.buffs["damage"][1] == 4, "seule la plus forte aura compte")
	b.remove_tower(2 * w + 1)
	check(is_equal_approx(shooter.buff("damage"), 0.12), "aura retirée à la vente")


func test_bounty_split_by_contribution() -> void:
	check(Bounty.split(10, {1: 30.0, 2: 10.0}, 1) == [[1, 8], [2, 2]] or Bounty.split(10, {1: 30.0, 2: 10.0}, 1) == [[1, 7], [2, 3]], "au prorata")
	var total := 0
	for s in Bounty.split(7, {1: 1.0, 2: 1.0, 3: 1.0}, 1):
		total += s[1]
	check(total == 7, "aucun or perdu ni créé")
	check(Bounty.split(5, {}, 9) == [[9, 5]], "sans contribution : prime entière au tueur")
	var b := _board()
	var m := _monster(b, "orc")  # 7 or
	var p := _shot({"damage": 0.0, "stun_chance": 1.0, "stun_duration": 2.0}, 2)
	_hit(b, m, p)
	var rewards := []
	BoardCombat.damage(b, m, 1000.0, false, BoardCombat.solo(1), rewards)
	var by := {}
	for r in rewards:
		by[r[0]] = r[1]
	check(by.get(2, 0) > 0 and by.get(1, 0) > by.get(2, 0), "le contrôleur touche une part, le tueur la plus grosse : %s" % str(rewards))


func test_goblin_economy() -> void:
	var gd := load_data()
	var goblin := _builder(gd, "goblin")
	check(MatchFlow.interest(gd, 500, PlayerKit.make(gd, goblin)) == 30 and MatchFlow.interest(gd, 2000, PlayerKit.make(gd, goblin)) == 50, "6 %% d'intérêts, plafond 50")
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0, 0], [2, "G", 1, goblin]])
	sim._credit_bounty(1, 20)
	sim._credit_bounty(2, 20)
	check(sim.players[1]["gold"] == 170 and sim.players[2]["gold"] == 175, "+25 %% sur ses primes : %d / %d" % [sim.players[1]["gold"], sim.players[2]["gold"]])


func test_enchanter_boosts_controls() -> void:
	var gd := load_data()
	var enchanter := _builder(gd, "enchanter")
	var base := gd.tower_stats("gong", 0)
	var boosted := gd.tower_stats("gong", 0, -1, enchanter)
	check(is_equal_approx(boosted["stun_chance"], base["stun_chance"] * 1.3), "chance +30 %")
	check(is_equal_approx(boosted["stun_duration"], base["stun_duration"] * 1.3), "durée +30 %")
	check(is_equal_approx(boosted["damage"], base["damage"]), "dégâts inchangés")


func test_snapshot_carries_controls_and_auras() -> void:
	var gd := load_data()
	# Artilleur avec le Tambour débloqué (Discipline 3, Étendard, Tambour)
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0, 1, {"gu_drill": 3, "gu_banner": 1, "gu_drum": 1}]])
	var b := sim.boards[0]
	var w := sim.map.width
	sim.apply_command(1, {"a": "build", "cell": 2 * w + 2, "tower": "crossbow"})
	sim.apply_command(1, {"a": "build", "cell": 2 * w + 3, "tower": "drum"})
	var m := _monster(b, "orc")
	m.apply_burn(1.0, 3.0, 2, 1)
	m.apply_control(SimMonster.Crowd.FEAR, 2.0, 1)
	var view := ViewState.new(gd, sim.map, 1)
	check(view.apply(sim.snapshot()), "instantané accepté")
	var vm: Dictionary = view.boards[0]["monsters"][m.id]
	check(vm["burning"] and vm["feared"] and not vm["stunned"], "brûlure et peur transmises")
	check(view.boards[0]["towers"][2 * w + 2]["buffs"] == 2, "aura de cadence transmise")

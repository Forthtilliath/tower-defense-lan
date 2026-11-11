extends "res://tests/unit/test_base.gd"
## Effets des talents sur les coups (BoardFeats) : critique, exécution, perforation, ricochet,
## marque, armure brisée, recul, onde et éclats à la mort, gros monstres, réactions, résonance,
## contagion à la mort, échauffement, série.

const DT := 0.05


func _board() -> SimBoard:
	var gd := load_data()
	return SimBoard.new(gd, gd.maps[0], 20)


## Monstre immobile sur le chemin 0, avec des PV et une armure fixés (tests lisibles).
func _monster(b: SimBoard, progress := 10.0, hp := 100.0, armor := 0.0) -> SimMonster:
	var m := b.spawn("goblin", 1.0, 0, progress)
	m.speed = 0.0
	m.max_hp = hp
	m.hp = hp
	m.armor = armor
	m.pos = b.map.position_at(0, progress, false)
	return m


## Coup d'une tourelle « nue » (statistiques de base nulles) avec les effets donnés.
func _shot(b: SimBoard, extra: Dictionary, element := "") -> SimProjectile:
	var p := SimProjectile.new()
	p.stats = b.data.tower_levels("crossbow")[0].duplicate()
	for key in extra:
		p.stats[key] = extra[key]
	p.element = element
	p.credit = BoardCombat.solo(7)
	p.owner = 7
	return p


func _hit(b: SimBoard, m: SimMonster, p: SimProjectile, rewards := []) -> void:
	p.target_id = m.id
	p.pos = m.pos
	p.target_pos = m.pos
	b.projectiles.append(p)
	BoardCombat.move_projectiles(b, DT, rewards)


func test_crit_multiplies_damage() -> void:
	var b := _board()
	var m := _monster(b)
	_hit(b, m, _shot(b, {"damage": 10.0, "crit_chance": 1.0, "crit_bonus": 1.0}))
	check(is_equal_approx(m.hp, 70.0), "critique ×3 : %f" % m.hp)


func test_execute_finishes_weak_monsters() -> void:
	var b := _board()
	var m := _monster(b)
	_hit(b, m, _shot(b, {"damage": 85.0, "execute": 0.2}))
	check(not m.is_alive(), "achevé sous 20 %% de PV : %f" % m.hp)
	var big := _monster(b, 12.0, 1000.0)
	_hit(b, big, _shot(b, {"damage": 850.0, "execute": 0.2}))
	check(big.is_alive(), "un gros monstre n'est achevé que sous 10 %%")


func test_pierce_and_ricochet_hit_neighbours() -> void:
	var b := _board()
	var m := _monster(b)
	var behind := _monster(b, 10.4)
	var far := _monster(b, 14.0)
	_hit(b, m, _shot(b, {"damage": 10.0, "pierce": 1}))
	check(is_equal_approx(behind.hp, 90.0) and is_equal_approx(far.hp, 100.0), "perforation : le voisin seul (%f, %f)" % [behind.hp, far.hp])
	_hit(b, m, _shot(b, {"damage": 10.0, "ricochet": 1.0}))
	check(is_equal_approx(behind.hp, 80.0), "ricochet sur le voisin : %f" % behind.hp)


func test_mark_makes_every_tower_hit_harder() -> void:
	var b := _board()
	var m := _monster(b)
	_hit(b, m, _shot(b, {"damage": 10.0, "mark": 0.5}))
	_hit(b, m, _shot(b, {"damage": 10.0}))
	check(is_equal_approx(m.hp, 100.0 - 15.0 - 15.0), "marqué : +50 %% sur chaque coup (%f)" % m.hp)


func test_armor_break_stacks_to_its_cap() -> void:
	var b := _board()
	var m := _monster(b, 10.0, 1000.0, 4.0)
	for i in 3:
		_hit(b, m, _shot(b, {"damage": 10.0, "armor_break": 2}))
	check(m.marks.armor_down == 2 and is_equal_approx(m.armor_against(0.0), 2.0), "armure brisée de 2 au plus : %d" % m.marks.armor_down)


func test_knockback_pushes_back() -> void:
	var b := _board()
	var m := _monster(b)
	_hit(b, m, _shot(b, {"damage": 1.0, "knockback": 1.0}))
	check(is_equal_approx(m.progress, 10.0 - BoardFeats.KNOCKBACK), "repoussé : %f" % m.progress)


func test_kill_splash_and_shards() -> void:
	var b := _board()
	var m := _monster(b, 10.0, 5.0)
	var next := _monster(b, 10.4)
	_hit(b, m, _shot(b, {"damage": 10.0, "kill_splash": 0.5, "frag": 0.5}))
	check(is_equal_approx(next.hp, 90.0), "onde (5) et éclat (5) sur le voisin : %f" % next.hp)


func test_big_monsters_and_fire_reaction() -> void:
	var b := _board()
	var big := _monster(b, 10.0, 1000.0)
	_hit(b, big, _shot(b, {"damage": 10.0, "vs_big": 1.0}))
	check(is_equal_approx(big.hp, 980.0), "gros monstre : ×2 (%f)" % big.hp)
	var m := _monster(b, 14.0)
	m.apply_slow(0.5, 5.0)
	_hit(b, m, _shot(b, {"damage": 10.0, "reaction": 0.5}, "fire"))
	check(m.hp <= 85.0 + 0.01, "feu sur un ralenti : ×1,5 (%f)" % m.hp)


func test_resonance_lowers_resistances() -> void:
	var b := _board()
	var m := _monster(b)
	m.element_taken["fire"] = 0.5
	_hit(b, m, _shot(b, {"damage": 10.0, "resonance": 0.5}, "fire"))
	check(is_equal_approx(m.hp, 92.5), "résistance de 50 %% réduite de moitié : %f" % m.hp)


func test_burn_spreads_on_death() -> void:
	var b := _board()
	var m := _monster(b, 10.0, 5.0)
	var next := _monster(b, 10.4)
	m.apply_burn(2.0, 5.0, 3, 7)
	_hit(b, m, _shot(b, {"damage": 10.0, "death_burn": 1}))
	check(next.is_burning(), "le voisin prend feu à la mort")
	check(int(next.marks.death_spread.get("burn", 0)) == 1, "et transmettra à son tour")


func test_warmup_and_streak() -> void:
	var b := _board()
	var t := b.add_tower(2 * b.map.width + 2, "crossbow", 7, 50)
	t.stats["warmup"] = 0.1
	t.stats["warmup_cap"] = 0.5
	var first := BoardFeats.next_delay(t, 1.0)
	t.warm = 10.0
	check(is_equal_approx(first, 1.0) and is_equal_approx(BoardFeats.next_delay(t, 1.0), 1.0 / 1.5), "échauffement plafonné à +50 %%")
	t.stats["streak"] = 0.05
	t.stats["streak_cap"] = 0.2
	t.kills = 10
	var p := BoardCombat.shot(b, t, b.data.towers["crossbow"])
	check(is_equal_approx(p.stats["damage"], float(t.stats["damage"]) * 1.2), "série plafonnée à +20 %%")
	_monster(b)
	BoardFeats.reset_streaks(b)
	check(t.kills == 10, "série gardée tant que la carte n'est pas vide")


func test_slow_and_longer_effects() -> void:
	var b := _board()
	var m := _monster(b)
	_hit(b, m, _shot(b, {"damage": 1.0, "slow": 0.3, "poison_dps": 1.0, "poison_duration": 2.0, "dot_duration": 1.0}))
	check(m.is_slowed() and is_equal_approx(m.slow_factor, 0.7), "ralenti de 30 %% : %f" % m.slow_factor)
	check(m.poison_timer > 3.9, "poison deux fois plus long : %f" % m.poison_timer)


func test_last_stand_growth_and_harmony() -> void:
	var b := _board()
	var w := b.map.width
	var kit := PlayerKit.make(b.data, 0)
	var t := b.add_tower(2 * w + 2, "crossbow", 7, 50, kit)
	t.stats["last_stand"] = 1.0
	check(is_equal_approx(BoardFeats.next_delay(t, 1.0, 20), 1.0) and is_equal_approx(BoardFeats.next_delay(t, 1.0, 3), 0.5), "dernier rempart : cadence ×2 à 3 vies")
	b.add_tower(2 * w + 3, "brazier", 7, 50, kit)
	b.add_tower(3 * w + 2, "frost", 7, 50, kit)
	b.add_tower(3 * w + 3, "tesla", 8, 50)
	check(BoardLayout.elements_around(b, t) == 2, "harmonie : feu et glace voisins, pas la Tesla d'un allié")
	t.stats["growth"] = 0.1
	t.stats["harmony"] = 0.1
	kit.clean_waves = 5
	var p := BoardCombat.shot(b, t, b.data.towers["crossbow"])
	check(is_equal_approx(p.stats["damage"], float(t.stats["damage"]) * 1.5 * 1.2), "croissance ×1,5 et harmonie ×1,2")


func test_static_charge_and_storm() -> void:
	var b := _board()
	var m := _monster(b, 10.0, 1000.0)
	var next := _monster(b, 10.4, 1000.0)
	for i in BoardFeats.STATIC_HITS:
		_hit(b, m, _shot(b, {"damage": 10.0, "static_charge": 1.0}, "lightning"))
	check(is_equal_approx(next.hp, 990.0), "décharge sur le voisin au 5e coup : %f" % next.hp)
	var t := b.add_tower(2 * b.map.width + 2, "tesla", 7, 90)
	t.stats["storm"] = 2.0
	var target := _monster(b, 1.0, 1000.0)
	target.pos = t.center + Vector2(0.5, 0.0)
	t.storm_clock = BoardFeats.STORM_PERIOD
	BoardFeats.storm(b, t, b.data.towers["tesla"], 0.01, [])
	check(target.hp < 1000.0 and t.storm_clock == 0.0, "éclair gratuit de l'Orage : %f" % target.hp)


func test_conditional_bonuses() -> void:
	var b := _board()
	var tank := _monster(b, 10.0, 1000.0, 3.0)
	_hit(b, tank, _shot(b, {"damage": 13.0, "vs_armored": 1.0, "armor_pierce": 1.0}))
	check(is_equal_approx(tank.hp, 974.0), "blindé : ×2 (%f)" % tank.hp)
	var sick := _monster(b, 14.0)
	sick.apply_poison(1.0, 5.0, 7)
	sick.apply_slow(0.5, 5.0)
	_hit(b, sick, _shot(b, {"damage": 10.0, "vs_afflicted": 1.0}))
	check(is_equal_approx(sick.hp, 80.0), "sous deux effets : ×2 (%f)" % sick.hp)
	var weak := _monster(b, 18.0)
	weak.hp = 20.0
	_hit(b, weak, _shot(b, {"damage": 5.0, "vs_wounded": 1.0}))
	check(is_equal_approx(weak.hp, 10.0), "blessé : ×2 (%f)" % weak.hp)
	var fast := _monster(b, 22.0)
	fast.speed = 2.0
	check(is_equal_approx(BoardFeats.bleed_of(fast, _shot(b, {"bleed": 0.01, "vs_fast": 0.5})), 0.02), "saignement ×2 sur un monstre de vitesse 2")


func test_puddle_and_all_targets() -> void:
	var b := _board()
	var m := _monster(b, 10.0, 5.0)
	m.apply_poison(1.0, 5.0, 7)
	_hit(b, m, _shot(b, {"damage": 10.0, "death_puddle": 0.1}))
	check(b.patches.size() == 1, "flaque laissée à la mort d'un empoisonné")
	var t := b.add_tower(2 * b.map.width + 2, "cannon", 7, 90)
	t.stats["all_targets"] = 1
	var p := BoardCombat.shot(b, t, b.data.towers["cannon"])
	check(p.hits_air and p.hits_ground, "le Canon vise aussi l'air")
extends "res://tests/unit/test_base.gd"
## Talents du Support (BoardSupport) : auras des talents (critique, Vétérans, Ralliement, Charge,
## Garde rapprochée, Sanctuaire, Lumière, Fanfare), effets sur les monstres (affaibli, résistances
## réduites, maléfice, peur contagieuse, contrôles répétés), Esprit d'équipe.

const DT := 0.05


func _board() -> SimBoard:
	var gd := load_data()
	return SimBoard.new(gd, gd.maps[0], 20)


func _monster(b: SimBoard, progress := 10.0) -> SimMonster:
	var m := b.spawn("goblin", 1.0, 0, progress)
	m.speed = 0.0
	m.max_hp = 100.0
	m.hp = 100.0
	m.armor = 0.0
	m.pos = b.map.position_at(0, progress, false)
	return m


func _tower(b: SimBoard, buffs: Dictionary) -> SimTower:
	var t := b.add_tower(2 * b.map.width + 2, "crossbow", 7, 50)
	for kind in buffs:
		t.buffs[kind] = [buffs[kind], 8]
	return t


func test_shot_auras() -> void:
	var b := _board()
	var t := _tower(b, {"crit": 0.3, "veteran": 0.01, "rally": 0.5, "late": 0.4, "stun": 0.1})
	t.kills_total = 100
	b.set_meta("leak_at", b.clock)
	var p := _fire(b, t)
	check(is_equal_approx(p.stat("crit_chance"), 0.3) and is_equal_approx(p.stat("vs_late"), 0.4), "critique et Garde rapprochée transmis")
	check(p.stat("stun_chance") >= 0.1 and p.stat("stun_duration") >= BoardSupport.AURA_STUN, "étourdissement de l'aura")
	var base := float(t.stats["damage"])
	check(is_equal_approx(p.stats["damage"], base * 1.3 * 1.5), "Vétérans plafonné à +30 %%, Ralliement +50 %% : %f" % p.stats["damage"])


func _fire(b: SimBoard, t: SimTower) -> SimProjectile:
	return BoardCombat.shot(b, t, b.data.towers[t.type])


func test_charge_after_wave_start() -> void:
	var b := _board()
	var t := _tower(b, {"charge": 1.0})
	b.set_meta("wave_at", b.clock)
	check(is_equal_approx(BoardSupport.rate_mult(b, t), 2.0), "Charge : cadence ×2 au départ d'une vague")
	b.clock += BoardSupport.CHARGE_TIME + 1.0
	check(is_equal_approx(BoardSupport.rate_mult(b, t), 1.0), "puis plus rien")


func test_monster_marks() -> void:
	var b := _board()
	var m := _monster(b)
	var p := SimProjectile.new()
	p.stats = {"weaken": 1.0, "resist_down": 0.5, "hex": 0.5}
	BoardSupport.mark(m, p, 3.0)
	m.damage = 3
	check(BoardSupport.leak_damage(m) == 2, "affaibli : une vie de moins")
	m.damage = 1
	check(BoardSupport.leak_damage(m) == 1, "au moins une vie")
	m.element_taken["fire"] = 0.5
	var fire := SimProjectile.new()
	fire.element = "fire"
	check(is_equal_approx(BoardFeats.taken(m, fire), 0.75), "résistance au feu réduite de moitié")
	check(is_equal_approx(m.marks.ability_pace(), 0.5), "capacités deux fois plus lentes")
	m.element_taken["pierce"] = 0.0
	var bolt := SimProjectile.new()
	bolt.element = "pierce"
	bolt.stats = {"light": 0.5}
	check(is_equal_approx(BoardFeats.taken(m, bolt), 0.5), "Lumière : un insensible est touché à moitié")


func test_fear_spreads_and_sanctuary() -> void:
	var b := _board()
	var m := _monster(b)
	var next := _monster(b, 10.4)
	m.apply_control(SimMonster.Crowd.FEAR, 2.0, 7)
	var p := SimProjectile.new()
	p.stats = {"fear_spread": 1, "fear_duration": 2.0}
	BoardSupport.after_hit(b, m, p)
	check(next.is_feared(), "la peur gagne le voisin")
	var late := _monster(b, m.length * 0.9 if m.length > 0.0 else 30.0)
	late.progress = late.length * 0.9
	var s := SimProjectile.new()
	s.stats = {"sanctuary": 0.4}
	BoardSupport.after_hit(b, late, s)
	check(late.is_slowed() and is_equal_approx(late.slow_factor, 0.6), "Sanctuaire : ralenti près de la sortie")


func test_repeated_controls_and_nojam() -> void:
	var b := _board()
	var m := _monster(b)
	var p := SimProjectile.new()
	p.stats = {"vs_controlled": 0.5}
	check(is_equal_approx(BoardSupport.control_mult(m, p), 1.0), "jamais contrôlé : chance normale")
	m.marks.controlled = 1
	check(is_equal_approx(BoardSupport.control_mult(m, p), 1.5), "déjà contrôlé : +50 %%")
	var t := _tower(b, {"nojam": 1.0})
	var jammer := _monster(b, 1.0)
	jammer.pos = t.center
	jammer.jam_radius = 2.0
	jammer.jam_interval = 1.0
	jammer.jam_duration = 3.0
	jammer.jam_clock = 1.0
	MonsterAbilities._jam(b, jammer, DT)
	check(not t.is_jammed(), "Fanfare : la tourelle n'est pas brouillée")


func test_team_spirit_scales_auras() -> void:
	var gd := load_data()
	var kit := PlayerKit.make(gd, 3)
	var alone := float(gd.tower_stats("drum", 0, -1, kit)["aura_rate"])
	kit.money = {"team_aura": 0.1}
	kit.allies = 3
	var together := float(gd.tower_stats("drum", 0, -1, kit)["aura_rate"])
	check(is_equal_approx(together, alone * 1.3), "3 alliés : auras +30 %% (%f / %f)" % [together, alone])

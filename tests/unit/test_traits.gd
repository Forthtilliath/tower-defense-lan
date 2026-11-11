extends "res://tests/unit/test_base.gd"
## Bonus des monstres : lévitation, véhicule, résistances aux éléments (et vagues spéciales qui
## les donnent), bonds, protection des voisins, brouillage des tourelles, leurs textes, leur
## validation et leur transmission.

const DT := 0.05
const AT := Vector2(5, 5)


func _board() -> SimBoard:
	var gd := load_data()
	return SimBoard.new(gd, gd.maps[0], 20)


## Tourelle posée sur la première case libre, puis déplacée en `at` (géométrie maîtrisée).
func _tower(b: SimBoard, type: String, at := AT) -> SimTower:
	var cell := 0
	while not b.can_build(cell):
		cell += 1
	var t := b.add_tower(cell, type, 7, 0)
	t.center = at
	BoardAuras.refresh(b)
	return t


## Monstre immobile placé en `at`.
func _mob(b: SimBoard, type: String, at := AT, mod := {}) -> SimMonster:
	var m := b.spawn(type, 1.0, 0, 1.0, true, mod)
	m.speed = 0.0
	m.pos = at
	return m


func _hit(b: SimBoard, m: SimMonster, tower: String, amount: float) -> void:
	var t := _tower(b, tower, AT + Vector2(20, 20))
	BoardCombat.hit(b, m, BoardCombat.shot(b, t, b.data.towers[tower]), amount, [])


func _effects(b: SimBoard, seconds: float) -> void:
	for k in roundi(seconds / DT):
		MonsterEffects.update(b, DT, [])


func _abilities(b: SimBoard, seconds: float) -> void:
	for k in roundi(seconds / DT):
		MonsterAbilities.update(b, DT)


func test_hovering_monster_ignores_ground_patches() -> void:
	var b := _board()
	var t := _tower(b, "greek_fire")  # nappe de 5 dégâts/s
	var wisp := _mob(b, "wisp")
	var goblin := _mob(b, "goblin")
	BoardPatches.add(b, BoardCombat.shot(b, t, b.data.towers["greek_fire"]))
	for k in int(1.0 / DT) + 1:
		BoardPatches.update(b, DT, [])
	check(is_equal_approx(goblin.hp, 7.0), "le gobelin brûle : %f" % goblin.hp)
	check(is_equal_approx(wisp.hp, 12.0), "le feu follet passe au-dessus : %f" % wisp.hp)


func test_vehicle_shrugs_off_dots_fear_and_charm_but_not_stun() -> void:
	var b := _board()
	var cart := _mob(b, "chariot")
	cart.apply_poison(4.0, 4.0, 7)
	cart.apply_burn(2.0, 3.0, 4, 7)
	cart.apply_bleed(0.05, 3.0, 7)
	check(not cart.is_poisoned() and not cart.is_burning() and not cart.is_bleeding(), "ni poison, ni brûlure, ni saignement")
	check(cart.apply_control(SimMonster.Crowd.FEAR, 2.0, 7) == 0.0, "pas de peur")
	check(cart.apply_control(SimMonster.Crowd.CHARM, 2.0, 7) == 0.0, "pas de charme")
	check(cart.apply_control(SimMonster.Crowd.STUN, 1.0, 7) > 0.0, "l'étourdissement marche")
	cart.apply_slow(0.5, 2.0)
	check(cart.is_slowed(), "le ralentissement aussi")


func test_fire_resistance_cuts_hits_and_burn() -> void:
	var b := _board()
	var imp := _mob(b, "imp")  # 28 PV, résiste au feu à 70 %
	var goblin := _mob(b, "goblin", AT + Vector2(0, 1))
	_hit(b, imp, "brazier", 10.0)
	_hit(b, goblin, "crossbow", 10.0)
	check(is_equal_approx(imp.hp, 25.0), "coup de feu réduit à 3 : %f" % imp.hp)
	check(is_equal_approx(goblin.hp, 2.0), "coup physique sur un gobelin : entier")
	_effects(b, 1.0)
	check(absf(imp.hp - 24.25) < 0.01, "brûlure réduite (2,5 × 0,3 par s) : %f" % imp.hp)


func test_ice_resistance_weakens_slows() -> void:
	var b := _board()
	var yeti := _mob(b, "yeti")  # résiste à la glace à 70 %
	var orc := _mob(b, "orc", AT + Vector2(0, 1))
	_hit(b, yeti, "frost", 0.0)
	_hit(b, orc, "frost", 0.0)
	check(absf(yeti.slow_factor - 0.865) < 0.001, "ralenti de 13,5 %% seulement : %f" % yeti.slow_factor)
	check(is_equal_approx(orc.slow_factor, 0.55), "orc ralenti normalement")


func test_lightning_and_all_elements_resistance() -> void:
	var b := _board()
	var gargoyle := _mob(b, "gargoyle")  # 55 PV, armure 2, résiste à la foudre à 70 %
	_hit(b, gargoyle, "tesla", 10.0)
	check(is_equal_approx(gargoyle.hp, 54.0), "10 → 3, puis l'armure : 1 (%f)" % gargoyle.hp)
	var venomed := _mob(b, "warlock")  # 60 PV, résiste à tous les éléments à 50 %
	var shot := _mob(b, "warlock", AT + Vector2(0, 1))
	_hit(b, venomed, "venom", 4.0)
	_hit(b, shot, "crossbow", 4.0)
	check(is_equal_approx(venomed.hp, 58.0) and is_equal_approx(shot.hp, 56.0), "poison réduit, carreau entier : %f / %f" % [venomed.hp, shot.hp])
	_effects(b, 1.0)
	check(absf(venomed.hp - 55.5) < 0.01, "poison continu réduit de moitié (5 → 2,5 par s) : %f" % venomed.hp)


func test_wave_modifier_grants_passive_traits() -> void:
	var b := _board()
	var m := _mob(b, "goblin", AT, {"resist_fire": 0.5, "mechanical": true})
	check(is_equal_approx(m.taken("fire"), 0.5) and is_equal_approx(m.taken("ice"), 1.0), "résistance au feu de la vague")
	check(m.mechanical, "véhicule par la vague")
	var imp := _mob(b, "imp", AT, {"resist_fire": 0.5})
	check(is_equal_approx(imp.taken("fire"), 0.3), "la plus forte résistance l'emporte : %f" % imp.taken("fire"))


func test_shade_blinks_forward_unless_stunned() -> void:
	var b := _board()
	var shade := b.spawn("shade", 1.0, 0, 1.0)  # bond de 2,5 cases toutes les 3 s
	_abilities(b, 2.9)
	check(is_equal_approx(shade.progress, 1.0), "pas encore de bond")
	_abilities(b, 0.15)
	check(absf(shade.progress - 3.5) < 0.01, "bond à 3,5 : %f" % shade.progress)
	check(shade.pos.is_equal_approx(b.map.position_at(0, shade.progress, false)), "position suivie")
	shade.apply_control(SimMonster.Crowd.STUN, 5.0, 7)
	_abilities(b, 3.5)
	check(absf(shade.progress - 3.5) < 0.01, "étourdi : pas de bond (%f)" % shade.progress)


func test_herald_wards_its_neighbours_only() -> void:
	var b := _board()
	var herald := _mob(b, "herald")  # protège à 1,6 case : 35 % de dégâts en moins
	var near := _mob(b, "goblin", AT + Vector2(0.5, 0))
	var far := _mob(b, "goblin", AT + Vector2(4, 0))
	_abilities(b, DT)
	check(is_equal_approx(near.warded, 0.35) and far.warded == 0.0 and herald.warded == 0.0, "voisin protégé, pas lui-même")
	BoardCombat.damage(b, near, 10.0, true, BoardCombat.solo(7), [])
	check(is_equal_approx(near.hp, 5.5), "10 dégâts → 6,5 (%f)" % near.hp)
	herald.hp = 0.0
	_abilities(b, DT)
	check(near.warded == 0.0, "protecteur mort : plus de protection")


func test_saboteur_jams_nearby_towers_for_a_while() -> void:
	var b := _board()
	var near := _tower(b, "crossbow", AT + Vector2(1, 0))
	var far := _tower(b, "crossbow", AT + Vector2(6, 0))
	var sab := _mob(b, "saboteur")  # brouille à 1,8 case pendant 2 s, toutes les 5 s
	_mob(b, "goblin", AT + Vector2(1.5, 0))
	sab.jam_clock = sab.jam_interval
	_abilities(b, DT)
	check(near.is_jammed() and not far.is_jammed(), "seule la tourelle proche est brouillée")
	near.cooldown = 0.0
	BoardCombat.fire_towers(b, 0.001, [])
	check(b.projectiles.is_empty(), "la tourelle brouillée ne tire pas")
	_abilities(b, 2.05)
	check(not near.is_jammed(), "le brouillage s'arrête")
	sab.jam_clock = sab.jam_interval
	_abilities(b, DT)
	check(not near.is_jammed(), "protégée juste après un brouillage")
	_abilities(b, MonsterAbilities.JAM_GUARD)
	sab.jam_clock = sab.jam_interval
	_abilities(b, DT)
	check(near.is_jammed(), "de nouveau brouillable")


func test_jammed_support_drops_its_aura_until_restored() -> void:
	var b := _board()
	var banner := _tower(b, "banner", AT + Vector2(1, 0))  # +12 % de dégâts à 1,6 case
	var bow := _tower(b, "crossbow", AT + Vector2(2.5, 0))
	check(is_equal_approx(bow.buff("damage"), 0.12), "aura reçue")
	var sab := _mob(b, "saboteur")
	sab.jam_clock = sab.jam_interval
	_abilities(b, DT)
	check(banner.is_jammed() and not bow.is_jammed(), "seule la bannière est brouillée")
	check(bow.buff("damage") == 0.0, "plus d'aura pendant le brouillage")
	_abilities(b, 2.05)
	check(is_equal_approx(bow.buff("damage"), 0.12), "l'aura revient")


func test_data_rejects_incomplete_or_endless_abilities() -> void:
	var text := FileAccess.get_file_as_string(GameData.DEFAULT_PATH)
	check(not GameData.from_text(text.replace("\"blink_interval\": 3.0, \"blink_distance\": 2.5", "\"blink_interval\": 3.0")).is_valid(), "bond sans distance refusé")
	check(not GameData.from_text(text.replace("\"jam_duration\": 2.0", "\"jam_duration\": 3.0")).is_valid(), "brouillage trop long refusé")
	check(not GameData.from_text(text.replace("\"element\": \"fire\"", "\"element\": \"water\"")).is_valid(), "élément inconnu refusé")
	check(not GameData.from_text(text.replace("\"resist_ice\": 0.7", "\"resist_ice\": 1.0")).is_valid(), "résistance totale refusée")
	var gd := GameData.from_text(text.replace("\"id\": \"rush\",", "\"id\": \"rush\", \"resist_fire\": 0.5,"))
	check(gd.is_valid() and is_equal_approx(gd.modifiers["rush"]["resist_fire"], 0.5), "vague spéciale avec résistance : " + gd.error)


func test_trait_texts_describe_every_monster() -> void:
	var gd := load_data()
	for id in gd.monster_order:
		MonsterText.traits_text(gd.monsters[id])
	check(MonsterText.traits_text(gd.monsters["goblin"]) == "", "gobelin : rien de spécial")
	check(MonsterText.traits_text(gd.monsters["chariot"]).contains("véhicule"), "véhicule décrit")
	check(MonsterText.traits_text(gd.monsters["imp"]).contains("résiste au feu (70 %)"), "résistance décrite")
	var text := MonsterText.wave_text(gd, gd.waves["w9"])
	check(text.contains("Saboteur : brouille") and text.contains("• Gobelin"), "vague décrite : " + text)
	check(TowerText.stats_text(gd.towers["tesla"], gd.tower_stats("tesla", 0)).contains("élément foudre"), "élément de la tourelle")


func test_snapshot_carries_ward_jam_and_blink() -> void:
	var gd := load_data()
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]])
	var b := sim.boards[0]
	var t := _tower(b, "crossbow", AT + Vector2(1, 0))
	_mob(b, "herald")
	var near := _mob(b, "goblin", AT + Vector2(0.5, 0))
	var sab := _mob(b, "saboteur")
	sab.jam_clock = sab.jam_interval
	b.add_fx(SimBoard.Fx.BLINK, Vector2(2, 2), Vector2(3, 2))
	_abilities(b, DT)
	var view := ViewState.new(gd, sim.map, 1)
	check(view.apply(sim.snapshot()), "instantané accepté")
	var vb: Dictionary = view.boards[0]
	check(vb["monsters"][near.id]["warded"], "protection transmise")
	check(int(vb["towers"][t.cell]["buffs"]) & 8 != 0, "brouillage transmis")
	var kinds: Array = vb["fx"].map(func(f: Dictionary) -> int: return f["kind"])
	check(kinds.has(SimBoard.Fx.BLINK) and kinds.has(SimBoard.Fx.JAM), "bond et brouillage transmis : %s" % str(kinds))
	check(TowerText.buffs_text(8).contains("Brouillée"), "texte du brouillage")

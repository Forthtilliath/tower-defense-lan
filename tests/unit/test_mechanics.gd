extends "res://tests/unit/test_base.gd"
## Mécaniques : armure, poison, division, chaîne, soins, régénération, immunité,
## cases spéciales, difficultés et renforcement coop à plusieurs.

const DT := 0.05


func _board() -> SimBoard:
	var gd := load_data()
	return SimBoard.new(gd, gd.maps[0], 20)


## Fait apparaître un monstre immobile (vitesse nulle) au point `progress` du chemin.
func _monster(b: SimBoard, type: String, progress := 10.0) -> SimMonster:
	var m := b.spawn(type, 1.0, 0, progress)
	m.speed = 0.0
	return m


func _projectile(dmg: float) -> SimProjectile:
	var p := SimProjectile.new()
	p.stats = {"damage": dmg}
	p.credit = BoardCombat.solo(7)
	p.owner = 7
	return p


func test_armor_reduces_but_never_cancels() -> void:
	var b := _board()
	var m := _monster(b, "skeleton")  # armure 3
	m.armor = 3.0  # le squelette en a 1 aujourd’hui ; ce test vise une armure de 3
	var rewards := []
	BoardCombat.damage(b, m, 4.0, false, BoardCombat.solo(7), rewards)
	check(is_equal_approx(m.hp, 29.0), "4 - 3 = 1 dégât : %f" % m.hp)
	BoardCombat.damage(b, m, 2.0, false, BoardCombat.solo(7), rewards)
	check(is_equal_approx(m.hp, 28.5), "au moins 25 %% des dégâts : %f" % m.hp)
	BoardCombat.damage(b, m, 4.0, true, BoardCombat.solo(7), rewards)
	check(is_equal_approx(m.hp, 24.5), "le poison ignore l'armure : %f" % m.hp)


func test_poison_kills_and_rewards_owner() -> void:
	var b := _board()
	var m := _monster(b, "goblin")
	m.apply_poison(10.0, 3.0, 42)
	var rewards := []
	for i in int(2.0 / DT):
		MonsterEffects.update(b, DT, rewards)
	check(not m.is_alive(), "12 PV, 10 dégâts/s pendant 2 s : mort")
	check(rewards.size() == 1 and rewards[0][0] == 42, "prime à l'empoisonneur : %s" % str(rewards))


func test_slime_splits_on_death() -> void:
	var b := _board()
	var m := _monster(b, "slime", 12.0)
	var rewards := []
	BoardCombat.damage(b, m, 1000.0, false, BoardCombat.solo(3), rewards)
	b.step(DT)
	var minis := b.monsters.filter(func(x: SimMonster) -> bool: return x.type == "mini_slime")
	check(minis.size() == 2, "2 petites gelées : %d" % minis.size())
	check(minis.size() == 2 and minis[0].progress > 11.0, "elles repartent d'où la gelée est morte")


func test_tesla_chains_between_monsters() -> void:
	var b := _board()
	var first := _monster(b, "goblin", 5.0)
	var second := _monster(b, "goblin", 6.0)
	var third := _monster(b, "goblin", 7.0)
	var far := _monster(b, "goblin", 20.0)
	var p := _projectile(5.0)
	p.stats["chain"] = 3
	p.target_id = first.id
	p.pos = first.pos
	p.target_pos = first.pos
	b.projectiles.append(p)
	BoardCombat.move_projectiles(b, DT, [])
	check(first.hp < 12.0 and second.hp < 12.0 and third.hp < 12.0, "trois monstres touchés en chaîne")
	check(is_equal_approx(far.hp, 12.0), "le monstre éloigné n'est pas touché")
	check(second.hp > first.hp, "les rebonds font moins mal")


func test_shaman_heals_and_troll_regenerates() -> void:
	var b := _board()
	var shaman := _monster(b, "shaman", 10.0)
	var orc := _monster(b, "orc", 10.5)
	var troll := _monster(b, "troll", 30.0)
	orc.hp = 20.0
	troll.hp = 100.0
	for i in int(1.0 / DT):
		MonsterEffects.update(b, DT, [])
	var healed: float = 20.0 + float(b.data.monsters["shaman"]["heal_rate"]) - 0.5
	check(orc.hp > healed, "l'orc proche est soigné : %f" % orc.hp)
	check(troll.hp > 101.5, "le troll se régénère : %f" % troll.hp)
	check(is_equal_approx(shaman.hp, shaman.max_hp), "le chaman reste à pleine vie")


func test_golem_ignores_slow() -> void:
	var b := _board()
	var golem := _monster(b, "golem")
	golem.apply_slow(0.3, 3.0)
	check(not golem.is_slowed(), "le golem n'est pas ralenti")
	var orc := _monster(b, "orc")
	orc.apply_slow(0.3, 3.0)
	check(orc.is_slowed(), "l'orc est ralenti")


func test_difficulty_changes_lives_gold_and_hp() -> void:
	var gd := load_data()
	var easy := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]], 0)
	var nightmare := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]], 3)
	var de: Dictionary = gd.difficulties[0]
	var dn: Dictionary = gd.difficulties[3]
	check(easy.boards[0].lives == de["lives"] and nightmare.boards[0].lives == dn["lives"], "vies selon la difficulté")
	check(easy.players[1]["gold"] == roundi(150 * de["gold"]) and nightmare.players[1]["gold"] == roundi(150 * dn["gold"]), "or de départ : %d / %d" % [easy.players[1]["gold"], nightmare.players[1]["gold"]])
	check(easy.boards[0].lives > nightmare.boards[0].lives, "plus de vies en Facile")
	for sim in [easy, nightmare]:
		sim.launch_next_wave()
		sim.step(1.0)
	var e: SimMonster = easy.boards[0].monsters[0]
	var n: SimMonster = nightmare.boards[0].monsters[0]
	var base := 12.0 * float(gd.monster_scaling["hp"])
	check(is_equal_approx(e.max_hp, base * de["hp"]) and is_equal_approx(n.max_hp, base * dn["hp"]), "PV : %f / %f" % [e.max_hp, n.max_hp])
	check(n.max_hp > e.max_hp, "monstres plus résistants en Cauchemar")


## Normal sert de référence (PV x1) ; PV, nombre de monstres, armure et XP montent, vies et
## plafond des intérêts baissent, l'or reste le même ; Infernal ne laisse qu'une vie.
func test_difficulty_scale_is_consistent() -> void:
	var gd := load_data()
	check(gd.difficulties[1]["id"] == "normal" and is_equal_approx(gd.difficulties[1]["hp"], 1.0), "Normal à 100 %% des PV")
	for i in range(1, gd.difficulties.size()):
		var prev: Dictionary = gd.difficulties[i - 1]
		var d: Dictionary = gd.difficulties[i]
		check(d["hp"] > prev["hp"] and d["xp"] > prev["xp"] and d["lives"] <= prev["lives"], "%s plus dur que %s" % [d["id"], prev["id"]])
		check(d["count"] > prev["count"] and d["armor"] >= prev["armor"] and d["interest_cap"] <= prev["interest_cap"], "%s : plus de monstres, moins d'intérêts" % d["id"])
		check(is_equal_approx(d["gold"], 1.0) and is_equal_approx(d["reward"], 1.0), "%s : même or partout" % d["id"])
	check(gd.difficulties[-1]["id"] == "infernal" and gd.difficulties[-1]["lives"] == 1, "Infernal : une seule vie")
	var hard := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]], 2)
	check(MatchFlow.interest(gd, 5000, null, hard.difficulty) == int(hard.difficulty["interest_cap"]), "intérêts plafonnés par la difficulté")
	check(MatchFlow.interest_text([0.04, 25]) == "4 % de l'or gardé, 25 or au plus (dès 625 or gardés)", "plafond affiché en or gardé : " + MatchFlow.interest_text([0.04, 25]))
	var infernal := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]], gd.difficulties.size() - 1)
	infernal.launch_next_wave()
	var normal := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]], 1)
	normal.launch_next_wave()
	check(infernal.boards[0]._queue.size() > normal.boards[0]._queue.size(), "plus de monstres en Infernal : %d / %d" % [infernal.boards[0]._queue.size(), normal.boards[0]._queue.size()])


## Coopération, rythme libre : le compte à rebours part dès l'appel d'une vague ; la suivante
## s'appelle tout de suite, contre 1 or par seconde d'avance (une seule vague d'avance).
func test_next_wave_timer_starts_at_call() -> void:
	var gd := load_data()
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]])
	sim.launch_next_wave()
	check(is_equal_approx(sim.countdown, SimMatch.CALL_WINDOW), "30 s dès l'appel : %f" % sim.countdown)
	for i in int(3.0 / DT):
		sim.step(DT)
	check(MatchFlow.can_call(sim) and sim.boards[0].spawns_pending(), "vague suivante appelable pendant la vague")
	var gold: int = sim.players[1]["gold"]
	var interest := MatchFlow.interest(gd, gold, sim.players[1]["kit"], sim.difficulty)
	var wave_gold := int(gd.waves[sim.map.waves[1]]["gold"])
	var ahead := int(sim.countdown)
	sim.apply_command(1, {"a": "ready"})
	var bonus: int = sim.players[1]["gold"] - gold - interest - wave_gold
	check(sim.wave_index == 1 and ahead >= 26 and bonus == ahead, "%d s d'avance : +%d or" % [ahead, bonus])
	check(is_equal_approx(sim.countdown, SimMatch.CALL_WINDOW) and not MatchFlow.can_call(sim), "nouveau décompte, une seule vague d'avance")


func test_coop_scales_with_player_count() -> void:
	var gd := load_data()
	var solo := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]])
	var trio := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0], [2, "B", 1], [3, "C", 2]])
	for sim in [solo, trio]:
		sim.launch_next_wave()
		for i in int(15.0 / DT):
			sim.step(DT)
	var solo_count := solo.boards[0].monsters.size()
	var trio_count := trio.boards[0].monsters.size()
	check(solo_count == 8 and trio_count == 14, "8 gobelins seul, 14 à trois : %d / %d" % [solo_count, trio_count])
	var hp: float = trio.boards[0].monsters[0].max_hp
	check(is_equal_approx(hp, 12.0 * 1.3 * float(gd.monster_scaling["hp"]) * float(trio.difficulty["hp"])), "PV à trois : x1,3 (%f)" % hp)


func test_snapshot_carries_new_effects() -> void:
	var gd := load_data()
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "A", 0]])
	var b := sim.boards[0]
	var m := _monster(b, "orc")
	m.apply_poison(1.0, 5.0, 1)
	m.apply_slow(0.5, 5.0)
	b.add_fx(SimBoard.Fx.BOLT, Vector2(1, 1), Vector2(2, 3))
	var view := ViewState.new(gd, sim.map, 1)
	var snap := sim.snapshot()
	check(view.apply(snap), "instantané accepté")
	var vm: Dictionary = view.boards[0]["monsters"][m.id]
	check(vm["slowed"] and vm["poisoned"], "ralenti et empoisonné transmis")
	check(view.boards[0]["fx"][0]["kind"] == SimBoard.Fx.BOLT, "arc électrique transmis")

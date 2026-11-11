extends "res://tests/unit/test_base.gd"
## Pouvoirs actifs (MatchPowers) : refus (sans talent, avant la partie, en recharge), effets
## instantanés (Séisme, Tir parfait, Météore, Tornade, Curée, Grande parade, Encaissement, Âge
## d'or, Coup de génie, Remodelage) et à durée (Pluie de plomb, Ruée vers l'or, Va-tout, Fléau
## originel, Foudre en chaîne, Remontage), commande réseau.


func _sim(power: String, players := 1) -> SimMatch:
	var roster := [[1, "A", 0]]
	if players > 1:
		roster.append([2, "B", 1])
	var sim := SimMatch.new(load_data(), 0, SimMatch.Mode.COOP, roster)
	sim.players[1]["kit"].power = power
	sim.players[1]["gold"] = 100000
	return sim


func _cell(sim: SimMatch, x: int, y: int) -> int:
	return y * sim.map.width + x


func _monster(b: SimBoard, progress := 10.0) -> SimMonster:
	var m := b.spawn("goblin", 1.0, 0, progress)
	m.speed = 0.0
	m.max_hp = 400.0
	m.hp = 400.0
	m.armor = 0.0
	m.pos = b.map.position_at(0, progress, false)
	return m


func _use(sim: SimMatch, cell := 0) -> String:
	return sim.apply_command(1, {"a": "power", "cell": cell})


func test_refusals_and_cooldown() -> void:
	var sim := _sim("")
	sim.launch_next_wave()
	check(_use(sim) != "", "pas de pouvoir sans talent ultime")
	sim = _sim("tornado")
	check(_use(sim) != "", "pas avant le départ de la partie")
	sim.launch_next_wave()
	check(_use(sim) == "", "pouvoir lancé")
	check(_use(sim) != "" and MatchPowers.waves_left(sim, sim.players[1]) == 3, "en recharge pour 3 vagues")
	for i in 3:
		sim.launch_next_wave()
	check(_use(sim) == "", "de nouveau prêt 3 vagues plus tard")
	check(Commands.sanitize({"a": "power", "cell": -1}, sim.data, sim.map) is String, "case hors carte refusée")


func test_instant_powers() -> void:
	var sim := _sim("quake")
	sim.launch_next_wave()
	var b := sim.boards[0]
	sim.apply_command(1, {"a": "build", "cell": _cell(sim, 2, 2), "tower": "crusher"})
	sim.players[1]["kit"].towers["crusher"] = true
	sim.apply_command(1, {"a": "build", "cell": _cell(sim, 2, 2), "tower": "crusher"})
	var m := _monster(b, 1.5)
	m.pos = b.towers[_cell(sim, 2, 2)].center + Vector2(0.5, 0.0)
	check(_use(sim) == "" and m.is_stunned() and m.hp < m.max_hp, "Séisme : étourdi et blessé")
	var tornado := _sim("tornado")
	tornado.launch_next_wave()
	var t := _monster(tornado.boards[0], 10.0)
	_use(tornado)
	check(is_equal_approx(t.progress, 10.0 - MatchPowers.PUSH), "Tornade : repoussé de 3 cases")
	var feast := _sim("feast")
	feast.launch_next_wave()
	var f := _monster(feast.boards[0])
	f.apply_bleed(0.01, 5.0, 1)
	_use(feast)
	check(f.hp < f.max_hp * (1.0 - MatchPowers.FEAST + 0.01), "Curée : -15 %% des PV d'un monstre qui saigne")


func test_aimed_powers() -> void:
	var sim := _sim("perfect_shot")
	sim.launch_next_wave()
	check(_use(sim, _cell(sim, 8, 1)) != "", "Tir parfait : il faut une Baliste")
	var meteor := _sim("meteor")
	meteor.launch_next_wave()
	var b := meteor.boards[0]
	var m := _monster(b)
	var cell := b.map.cell_count() - 1
	for i in b.map.cell_count():
		if b.map.cell_center(i).distance_to(m.pos) < 0.8:
			cell = i
	check(_use(meteor, cell) == "" and m.hp < m.max_hp and not b.patches.is_empty(), "Météore : dégâts et nappe de feu")
	var genius := _sim("genius")
	genius.launch_next_wave()
	var c := _cell(genius, 2, 2)
	genius.apply_command(1, {"a": "build", "cell": c, "tower": "crossbow"})
	check(_use(genius, c) == "" and genius.boards[0].towers[c].level == 1, "Coup de génie : un niveau gratuit")


func test_gold_powers() -> void:
	var sim := _sim("golden_age", 2)
	sim.launch_next_wave()
	var before := int(sim.players[2]["gold"])
	_use(sim)
	check(int(sim.players[2]["gold"]) == before + MatchPowers.GOLDEN_AGE, "Âge d'or : 100 or à l'allié")
	var rush := _sim("gold_rush")
	rush.launch_next_wave()
	_use(rush)
	rush.players[1]["kit"].bounty = 1.0
	rush.players[1]["gold"] = 0
	MatchEconomy.credit_bounty(rush, 1, 10)
	check(rush.players[1]["gold"] == 20, "Ruée vers l'or : primes ×2")
	var all_in := _sim("all_in")
	all_in.launch_next_wave()
	_use(all_in)
	MatchPowers.update(all_in, 0.05)
	check(int(all_in.boards[0].get_meta("leak_extra", 0)) == 1, "Va-tout : une vie de plus par fuite")
	all_in.boards[0].clock += 20.0
	MatchPowers.update(all_in, 0.05)
	check(int(all_in.boards[0].get_meta("leak_extra", 0)) == 0 and not MatchPowers.active(all_in.boards[0], "all_in"), "puis fin du Va-tout")


func test_timed_combat_powers() -> void:
	var sim := _sim("lead_rain")
	sim.launch_next_wave()
	sim.players[1]["kit"].towers["gatling"] = true
	sim.apply_command(1, {"a": "build", "cell": _cell(sim, 2, 2), "tower": "gatling"})
	var t: SimTower = sim.boards[0].towers[_cell(sim, 2, 2)]
	_use(sim)
	check(is_equal_approx(MatchPowers.rate_mult(sim.boards[0], t), 3.0), "Pluie de plomb : cadence ×3")
	var plague := _sim("plague")
	plague.launch_next_wave()
	_use(plague)
	var b := plague.boards[0]
	var m := _monster(b)
	var p := SimProjectile.new()
	p.stats = {"poison_dps": 1.0, "poison_duration": 2.0}
	p.credit = BoardCombat.solo(1)
	p.owner = 1
	BoardCombat.afflict(b, m, p)
	check(m.poison_timer > 100.0, "Fléau originel : poison sans fin")
	var chain := _sim("chain_lightning")
	chain.launch_next_wave()
	_use(chain)
	var cb := chain.boards[0]
	var a := _monster(cb, 10.0)
	var other := _monster(cb, 14.0)
	a.marks.apply_shock(0.0001)
	other.marks.apply_shock(0.0001)
	BoardCombat.damage(cb, a, 100.0, true, BoardCombat.solo(1), [])
	check(other.hp < other.max_hp - 20.0, "Foudre en chaîne : 25 %% partagés (%f)" % other.hp)


func test_remount_and_reshape() -> void:
	var sim := _sim("remount")
	sim.launch_next_wave()
	var c := _cell(sim, 2, 2)
	sim.apply_command(1, {"a": "build", "cell": c, "tower": "crossbow"})
	_use(sim)
	check(sim.apply_command(1, {"a": "move", "cell": c, "to": _cell(sim, 3, 2)}) == "", "Remontage : déplacement sans talent")
	var before := int(sim.players[1]["gold"])
	sim.apply_command(1, {"a": "sell", "cell": _cell(sim, 3, 2)})
	check(int(sim.players[1]["gold"]) - before == int(sim.data.tower_levels("crossbow")[0]["cost"]), "revente à 100 %%")
	var shape := _sim("reshape")
	shape.launch_next_wave()
	shape.players[1]["used_tile"] = 3
	_use(shape)
	check(not shape.players[1].has("used_tile"), "Remodelage : charges rendues")


## Le joueur automatique lance son pouvoir au niveau 30 (sans plantage), pour chaque classe.
func test_bot_uses_its_power() -> void:
	var gd := load_data()
	var bot = preload("res://tests/bot/balance_bot.gd").new()
	for b in gd.builders.size():
		var sim: SimMatch = bot.play(gd, 0, 1, 0, {}, [[b, 0]], 30)
		check(int(sim.players[1].get("power_wave", -99)) >= 0, "%s : pouvoir lancé au moins une fois" % gd.builders[b]["id"])
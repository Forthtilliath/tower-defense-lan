extends "res://tests/unit/test_base.gd"
## Règles de jeu appliquées par l'hôte : construction, propriété, or, vagues, fin de partie.

const DT := 0.05


func _coop(players := 1) -> SimMatch:
	var roster := []
	for i in players:
		roster.append([i + 1, "J%d" % (i + 1), i])
	return SimMatch.new(load_data(), 0, SimMatch.Mode.COOP, roster)


func _first_buildable(m: MapDef) -> int:
	for i in m.cell_count():
		if m.is_buildable(i):
			return i
	return -1


func _cmd(raw: Dictionary, sim: SimMatch) -> Variant:
	return Commands.sanitize(raw, sim.data, sim.map)


func test_build_spends_gold() -> void:
	var sim := _coop()
	var cell := _first_buildable(sim.map)
	check(sim.apply_command(1, _cmd({"a": "build", "cell": cell, "tower": 0}, sim)) == "", "construction acceptée")
	check(sim.players[1]["gold"] == 100, "50 or dépensés")
	check(sim.apply_command(1, _cmd({"a": "build", "cell": cell, "tower": 0}, sim)) != "", "case occupée refusée")


func test_cannot_build_on_route_or_without_gold() -> void:
	var sim := _coop()
	var route := sim.map.width * 1 + 1  # case (1, 1) : route de la prairie
	check(sim.apply_command(1, _cmd({"a": "build", "cell": route, "tower": 0}, sim)) != "", "route refusée")
	sim.players[1]["gold"] = 10
	var cell := _first_buildable(sim.map)
	check(sim.apply_command(1, _cmd({"a": "build", "cell": cell, "tower": 0}, sim)) == "Or insuffisant", "or insuffisant")


func test_only_owner_can_sell_or_upgrade() -> void:
	var sim := _coop(2)
	var cell := _first_buildable(sim.map)
	sim.apply_command(1, _cmd({"a": "build", "cell": cell, "tower": 0}, sim))
	check(sim.apply_command(2, _cmd({"a": "sell", "cell": cell}, sim)) != "", "vente par un autre refusée")
	check(sim.apply_command(2, _cmd({"a": "upgrade", "cell": cell}, sim)) != "", "amélioration par un autre refusée")
	check(sim.apply_command(1, _cmd({"a": "upgrade", "cell": cell}, sim)) == "", "amélioration acceptée")
	check(sim.apply_command(1, _cmd({"a": "sell", "cell": cell}, sim)) == "", "vente acceptée")
	# 150 - 50 - 45 + 70 % de 95 = 121
	check(sim.players[1]["gold"] == 121, "remboursement à 70 %% : %d" % sim.players[1]["gold"])


func test_malformed_commands_are_rejected() -> void:
	var sim := _coop()
	var bad := [
		null, 42, "build", [], {"a": "build"}, {"a": "build", "cell": -1, "tower": 0},
		{"a": "build", "cell": 9999, "tower": 0}, {"a": "build", "cell": 3, "tower": 99},
		{"a": "build", "cell": 3.5, "tower": 0}, {"a": "build", "cell": 3, "tower": 0, "x": 1},
		{"a": "sell", "cell": "3"}, {"a": "send", "monster": -2}, {"a": "boom"}, {"a": 1},
	]
	for raw in bad:
		check(typeof(Commands.sanitize(raw, sim.data, sim.map)) == TYPE_STRING, "refus attendu : %s" % str(raw))


func test_monsters_leak_and_cost_lives() -> void:
	var sim := _coop()
	sim.launch_next_wave()
	# 40 s : la vague 1 est passée, les gobelins de la vague 2 ne sont pas encore arrivés
	for i in int(40.0 / DT):
		sim.step(DT)
	check(sim.boards[0].lives == 12, "8 gobelins passés = -8 vies : %d" % sim.boards[0].lives)


func test_tower_kills_reward_owner() -> void:
	var sim := _coop(2)
	# Case (2, 2) : juste à côté de la route du haut
	var cell := 2 * sim.map.width + 2
	sim.apply_command(2, _cmd({"a": "build", "cell": cell, "tower": 0}, sim))
	sim.players[2]["gold"] = 0
	sim.launch_next_wave()
	# 15 s : avant le lancement automatique de la vague 2
	for i in int(15.0 / DT):
		sim.step(DT)
	check(sim.players[2]["gold"] > 15, "le propriétaire touche les primes : %d" % sim.players[2]["gold"])
	# 6 or d'intérêts (4 % de 150) + 15 or de vague ; pas de bonus pour la première vague
	check(sim.players[1]["gold"] == 150 + 6 + 15, "l'autre joueur ne touche que l'or de vague : %d" % sim.players[1]["gold"])


func test_first_wave_waits_for_the_players() -> void:
	var sim := _coop(2)
	for i in int(120.0 / DT):
		sim.step(DT)
	check(sim.wave_index == -1 and sim.boards[0].monsters.is_empty(), "la première vague ne part jamais seule")
	check(sim.snapshot()["nx"], "elle peut être lancée")
	check(sim.apply_command(1, _cmd({"a": "ready"}, sim)) == "", "prêt accepté")
	check(sim.wave_index == -1, "la vague attend le second joueur")
	sim.apply_command(2, _cmd({"a": "ready"}, sim))
	check(sim.wave_index == 0, "vague lancée quand tout le monde est prêt")
	check(sim.players[1]["gold"] == 150 + 6 + 15, "intérêts et vague, sans bonus pour la première : %d" % sim.players[1]["gold"])


func test_coop_defeat_when_lives_reach_zero() -> void:
	var sim := _coop()
	sim.boards[0].lives = 1
	sim.launch_next_wave()
	for i in int(60.0 / DT):
		sim.step(DT)
	check(sim.ended and sim.result == "defeat", "défaite attendue")


func test_versus_send_and_elimination() -> void:
	var sim := SimMatch.new(load_data(), 0, SimMatch.Mode.VERSUS, [[1, "A", 0], [5, "B", 1]])
	check(sim.boards.size() == 2, "un plateau par joueur")
	check(sim.apply_command(1, _cmd({"a": "send", "monster": 0}, sim)) == "", "envoi accepté")
	check(sim.players[1]["income"] == 1 and sim.players[1]["gold"] == 140, "revenu et coût")
	sim.step(1.0)
	check(sim.boards[1].monsters.size() == 1 and sim.boards[0].monsters.is_empty(), "monstre chez l'adversaire")
	sim.boards[1].lives = 1
	for i in int(40.0 / DT):
		sim.step(DT)
	check(sim.ended and sim.result == "winner" and sim.winner == 1, "A gagne : %s %d" % [sim.result, sim.winner])


func test_versus_disconnect_eliminates() -> void:
	var sim := SimMatch.new(load_data(), 0, SimMatch.Mode.VERSUS, [[1, "A", 0], [5, "B", 1], [9, "C", 2]])
	sim.player_left(5)
	check(not sim.players[5]["alive"] and not sim.ended, "B éliminé, partie continue")
	check(sim.next_opponent_board(1) == 2, "A envoie désormais chez C")
	sim.player_left(9)
	check(sim.ended and sim.winner == 1, "A gagne par abandon")

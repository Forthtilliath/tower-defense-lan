extends "res://tests/test_base.gd"
## Économie des talents (MatchEconomy, PlayerKit.MONEY) : prêt, or offert aux alliés, rente,
## Main chaude, or d'avance, intérêts composés et partagés, primes (gros monstres, trophées,
## risque, nerfs, contrat, jackpot, butin), dons investis, améliorations moins chères.


func _duo() -> SimMatch:
	return SimMatch.new(load_data(), 0, SimMatch.Mode.COOP, [[1, "A", 0], [2, "B", 1]])


func _wave(sim: SimMatch) -> Dictionary:
	return {"gold": 10, "groups": []}


func test_loan_and_ally_start() -> void:
	var sim := _duo()
	var a: Dictionary = sim.players[1]
	var b: Dictionary = sim.players[2]
	var before := [int(a["gold"]), int(b["gold"])]
	a["kit"].money = {"loan": 200.0, "ally_start": 30.0}
	MatchEconomy.setup(sim)
	check(a["gold"] == before[0] + 200 and a["loan_due"] == 240, "prêt de 200, 240 à rendre")
	check(b["gold"] == before[1] + 30, "l'allié reçoit 30 or")
	a["gold"] = 100
	sim.wave_index = MatchEconomy.LOAN_WAVE
	MatchEconomy.pay_wave(sim, _wave(sim), 0, {})
	check(a["gold"] == 0 and int(a["loan_due"]) > 0, "remboursement partiel sans or négatif : %d, reste %d" % [a["gold"], a["loan_due"]])


func test_wave_income_talents() -> void:
	var sim := _duo()
	var a: Dictionary = sim.players[1]
	var kit: PlayerKit = a["kit"]
	kit.money = {"rent": 5.0, "hot_hand": 3.0, "early_wave": 1.0}
	a["gold"] = 0
	MatchEconomy.pay_wave(sim, _wave(sim), 0, {0: true})
	check(a["gold"] == 10 + 5 + 3, "vague + rente + Main chaude (1 vague) : %d" % a["gold"])
	a["gold"] = 0
	MatchEconomy.pay_wave(sim, _wave(sim), 4, {0: true})
	check(a["gold"] == 10 + 4 + 5 + 6 + 10, "or d'avance, rente, Main chaude (2 d'affilée), vague doublée : %d" % a["gold"])
	MatchEconomy.pay_wave(sim, _wave(sim), 0, {})
	check(kit.clean_streak == 0, "une fuite remet la série à zéro")


func test_compound_and_shared_interest() -> void:
	var sim := _duo()
	var a: Dictionary = sim.players[1]
	var b: Dictionary = sim.players[2]
	sim.apply_command(1, {"a": "build", "cell": 2 * sim.map.width + 2, "tower": "crossbow"})
	a["kit"].money = {"compound": 0.5, "share_interest": 0.5}
	a["gold"] = 100
	b["gold"] = 0
	MatchEconomy.pay_wave(sim, {"gold": 0, "groups": []}, 0, {})
	var expected := MatchFlow.interest(sim.data, 100 + 25, a["kit"])
	check(a["gold"] == 100 + expected, "intérêts sur l'or et la moitié des 50 investis : %d" % a["gold"])
	check(b["gold"] == roundi(expected * 0.5), "l'allié touche la moitié des intérêts : %d" % b["gold"])


func test_bounty_talents() -> void:
	var sim := _duo()
	var a: Dictionary = sim.players[1]
	var kit: PlayerKit = a["kit"]
	kit.bounty = 1.0
	kit.money = {"boss_bounty": 1.0, "trophy": 0.1}
	a["gold"] = 0
	MatchEconomy.credit_bounty(sim, 1, 10, true)
	check(a["gold"] == 20 and kit.trophies == 1, "gros monstre : prime ×2, un trophée")
	a["gold"] = 0
	MatchEconomy.credit_bounty(sim, 1, 10)
	check(a["gold"] == 11, "trophée : +10 %% : %d" % a["gold"])
	kit.money = {"contract": 2.0}
	kit.trophies = 0
	a["gold"] = 0
	MatchEconomy.credit_bounty(sim, 1, 10)
	MatchEconomy.credit_bounty(sim, 1, 10)
	check(a["gold"] == 30 + 10, "contrat : le premier de la vague ×3 : %d" % a["gold"])
	kit.money = {"jackpot": 1.0, "loot": 1.0}
	a["gold"] = 0
	MatchEconomy.credit_bounty(sim, 1, 10)
	check(a["gold"] == 100 + MatchEconomy.LOOT_GOLD, "jackpot ×10 et butin : %d" % a["gold"])


func test_risk_and_nerve() -> void:
	var sim := _duo()
	var a: Dictionary = sim.players[1]
	a["kit"].bounty = 1.0
	a["kit"].money = {"risk": 0.02, "nerve": 0.5}
	sim.boards[0].lives = int(a["start_lives"]) - 10
	a["gold"] = 0
	MatchEconomy.credit_bounty(sim, 1, 100)
	check(a["gold"] == 120, "10 vies perdues : +20 %% : %d" % a["gold"])
	sim.boards[0].lives = 3
	a["gold"] = 0
	MatchEconomy.credit_bounty(sim, 1, 100)
	check(a["gold"] == 100 + 30 + 50, "risque plafonné à 30 %%, nerfs +50 %% : %d" % a["gold"])


func test_invest_and_team_discount() -> void:
	var sim := _duo()
	var a: Dictionary = sim.players[1]
	var b: Dictionary = sim.players[2]
	a["kit"].money = {"invest": 0.5, "team_discount": 0.2}
	a["gold"] = 100
	check(sim.apply_command(1, {"a": "give", "to": 1, "amount": 40}) == "", "don accepté")
	sim.wave_index += MatchEconomy.INVEST_WAVES
	var gold_before := int(a["gold"])
	MatchEconomy.pay_wave(sim, {"gold": 0, "groups": []}, 0, {})
	check(int(a["gold"]) >= gold_before + 20, "la moitié du don revient 3 vagues plus tard")
	var cell := 2 * sim.map.width + 2
	b["gold"] = 1000
	sim.apply_command(2, {"a": "build", "cell": cell, "tower": "crossbow"})
	var before := int(b["gold"])
	sim.apply_command(2, {"a": "upgrade", "cell": cell})
	var full := int(sim.data.tower_levels("crossbow")[1]["cost"])
	check(before - int(b["gold"]) == b["kit"].cost(full, 0.2), "amélioration de l'allié 20 %% moins chère")

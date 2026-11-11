extends "res://tests/unit/test_base.gd"
## Talents de disposition (BoardLayout) et étages : voisinage, plans, contreforts, chef-d'œuvre,
## pièces détachées, déplacement d'une tourelle, niveaux 6 et 7 de l'Architecte, Ferraille.


func _solo() -> SimMatch:
	var sim := SimMatch.new(load_data(), 0, SimMatch.Mode.COOP, [[1, "A", 0, 5]])
	sim.players[1]["gold"] = 100000
	return sim


func _cell(sim: SimMatch, x: int, y: int) -> int:
	return y * sim.map.width + x


func test_neighbourhood_bonuses() -> void:
	var sim := _solo()
	var b := sim.boards[0]
	for xy in [[2, 2], [3, 2], [2, 3], [3, 3]]:
		sim.apply_command(1, {"a": "build", "cell": _cell(sim, xy[0], xy[1]), "tower": "crossbow"})
	var t: SimTower = b.towers[_cell(sim, 2, 2)]
	var p := BoardCombat.shot(b, t, sim.data.towers["crossbow"])
	p.stats["wall"] = 0.1
	p.stats["keystone"] = 0.5
	p.stats["twin"] = 0.2
	check(is_equal_approx(BoardLayout.damage_mult(b, t, p), 1.3 * 1.5 * 1.2), "3 voisines identiques : mur ×1,3, pierre angulaire ×1,5, symétrie ×1,2")
	sim.apply_command(1, {"a": "upgrade", "cell": t.cell})
	check(BoardLayout.is_crown(b, t), "la plus chère : clé de voûte")


func test_floors_unlock_levels_six_and_seven() -> void:
	var sim := _solo()
	var kit: PlayerKit = sim.players[1]["kit"]
	var cell := _cell(sim, 2, 2)
	sim.apply_command(1, {"a": "build", "cell": cell, "tower": "crossbow"})
	for i in 6:
		sim.apply_command(1, {"a": "upgrade", "cell": cell})
	var t: SimTower = sim.boards[0].towers[cell]
	check(t.level == 4, "sans étage : niveau 5 au plus (%d)" % (t.level + 1))
	kit.money["floors"] = 2.0
	sim.apply_command(1, {"a": "upgrade", "cell": cell})
	sim.apply_command(1, {"a": "upgrade", "cell": cell})
	check(t.level == 6, "deux étages : niveau 7 (%d)" % (t.level + 1))
	check(float(t.stats["damage"]) > float(sim.data.tower_levels("crossbow")[4]["damage"]) * 1.7, "chaque étage frappe plus fort")
	check(sim.data.levels_for("ballista", kit).size() == 5, "pas d'étage hors du tronc commun")


func test_move_and_spare_parts() -> void:
	var sim := _solo()
	var kit: PlayerKit = sim.players[1]["kit"]
	var a := _cell(sim, 2, 2)
	var to := _cell(sim, 4, 2)
	sim.apply_command(1, {"a": "build", "cell": a, "tower": "cannon"})
	check(sim.apply_command(1, {"a": "move", "cell": a, "to": to}) != "", "pas de déplacement sans le talent")
	kit.money = {"moves": 1.0, "tinker": 0.5, "spare": 0.1}
	check(sim.apply_command(1, {"a": "move", "cell": a, "to": to}) == "", "déplacement accepté")
	var t: SimTower = sim.boards[0].towers.get(to)
	check(t != null and not sim.boards[0].towers.has(a), "la tourelle a changé de case")
	check(t.tinker > 0.0 and is_equal_approx(BoardLayout.rate_mult(t), 1.5), "Bricolage : cadence en plus")
	check(sim.apply_command(1, {"a": "move", "cell": to, "to": a}) != "", "un seul déplacement par vague")
	sim.apply_command(1, {"a": "sell", "cell": to})
	sim.apply_command(1, {"a": "build", "cell": a, "tower": "crossbow"})
	check(is_equal_approx(sim.boards[0].towers[a].spare, 0.1), "pièces détachées sur la tourelle suivante")
	check(Commands.sanitize({"a": "move", "cell": a, "to": a}, sim.data, sim.map) is String, "déplacement sur place refusé")


func test_scrap_pays_more_for_vehicles() -> void:
	var sim := _solo()
	var p: Dictionary = sim.players[1]
	p["kit"].bounty = 1.0
	p["kit"].money = {"scrap": 0.5}
	p["gold"] = 0
	MatchEconomy.credit_bounty(sim, 1, 10, false, true)
	check(p["gold"] == 15, "véhicule : +50 %% (%d)" % p["gold"])

func _special(sim: SimMatch, id: String) -> int:
	for i in sim.data.specials.size():
		if sim.data.specials[i]["id"] == id:
			return i
	return -1


func test_terraformer_tiles_use_their_own_charges() -> void:
	var sim := _solo()
	var p: Dictionary = sim.players[1]
	var kit: PlayerKit = p["kit"]
	var cell := _cell(sim, 2, 2)
	var mound := _special(sim, "mound")
	kit.tile_charges = 3
	check(sim.apply_command(1, {"a": "tile", "cell": cell, "special": mound}) != "", "la Géomancie ne pose pas de Butte")
	kit.money = {"mound_tiles": 1.0, "vein_tiles": 1.0}
	check(sim.apply_command(1, {"a": "tile", "cell": cell, "special": mound}) == "", "Butte posée avec sa charge")
	check(MatchActions.charges_left(p, "mound") == 0 and MatchActions.charges_left(p, "tile") == 3, "charge de Butte dépensée, pas celle de Géomancie")
	check(sim.apply_command(1, {"a": "tile", "cell": _cell(sim, 3, 2), "special": _special(sim, "gold")}) == "", "Filon posé")
	var view := ViewState.new(sim.data, sim.map, sim.boards.size())
	var snap := sim.snapshot()
	snap["speed"] = 1
	snap["iv"] = 0.1
	check(view.apply(snap), "un client accepte la Butte et le Filon posés")
	check(int(view.players[1].get("tile", -1)) == 3 and int(view.players[1].get("mound", -1)) == 0, "charges reçues")


func test_ditch_slows_and_fertile_soil() -> void:
	var sim := _solo()
	var b := sim.boards[0]
	var kit: PlayerKit = sim.players[1]["kit"]
	kit.money = {"ditch_tiles": 1.0}
	var cell := _cell(sim, 3, 2)  # à côté de la route de Prairie (ligne 1)
	check(sim.apply_command(1, {"a": "tile", "cell": cell, "special": _special(sim, "ditch")}) == "", "Fossé creusé")
	var m := b.spawn("goblin", 1.0, 0, 0.0)
	m.pos = b.map.cell_center(cell) + Vector2(0.0, -0.9)
	BoardTerrain.ditches(b)
	check(m.is_slowed() and is_equal_approx(m.slow_factor, 0.75), "ralenti de 25 %% près du fossé")
	var hill := _special(sim, "hill")
	var plain := float(sim.data.tower_stats("crossbow", 0, hill, kit)["range"])
	kit.money["fertile"] = 1.0
	var rich := float(sim.data.tower_stats("crossbow", 0, hill, kit)["range"])
	var base := float(sim.data.tower_levels("crossbow")[0]["range"])
	check(is_equal_approx(rich, base * 1.5) and is_equal_approx(plain, base * 1.25), "Terre fertile : Colline +50 %% au lieu de +25 %%")


func test_shared_jackpot() -> void:
	var sim := SimMatch.new(load_data(), 0, SimMatch.Mode.COOP, [[1, "A", 0], [2, "B", 1]])
	sim.players[1]["kit"].money = {"jackpot": 1.0, "jackpot_share": 0.5}
	sim.players[2]["gold"] = 0
	MatchEconomy.credit_bounty(sim, 1, 10)
	check(sim.players[2]["gold"] == 45, "l'allié touche la moitié du gain du jackpot : %d" % sim.players[2]["gold"])
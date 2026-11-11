class_name MatchRecap
extends RefCounted
## Fin de partie pour le compte ouvert (une seule fois par partie) : expérience de la classe
## jouée, puis la partie ajoutée à l'historique avec ses étoiles (MatchHistory).


## start_lives : vies du plateau du joueur au début de la partie (le plus haut vu).
## Renvoie {xp_text, won, stars, record, lives, start}.
static func close(game: GameScreen, start_lives: int) -> Dictionary:
	var state := game.state
	var won := state.result == "victory" or (state.result == "winner" and state.winner == game.my_id)
	var passed := state.wave if won else maxi(0, state.wave - 1)
	var total := game.map.waves.size()
	var difficulty := int(game.config.get("difficulty", 1))
	var amount := TalentRules.match_xp(Data.db, won, mini(passed, total), total, difficulty)
	var kit := game.my_kit()
	if won and kit != null and kit.m("saver") > 0.0:  # Épargnant : l'or gardé rapporte de l'expérience
		amount = roundi(amount * (1.0 + kit.m("saver") * int(state.players.get(game.my_id, {}).get("gold", 0)) / 100.0))
	var builder := game.my_builder()
	var levels := Progress.award(builder, amount)
	var text := "+%d XP pour %s (niveau %d)" % [amount, Data.db.builders[builder]["name"], levels[1]]
	if levels[1] > levels[0]:
		text += " : +%d point(s) de talent !" % (levels[1] - levels[0])
	var lives := int(state.boards[game.my_board]["lives"]) if game.my_board < state.boards.size() else 0
	var start := maxi(1, maxi(start_lives, lives))
	var stars := MatchHistory.stars(won, not game.is_versus, lives, start)
	var record := Progress.record_game({
		"t": int(Time.get_unix_time_from_system()),
		"map": Data.db.maps[int(game.config["map"])].id,
		"diff": Data.db.difficulties[clampi(difficulty, 0, Data.db.difficulties.size() - 1)]["id"],
		"mode": "versus" if game.is_versus else "coop",
		"won": won, "wave": clampi(state.wave, 0, HistoryFile.MAX_COUNT), "waves": clampi(total, 1, 1000),
		"lives": clampi(lives, 0, HistoryFile.MAX_COUNT), "start": clampi(start, 1, HistoryFile.MAX_COUNT),
		"stars": stars, "class": Data.db.builders[builder]["id"], "lvl": clampi(levels[0], 1, 1000),
		"xp": clampi(amount, 0, ProgressFile.MAX_XP), "team": _team(game),
	})
	return {"xp_text": text, "won": won, "stars": stars, "record": record and stars > 0, "lives": lives, "start": start}


## [[pseudo, classe], …] des autres joueurs de la partie, dans l'ordre de la partie.
static func _team(game: GameScreen) -> Array:
	var out := []
	for id in game.order:
		if id == game.my_id or out.size() >= HistoryFile.MAX_TEAM:
			continue
		var name := Check.sanitize_name(game.names.get(id, ""))
		var b := clampi(int(game.builders.get(id, 0)), 0, Data.db.builders.size() - 1)
		if name != "":
			out.append([name, Data.db.builders[b]["id"]])
	return out

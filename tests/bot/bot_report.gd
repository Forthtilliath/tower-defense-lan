extends SceneTree
## Bilan du joueur automatique : fait jouer chaque spécialisation sur chaque carte et imprime
## un tableau (une ligne par spécialisation, une colonne par carte : V = victoire, sinon la
## vague de la défaite), puis les totaux. Sert à l'équilibrage et au fichier docs/BOT.md.
##
## godot --headless --path . --script res://tests/bot/bot_report.gd -- [--level=10] [--difficulty=1]
##   [--maps=0,1,2] [--classes=0,1] [--specs=0,1] [--players=1] [--out=chemin.md]

const Bot := preload("res://tests/bot/balance_bot.gd")


func _init() -> void:
	var level := 10
	var difficulty := 1
	var players := 1
	var maps: Array = []
	var classes: Array = []
	var specs: Array = []
	var out := ""
	var verbose := false
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"--level":
				level = int(kv[1])
			"--difficulty":
				difficulty = int(kv[1])
			"--players":
				players = int(kv[1])
			"--maps":
				maps = _ints(kv[1])
			"--classes":
				classes = _ints(kv[1])
			"--specs":
				specs = _ints(kv[1])
			"--out":
				out = kv[1]
			"--verbose":
				verbose = kv[1] == "1"
	var gd := GameData.load_file()
	if not gd.is_valid():
		printerr("Données invalides : ", gd.error)
		quit(1)
		return
	if maps.is_empty():
		maps = range(gd.maps.size())
	if classes.is_empty():
		classes = range(gd.builders.size())
	var bot = Bot.new()
	bot.verbose = verbose
	if verbose:
		var table: Dictionary = preload("res://tests/bot/bot_calibrate.gd")._table(gd)
		for type in table:
			print("étalonnage %s : ×%.2f (niv. 1), ×%.2f (niv. 4)" % [type, table[type][0], table[type][1]])
	var lines := []
	var header := "| Spécialisation |"
	var sep := "|---|"
	for m in maps:
		header += " %s |" % gd.maps[m].name
		sep += "---|"
	header += " Gagnées | Vies moy. | Or final |"
	sep += "---|---|---|"
	lines.append(header)
	lines.append(sep)
	var started := Time.get_ticks_msec()
	var total_won := 0
	var total_games := 0
	for b in classes:
		for s in (specs if not specs.is_empty() else range(bot.spec_count(gd, b))):
			var row := "| %s · %s |" % [gd.builders[b]["name"], bot.spec_id(gd, b, s)]
			var won := 0
			var lives := 0.0
			var gold := 0.0
			for m in maps:
				var team := []
				for i in players:
					team.append([b, s])
				var sim: SimMatch = bot.play(gd, m, players, difficulty, {}, team, level)
				var victory := sim.result == "victory"
				won += 1 if victory else 0
				lives += sim.boards[0].lives
				gold += sim.players[sim.order[0]]["gold"]
				row += " %s |" % ("V %d" % sim.boards[0].lives if victory else "✗ %d" % (sim.wave_index + 1))
				print("%s/%s %s : %s (vague %d, vies %d, or %d) [%d s]" % [gd.builders[b]["id"], bot.spec_id(gd, b, s), gd.maps[m].id,
					sim.result, sim.wave_index + 1, sim.boards[0].lives, sim.players[sim.order[0]]["gold"], (Time.get_ticks_msec() - started) / 1000])
			row += " %d/%d | %.1f | %.0f |" % [won, maps.size(), lives / maps.size(), gold / maps.size()]
			lines.append(row)
			total_won += won
			total_games += maps.size()
	lines.append("")
	lines.append("Total : %d/%d parties gagnées (niveau %d, %s, %d joueur(s)), en %d s." % [total_won, total_games, level,
		gd.difficulties[difficulty]["name"], players, (Time.get_ticks_msec() - started) / 1000])
	var text := "\n".join(lines)
	print("\nRAPPORT\n" + text)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_string(text + "\n")
	quit(0)


func _ints(text: String) -> Array:
	var out := []
	for part in text.split(","):
		if part.strip_edges().is_valid_int():
			out.append(int(part))
	return out

extends "res://tests/unit/test_base.gd"
## Historique des parties et étoiles des cartes (MatchHistory, HistoryFile) : étoiles selon les
## vies gardées, records, filtres, validation stricte du fichier, taille, compte transféré.

const DIR := "user://test_history"


func _game(overrides := {}) -> Dictionary:
	var g := {"t": 1762870000, "map": "prairie", "diff": "normal", "mode": "coop", "won": true,
		"wave": 20, "waves": 20, "lives": 18, "start": 20, "stars": 3, "class": "arcanist",
		"lvl": 4, "xp": 300, "team": [["Atthis", "support"]]}
	g.merge(overrides, true)
	return g


func test_stars_follow_lives_kept() -> void:
	check(MatchHistory.stars(true, true, 18, 20) == 3, "18 vies sur 20 : 3 étoiles")
	check(MatchHistory.stars(true, true, 17, 20) == 2, "17 vies sur 20 : 2 étoiles")
	check(MatchHistory.stars(true, true, 10, 20) == 2, "la moitié des vies : 2 étoiles")
	check(MatchHistory.stars(true, true, 9, 20) == 1, "moins de la moitié : 1 étoile")
	check(MatchHistory.stars(true, true, 54, 60) == 3 and MatchHistory.stars(true, true, 53, 60) == 2, "à trois (60 vies) : même proportion")
	check(MatchHistory.stars(false, true, 20, 20) == 0, "défaite : aucune étoile")
	check(MatchHistory.stars(true, false, 20, 20) == 0, "versus : aucune étoile")


func test_records_are_kept_and_never_lowered() -> void:
	var h := MatchHistory.empty()
	check(MatchHistory.add(h, _game({"stars": 2, "lives": 12})), "première victoire : record")
	check(not MatchHistory.add(h, _game({"stars": 1, "lives": 3})), "moins d'étoiles : pas de record")
	check(MatchHistory.best(h, "prairie", "normal") == 2, "le record reste à 2")
	check(MatchHistory.add(h, _game({"stars": 3})), "3 étoiles : nouveau record")
	check(MatchHistory.best(h, "prairie", "hard") == 0 and MatchHistory.best(h, "riviere", "normal") == 0, "record par carte et par difficulté")
	for i in MatchHistory.MAX_GAMES + 5:
		MatchHistory.add(h, _game({"won": false, "stars": 0, "t": i}))
	check(h["games"].size() == MatchHistory.MAX_GAMES, "historique coupé à %d parties" % MatchHistory.MAX_GAMES)
	check(h["games"][0]["t"] == MatchHistory.MAX_GAMES + 4, "la plus récente en tête")
	check(MatchHistory.best(h, "prairie", "normal") == 3, "les étoiles restent après la sortie de la partie")


func test_filters_and_mates() -> void:
	var games := [
		_game({"class": "arcanist", "team": [["Atthis", "support"]]}),
		_game({"class": "gunner", "team": [["Bob", "arcanist"], ["Atthis", "gunner"]], "won": false, "stars": 0}),
		_game({"class": "arcanist", "team": [], "map": "riviere"}),
	]
	check(MatchHistory.filter(games, {}).size() == 3, "sans filtre : tout")
	check(MatchHistory.filter(games, {"class": "arcanist"}).size() == 2, "par classe jouée")
	check(MatchHistory.filter(games, {"mate": "Atthis"}).size() == 2, "par coéquipier")
	check(MatchHistory.filter(games, {"mate_class": "arcanist"}).size() == 1, "par classe d'un coéquipier")
	check(MatchHistory.filter(games, {"solo": true}).size() == 1, "seul")
	check(MatchHistory.filter(games, {"map": "riviere", "class": "gunner"}).is_empty(), "filtres cumulés")
	check(",".join(MatchHistory.mates(games)) == "Atthis,Bob", "coéquipiers triés : %s" % [MatchHistory.mates(games)])
	var s := MatchHistory.summary(games)
	check(s["count"] == 3 and s["wins"] == 2, "bilan : 3 parties, 2 victoires")


func test_history_file_is_strict() -> void:
	var good := {"games": [_game()], "best": {"prairie": {"normal": 3}}}
	var parsed = HistoryFile.parse(JSON.parse_string(JSON.stringify(good)))
	check(parsed != null and parsed["games"][0]["lives"] == 18 and parsed["best"]["prairie"]["normal"] == 3, "historique relu")
	var extra := _game()
	extra["pirate"] = "x"
	parsed = HistoryFile.parse({"games": [extra], "best": {}})
	check(parsed != null and not parsed["games"][0].has("pirate"), "clé inconnue retirée")
	var bad_games := {
		"étoiles sur une défaite": _game({"won": false}),
		"étoiles en versus": _game({"mode": "versus"}),
		"4 étoiles": _game({"stars": 4}),
		"vies négatives": _game({"lives": -1}),
		"vies en texte": _game({"lives": "18"}),
		"vague décimale": _game({"wave": 2.5}),
		"mode inconnu": _game({"mode": "raid"}),
		"carte avec chemin": _game({"map": "../x"}),
		"pseudo vide": _game({"team": [["", "support"]]}),
		"pseudo non nettoyé": _game({"team": [[" Bob", "support"]]}),
		"coéquipier mal formé": _game({"team": [["Bob"]]}),
		"trop de coéquipiers": _game({"team": [["A", "x"], ["B", "x"], ["C", "x"], ["D", "x"], ["E", "x"], ["F", "x"], ["G", "x"], ["H", "x"]]}),
		"victoire manquante": _game({"won": null}),
	}
	for label in bad_games:
		check(HistoryFile.parse({"games": [_game(), bad_games[label]], "best": {}}) == null, "historique refusé : " + label)
	var bad_best := [{"prairie": {"normal": 4}}, {"prairie": {"normal": 0}}, {"prairie": 3}, {"Prairie!": {"normal": 1}}]
	for best in bad_best:
		check(HistoryFile.parse({"games": [], "best": best}) == null, "record refusé : %s" % [best])
	var many := []
	for i in MatchHistory.MAX_GAMES + 1:
		many.append(_game())
	check(HistoryFile.parse({"games": many, "best": {}}) == null, "trop de parties refusé")
	check(HistoryFile.parse({"games": []}) == null and HistoryFile.parse([]) == null, "structure incomplète refusée")


func test_account_file_keeps_history() -> void:
	var gd := load_data()
	var h := MatchHistory.empty()
	MatchHistory.add(h, _game())
	var text := ProgressFile.serialize(gd, "Forth", {"arcanist": {"xp": 300, "talents": {}}}, 0, h)
	var parsed = ProgressFile.parse(gd, text)
	check(parsed != null and parsed[3]["games"].size() == 1 and MatchHistory.best(parsed[3], "prairie", "normal") == 3, "historique relu avec le compte")
	var v2 = ProgressFile.parse(gd, "{\"v\": 2, \"name\": \"Forth\", \"classes\": {}}")
	check(v2 != null and v2[3]["games"].is_empty(), "compte de version 2 : historique vide")
	check(ProgressFile.parse(gd, "{\"v\": 3, \"name\": \"Forth\", \"classes\": {}}") == null, "version 3 sans historique refusée")
	check(ProgressFile.parse(gd, text.replace("\"stars\":3", "\"stars\":9")) == null, "partie invalide : compte refusé en entier")
	var offer = AccountTransfer.read_offer(gd, AccountTransfer.offer_bytes("1234", text).get_string_from_utf8(), "1234")
	check(offer is Dictionary and offer["history"]["games"].size() == 1, "historique transféré avec le compte")


## Le pire cas (historique plein, pseudos longs en caractères accentués, 7 coéquipiers) tient
## sous la taille maximale d'un fichier de compte.
func test_full_history_fits_in_account_file() -> void:
	var gd := load_data()
	var h := MatchHistory.empty()
	var team := []
	for i in HistoryFile.MAX_TEAM:
		team.append(["ééééééééééééééé%d" % i, "arcanist"])
	for i in MatchHistory.MAX_GAMES:
		MatchHistory.add(h, _game({"team": team, "t": HistoryFile.MAX_TIME, "xp": ProgressFile.MAX_XP, "map": "abcdefghijklmnopqrstuvwx"}))
	var classes := {}
	for b in gd.builders:
		classes[b["id"]] = {"xp": ProgressFile.MAX_XP, "talents": {}}
	var text := ProgressFile.serialize(gd, "ééééééééééééééé", classes, 0, h)
	check(text.to_utf8_buffer().size() < AccountStore.MAX_SIZE, "%d octets pour %d au plus" % [text.to_utf8_buffer().size(), AccountStore.MAX_SIZE])


func test_store_writes_and_reads_history() -> void:
	var gd := load_data()
	var h := MatchHistory.empty()
	MatchHistory.add(h, _game({"stars": 2, "lives": 15}))
	var id := AccountStore.new_id()
	check(AccountStore.write(gd, id, "Forth", {}, 0, DIR, h), "compte écrit avec son historique")
	var a = AccountStore.read(gd, id, DIR)
	check(a != null and a["history"]["games"].size() == 1 and MatchHistory.best(a["history"], "prairie", "normal") == 2, "historique relu")
	var exported := AccountStore.export_text(gd, id, DIR)
	check(exported.contains("\"history\"") and ProgressFile.parse(gd, exported)[3]["games"].size() == 1, "historique dans le compte envoyé")
	AccountStore.remove(id, DIR)
	DirAccess.remove_absolute(DIR)

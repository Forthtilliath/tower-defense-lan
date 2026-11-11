class_name HistoryFile
extends RefCounted
## Validation de l'historique d'un compte (format : MatchHistory), relu depuis le fichier du
## compte ou reçu d'un autre appareil.
## - Chaque partie et chaque record est vérifié champ par champ (type, bornes, valeurs permises).
## - Au moindre défaut, l'historique entier est refusé (et donc le fichier du compte).
## - Les clés inconnues ne sont pas recopiées : chaque partie est reconstruite.
## - Les cartes et classes inconnues des données (retirées par une mise à jour) sont gardées :
##   l'affichage montre alors leur identifiant.

const MAX_TIME := 100000000000
const MAX_TEAM := 7
const MAX_MAPS := 64
const MAX_DIFFICULTIES := 8
const MAX_COUNT := 100000


## Historique vérifié, ou null au premier défaut.
static func parse(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw
	if typeof(d.get("games")) != TYPE_ARRAY or typeof(d.get("best")) != TYPE_DICTIONARY:
		return null
	var raw_games: Array = d["games"]
	if raw_games.size() > MatchHistory.MAX_GAMES:
		return null
	var games := []
	for g in raw_games:
		var game = parse_game(g)
		if game == null:
			return null
		games.append(game)
	var best = _parse_best(d["best"])
	if best == null:
		return null
	return {"games": games, "best": best}


## Une partie vérifiée et reconstruite (clés connues seulement), ou null.
static func parse_game(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var g: Dictionary = raw
	var out := {
		"t": Check.as_int(g.get("t"), 0, MAX_TIME),
		"map": g.get("map") if Check.is_valid_id(g.get("map")) else null,
		"diff": g.get("diff") if Check.is_valid_id(g.get("diff")) else null,
		"mode": g.get("mode") if typeof(g.get("mode")) == TYPE_STRING and MatchHistory.MODES.has(g.get("mode")) else null,
		"won": Check.as_bool(g.get("won")),
		"wave": Check.as_int(g.get("wave"), 0, MAX_COUNT),
		"waves": Check.as_int(g.get("waves"), 1, 1000),
		"lives": Check.as_int(g.get("lives"), 0, MAX_COUNT),
		"start": Check.as_int(g.get("start"), 1, MAX_COUNT),
		"stars": Check.as_int(g.get("stars"), 0, 3),
		"class": g.get("class") if Check.is_valid_id(g.get("class")) else null,
		"lvl": Check.as_int(g.get("lvl"), 1, 1000),
		"xp": Check.as_int(g.get("xp"), 0, ProgressFile.MAX_XP),
		"team": _parse_team(g.get("team")),
	}
	for key in out:
		if out[key] == null:
			return null
	# Des étoiles sans victoire, ou en versus : fichier incohérent.
	if out["stars"] > 0 and (not out["won"] or out["mode"] != "coop"):
		return null
	return out


## [[pseudo, classe], …] des autres joueurs, ou null.
static func _parse_team(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_ARRAY or raw.size() > MAX_TEAM:
		return null
	var out := []
	for e in raw:
		if typeof(e) != TYPE_ARRAY or e.size() != 2:
			return null
		var name := Check.sanitize_name(e[0])
		if name == "" or name != e[0] or not Check.is_valid_id(e[1]):
			return null
		out.append([name, String(e[1])])
	return out


## {"<carte>": {"<difficulté>": 1 à 3}}, ou null.
static func _parse_best(raw: Dictionary) -> Variant:
	if raw.size() > MAX_MAPS:
		return null
	var out := {}
	for map_id in raw:
		var per = raw[map_id]
		if not Check.is_valid_id(map_id) or typeof(per) != TYPE_DICTIONARY or per.size() > MAX_DIFFICULTIES:
			return null
		var entry := {}
		for diff_id in per:
			var earned = Check.as_int(per[diff_id], 1, 3)
			if not Check.is_valid_id(diff_id) or earned == null:
				return null
			entry[diff_id] = earned
		out[map_id] = entry
	return out

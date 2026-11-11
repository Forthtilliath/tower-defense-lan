class_name NetPayloads
extends RefCounted
## Validation des messages de salon reçus de l'hôte. Un message invalide est ignoré en entier.
## Règles du salon partagées par l'hôte et les joueurs (pseudos, couleurs, vote de difficulté).

const MAX_PEER_ID := 2147483647


## Liste des joueurs : ids uniques, hôte (1) présent, noms non vides, valeurs bornées par les
## données du jeu, talents conformes à l'arbre de la classe.
## Salon (with_lobby) : [[id, nom, couleur, bâtisseur, vote, niveau, talents, héritage], ...]
## Partie : [[id, nom, couleur, bâtisseur, talents, héritage], ...]
static func parse_roster(raw: Variant, data: GameData, max_players: int, with_lobby: bool) -> Variant:
	if typeof(raw) != TYPE_ARRAY:
		return null
	var list: Array = raw
	if list.is_empty() or list.size() > max_players:
		return null
	var out := []
	var seen := {}
	var max_level := int(data.progression["max_level"])
	for e in list:
		if typeof(e) != TYPE_ARRAY or e.size() != (8 if with_lobby else 6):
			return null
		var id = Check.as_int(e[0], 1, MAX_PEER_ID)
		var player_name := Check.sanitize_name(e[1])
		var color = Check.as_int(e[2], 0, max_players - 1)
		var builder = Check.as_int(e[3], 0, data.builders.size() - 1)
		var vote = Check.as_int(e[4], 0, data.difficulties.size() - 1) if with_lobby else 0
		var level = Check.as_int(e[5], 1, max_level) if with_lobby else max_level
		if id == null or player_name == "" or color == null or builder == null or vote == null or level == null or seen.has(id):
			return null
		var talents = TalentRules.validate(data, builder, e[6] if with_lobby else e[4], TalentRules.points(level))
		var heritage = TalentRules.parse_heritage(data, e[7] if with_lobby else e[5])
		if talents == null or heritage == null:
			return null
		seen[id] = true
		out.append([id, player_name, color, builder, vote, level, talents, heritage] if with_lobby else [id, player_name, color, builder, talents, heritage])
	if not seen.has(1):
		return null
	return out


static func parse_lobby(raw: Variant, data: GameData, mode_count: int, max_players: int) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw
	var roster = parse_roster(d.get("players"), data, max_players, true)
	var options = _parse_options(d, data, mode_count)
	if roster == null or options == null:
		return null
	var players := {}
	for e in roster:
		players[e[0]] = {"name": e[1], "color": e[2], "builder": e[3], "vote": e[4], "level": e[5], "talents": e[6], "heritage": e[7]}
	options["players"] = players
	return options


static func parse_config(raw: Variant, data: GameData, mode_count: int, max_players: int) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw
	var roster = parse_roster(d.get("roster"), data, max_players, false)
	var options = _parse_options(d, data, mode_count)
	var difficulty = Check.as_int(d.get("difficulty"), 0, data.difficulties.size() - 1)
	if roster == null or options == null or difficulty == null:
		return null
	if not heritage_on(options) and roster.any(func(e: Array) -> bool: return not e[5].is_empty()):
		return null  # héritage désactivé : aucun joueur ne doit en recevoir
	options["roster"] = roster
	options["difficulty"] = difficulty
	return options


## Mode, carte, rythme, lancement et héritage : indices bornés.
static func _parse_options(d: Dictionary, data: GameData, mode_count: int) -> Variant:
	var mode = Check.as_int(d.get("mode"), 0, mode_count - 1)
	var map = Check.as_int(d.get("map"), 0, data.maps.size() - 1)
	var rhythm = Check.as_int(d.get("rhythm"), 0, SimMatch.RHYTHM_NAMES.size() - 1)
	var launch = Check.as_int(d.get("launch"), 0, SimMatch.LAUNCH_NAMES.size() - 1)
	var heritage = Check.as_int(d.get("heritage"), 0, SimMatch.HERITAGE_NAMES.size() - 1)
	if mode == null or map == null or rhythm == null or launch == null or heritage == null:
		return null
	return {"mode": mode, "map": map, "rhythm": rhythm, "launch": launch, "heritage": heritage}


## Roster de la partie : [[id, nom, couleur, bâtisseur, talents, héritage], ...] ; héritage
## désactivé par l'hôte : listes vides, la simulation n'en applique aucun.
static func match_roster(players: Dictionary, ids: Array, settings: Dictionary) -> Array:
	var out := []
	for id in ids:
		var p: Dictionary = players[id]
		out.append([id, p["name"], p["color"], p["builder"], p["talents"], p["heritage"] if heritage_on(settings) else []])
	return out


## Options du salon ou de la partie : l'héritage est-il actif ?
static func heritage_on(settings: Dictionary) -> bool:
	return int(settings.get("heritage", SimMatch.Heritage.ON)) == SimMatch.Heritage.ON


## Difficulté retenue : la plus votée ; en cas d'égalité, la plus facile des ex æquo.
static func voted_difficulty(players: Dictionary, count: int) -> int:
	var tally := tally_votes(players, count)
	var best := 0
	for i in count:
		if tally[i] > tally[best]:
			best = i
	return best


static func tally_votes(players: Dictionary, count: int) -> Array[int]:
	var tally: Array[int] = []
	tally.resize(count)
	tally.fill(0)
	for id in players:
		var v := int(players[id].get("vote", 0))
		if v >= 0 and v < count:
			tally[v] += 1
	return tally


## Pseudo unique dans le salon : ajoute un numéro si le nom est déjà pris.
static func unique_name(players: Dictionary, wanted: String) -> String:
	var taken := []
	for id in players:
		taken.append(players[id]["name"])
	var candidate := wanted
	var n := 2
	while taken.has(candidate):
		candidate = "%s %d" % [wanted.left(Check.NAME_MAX - 2), n]
		n += 1
	return candidate


## Première couleur de joueur libre.
static func free_color(players: Dictionary, max_players: int) -> int:
	var used := []
	for id in players:
		used.append(players[id]["color"])
	for c in max_players:
		if not used.has(c):
			return c
	return 0

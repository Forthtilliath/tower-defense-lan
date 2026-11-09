class_name NetPayloads
extends RefCounted
## Validation des messages de salon reçus de l'hôte. Un message invalide est ignoré en entier.

const MAX_PEER_ID := 2147483647


## Liste [[id, nom, couleur], ...] : ids uniques, hôte (1) présent, noms non vides.
static func parse_roster(raw: Variant, max_players: int) -> Variant:
	if typeof(raw) != TYPE_ARRAY:
		return null
	var list: Array = raw
	if list.is_empty() or list.size() > max_players:
		return null
	var out := []
	var seen := {}
	for e in list:
		if typeof(e) != TYPE_ARRAY or e.size() != 3:
			return null
		var id = Check.as_int(e[0], 1, MAX_PEER_ID)
		var player_name := Check.sanitize_name(e[1])
		var color = Check.as_int(e[2], 0, max_players - 1)
		if id == null or player_name == "" or color == null or seen.has(id):
			return null
		seen[id] = true
		out.append([id, player_name, color])
	if not seen.has(1):
		return null
	return out


static func parse_lobby(raw: Variant, map_count: int, mode_count: int, max_players: int) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw
	var roster = parse_roster(d.get("players"), max_players)
	var mode = Check.as_int(d.get("mode"), 0, mode_count - 1)
	var map = Check.as_int(d.get("map"), 0, map_count - 1)
	if roster == null or mode == null or map == null:
		return null
	var players := {}
	for e in roster:
		players[e[0]] = {"name": e[1], "color": e[2]}
	return {"players": players, "mode": mode, "map": map}


static func parse_config(raw: Variant, map_count: int, mode_count: int, max_players: int) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw
	var roster = parse_roster(d.get("roster"), max_players)
	var mode = Check.as_int(d.get("mode"), 0, mode_count - 1)
	var map = Check.as_int(d.get("map"), 0, map_count - 1)
	if roster == null or mode == null or map == null:
		return null
	return {"mode": mode, "map": map, "roster": roster}


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
class_name MapValidator
extends RefCounted
## Validation des cartes (pour DataValidator) : en-tête, grille, zones, entrées par vague, thème.
## Comme pour le reste des données, la première anomalie fait rejeter tout le fichier.

const MAX_MAPS := 24


static func maps(v: DataValidator, src: Variant, waves: Dictionary, specials: Array) -> Variant:
	var list = v._list(src, 1, MAX_MAPS, "maps")
	if list == null:
		return null
	var out: Array[MapDef] = []
	var ids := {}
	for i in list.size():
		var parsed = _map(v, list[i], "maps[%d]" % i, waves, specials)
		if parsed == null:
			return null
		if ids.has(parsed.id):
			return v._fail("maps[%d] : id « %s » en double" % [i, parsed.id])
		ids[parsed.id] = true
		out.append(parsed)
	return out


static func _map(v: DataValidator, src: Variant, where: String, waves: Dictionary, specials: Array) -> Variant:
	var head = v._obj(src, DataSchema.MAP, where)
	if head == null:
		return null
	if head["min_players"] > head["max_players"]:
		return v._fail("%s : min_players dépasse max_players" % where)
	if not DataSchema.THEMES.has(head["theme"]):
		return v._fail("%s : thème « %s » inconnu" % [where, head["theme"]])
	var rows = v._list(src.get("rows"), MapDef.MIN_SIZE, MapDef.MAX_SIZE, where + ".rows")
	var wave_ids = v._list(src.get("waves"), 1, 100, where + ".waves")
	var pattern = v._list(src.get("entries", []), 0, MapSpawns.MAX_PATTERN, where + ".entries")
	if rows == null or wave_ids == null or pattern == null:
		return null
	var typed_waves: Array[String] = []
	for w in wave_ids:
		if typeof(w) != TYPE_STRING or not waves.has(w):
			return v._fail("%s.waves : vague « %s » inconnue" % [where, str(w).left(30)])
		typed_waves.append(w)
	var parsed = MapDef.parse(head["id"], head["name"], rows, typed_waves, specials)
	if typeof(parsed) == TYPE_STRING:
		return v._fail("%s : %s" % [where, parsed])
	if src.has("zones"):
		var zone_rows = v._list(src["zones"], MapDef.MIN_SIZE, MapDef.MAX_SIZE, where + ".zones")
		if zone_rows == null:
			return null
		var zone_err: String = parsed.set_zones(zone_rows)
		if zone_err != "":
			return v._fail("%s : %s" % [where, zone_err])
	parsed.flyer_speed = head["flyer_speed"]
	parsed.min_players = head["min_players"]
	parsed.max_players = head["max_players"]
	parsed.lanes = head["lanes"]
	parsed.tier = head["tier"]
	parsed.monster_hp = head["hp"]
	parsed.theme = head["theme"]
	if parsed.lanes > parsed.start_count():
		return v._fail("%s : %d couloirs pour %d départs" % [where, parsed.lanes, parsed.start_count()])
	var entry_err := MapSpawns.check(parsed, pattern)
	if entry_err != "":
		return v._fail("%s : %s" % [where, entry_err])
	parsed.entries.assign(pattern)
	return parsed

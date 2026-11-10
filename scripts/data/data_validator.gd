class_name DataValidator
extends RefCounted
## Valide le JSON des données du jeu avant de l'utiliser (schémas : DataSchema).
## Le fichier entier est rejeté à la première anomalie (rien n'est appliqué),
## les clés inconnues sont ignorées et ne sont pas recopiées.

## Nombre maximal de tourelles (dans les données, et par liste d'une classe ou d'un talent).
const MAX_TOWERS := 48

var error := ""


## Vérifie `root` et, seulement s'il est entièrement valide, remplit `gd`.
func fill(root: Variant, gd: GameData) -> bool:
	if typeof(root) != TYPE_DICTIONARY:
		_fail("racine : objet attendu")
		return false
	var player = _obj(root.get("player"), DataSchema.PLAYER, "player")
	var scaling = _obj(root.get("coop_scaling"), DataSchema.COOP_SCALING, "coop_scaling")
	var difficulties = _collection(root.get("difficulties"), 8, "difficulties", _plain.bind(DataSchema.DIFFICULTY))
	var specials = _specials(root.get("special_tiles"))
	var towers = _collection(root.get("towers"), MAX_TOWERS, "towers", _tower)
	var monsters = _collection(root.get("monsters"), 32, "monsters", _monster)
	var modifiers = _collection(root.get("wave_modifiers"), 16, "wave_modifiers", _plain.bind(DataSchema.WAVE_MODIFIER.merged(DataSchema.PASSIVE_TRAITS)), 0)
	var progression = _obj(root.get("progression", {}), DataSchema.PROGRESSION, "progression")
	var tiers = TreeValidator.tiers(self, root.get("talent_tiers", [0]))
	if player == null or scaling == null or difficulties == null or specials == null or progression == null \
			or tiers == null or towers == null or monsters == null or modifiers == null or not _check_splits(monsters[0]):
		return false
	var common = TreeValidator.common_towers(self, root.get("common_towers"), towers[0])
	if common == null:
		return false
	var builders = _collection(root.get("builders"), 8, "builders", TreeValidator.builder.bind(self, towers[0], tiers.size()))
	var waves = _collection(root.get("waves"), 100, "waves", _wave.bind(monsters[0], modifiers[0]))
	if builders == null or waves == null:
		return false
	var maps = _maps(root.get("maps"), waves[0], specials)
	if maps == null:
		return false
	gd.player = player
	gd.coop_scaling = scaling
	gd.progression = progression
	gd.talent_tiers.assign(tiers)
	gd.common_towers.assign(common)
	gd.difficulties.assign(_ordered(difficulties))
	gd.builders.assign(_ordered(builders))
	gd.modifiers = modifiers[0]
	gd.specials.assign(specials)
	gd.towers = towers[0]
	gd.tower_order = towers[1]
	gd.monsters = monsters[0]
	gd.monster_order = monsters[1]
	gd.waves = waves[0]
	gd.maps = maps
	return true


static func _ordered(collection: Array) -> Array:
	return collection[1].map(func(id: String) -> Dictionary: return collection[0][id])


## Liste d'objets avec un « id » unique. Renvoie [dictionnaire par id, ordre des ids] ou null.
func _collection(src: Variant, max_size: int, where: String, check: Callable, min_size := 1) -> Variant:
	var list = _list(src, min_size, max_size, where)
	if list == null:
		return null
	var by_id := {}
	var order: Array[String] = []
	for i in list.size():
		var item = check.call(list[i], "%s[%d]" % [where, i])
		if item == null:
			return null
		if by_id.has(item["id"]):
			return _fail("%s[%d] : id « %s » en double" % [where, i, item["id"]])
		by_id[item["id"]] = item
		order.append(item["id"])
	return [by_id, order]


func _plain(src: Variant, where: String, schema: Dictionary) -> Variant:
	return _obj(src, schema, where)


func _tower(src: Variant, where: String) -> Variant:
	var t = _obj(src, DataSchema.TOWER, where)
	if t == null:
		return null
	if not t["air"] and not t["ground"]:
		return _fail("%s : la tourelle doit viser l'air, le sol ou les deux" % where)
	if not DataSchema.ATTACKS.has(t["attack"]):
		return _fail("%s : façon de frapper « %s » inconnue" % [where, t["attack"]])
	if t["element"] != "" and not DataSchema.ELEMENTS.has(t["element"]):
		return _fail("%s : élément « %s » inconnu" % [where, t["element"]])
	var levels = _list(src.get("levels"), 1, 5, where + ".levels")
	if levels == null:
		return null
	var out_levels := []
	for i in levels.size():
		var lvl = _obj(levels[i], DataSchema.TOWER_LEVEL, "%s.levels[%d]" % [where, i])
		if lvl == null:
			return null
		out_levels.append(lvl)
	t["levels"] = out_levels
	return t


## Liste d'identifiants de tourelles connues, sans doublon (au moins `lo`).
func tower_ids(src: Variant, lo: int, where: String, towers: Dictionary) -> Variant:
	var list = _list(src, lo, MAX_TOWERS, where)
	if list == null:
		return null
	var ids: Array[String] = []
	for id in list:
		if typeof(id) != TYPE_STRING or not towers.has(id) or ids.has(id):
			return _fail("%s : tourelle « %s » inconnue ou en double" % [where, str(id).left(30)])
		ids.append(id)
	return ids


## Monstre : division, et capacités dont les champs vont ensemble ; un brouillage plus long
## que son intervalle désactiverait les tourelles pour toujours.
func _monster(src: Variant, where: String) -> Variant:
	var m = _obj(src, DataSchema.MONSTER.merged(DataSchema.PASSIVE_TRAITS).merged(DataSchema.ABILITIES), where)
	if m == null:
		return null
	if (m["split_into"] == "") != (m["split_count"] == 0):
		return _fail("%s : split_into et split_count vont ensemble" % where)
	for group in DataSchema.LINKED:
		if group.any(func(k: String) -> bool: return m[k] > 0.0) and not group.all(func(k: String) -> bool: return m[k] > 0.0):
			return _fail("%s : %s vont ensemble" % [where, ", ".join(group)])
	if m["jam_interval"] > 0.0 and m["jam_duration"] >= m["jam_interval"] * 0.5:
		return _fail("%s : jam_duration doit rester sous la moitié de jam_interval" % where)
	return m


## Division à la mort : le monstre produit doit exister et ne pas se diviser lui-même.
func _check_splits(monsters: Dictionary) -> bool:
	for id in monsters:
		var target: String = monsters[id]["split_into"]
		if target == "":
			continue
		if not monsters.has(target):
			_fail("monsters « %s » : split_into « %s » inconnu" % [id, target])
			return false
		if monsters[target]["split_into"] != "":
			_fail("monsters « %s » : « %s » ne peut pas se diviser à son tour" % [id, target])
			return false
	return true


## Cases spéciales : symbole d'un caractère, unique, distinct des cases de base.
func _specials(src: Variant) -> Variant:
	var list = _list(src, 0, 8, "special_tiles")
	if list == null:
		return null
	var out := []
	var seen := {}
	for i in list.size():
		var where := "special_tiles[%d]" % i
		var s = _obj(list[i], DataSchema.SPECIAL, where)
		if s == null:
			return null
		var ch: String = s["char"]
		if MapDef.CHARS.has(ch) or seen.has(ch) or ch == " ":
			return _fail("%s : symbole « %s » déjà utilisé" % [where, ch])
		seen[ch] = true
		out.append(s)
	return out


func _wave(src: Variant, where: String, monsters: Dictionary, modifiers: Dictionary) -> Variant:
	var w = _obj(src, DataSchema.WAVE, where)
	if w == null:
		return null
	if w["modifier"] != "" and not modifiers.has(w["modifier"]):
		return _fail("%s : vague spéciale « %s » inconnue" % [where, w["modifier"]])
	var groups = _list(src.get("groups"), 1, 10, where + ".groups")
	if groups == null:
		return null
	var out_groups := []
	for i in groups.size():
		var g = _obj(groups[i], DataSchema.GROUP, "%s.groups[%d]" % [where, i])
		if g == null:
			return null
		if not monsters.has(g["monster"]):
			return _fail("%s.groups[%d] : monstre « %s » inconnu" % [where, i, g["monster"]])
		out_groups.append(g)
	w["groups"] = out_groups
	return w


func _maps(src: Variant, waves: Dictionary, specials: Array) -> Variant:
	var list = _list(src, 1, 20, "maps")
	if list == null:
		return null
	var out: Array[MapDef] = []
	for i in list.size():
		var where := "maps[%d]" % i
		var head = _obj(list[i], DataSchema.MAP, where)
		if head == null:
			return null
		if head["min_players"] > head["max_players"]:
			return _fail("%s : min_players dépasse max_players" % where)
		var rows = _list(list[i].get("rows"), MapDef.MIN_SIZE, MapDef.MAX_SIZE, where + ".rows")
		var wave_ids = _list(list[i].get("waves"), 1, 100, where + ".waves")
		if rows == null or wave_ids == null:
			return null
		var typed_waves: Array[String] = []
		for w in wave_ids:
			if typeof(w) != TYPE_STRING or not waves.has(w):
				return _fail("%s.waves : vague « %s » inconnue" % [where, str(w).left(30)])
			typed_waves.append(w)
		var parsed = MapDef.parse(head["id"], head["name"], rows, typed_waves, specials)
		if typeof(parsed) == TYPE_STRING:
			return _fail("%s : %s" % [where, parsed])
		if list[i].has("zones"):
			var zone_rows = _list(list[i]["zones"], MapDef.MIN_SIZE, MapDef.MAX_SIZE, where + ".zones")
			if zone_rows == null:
				return null
			var zone_err: String = parsed.set_zones(zone_rows)
			if zone_err != "":
				return _fail("%s : %s" % [where, zone_err])
		parsed.flyer_speed = head["flyer_speed"]
		parsed.min_players = head["min_players"]
		parsed.max_players = head["max_players"]
		parsed.lanes = head["lanes"]
		if parsed.lanes > parsed.start_count():
			return _fail("%s : %d couloirs pour %d départs" % [where, parsed.lanes, parsed.start_count()])
		out.append(parsed)
	return out


func _obj(src: Variant, schema: Dictionary, where: String) -> Variant:
	if typeof(src) != TYPE_DICTIONARY:
		return _fail("%s : objet attendu" % where)
	var d: Dictionary = src
	var out := {}
	for key in schema:
		var rule: Array = schema[key]
		var argc: int = DataSchema.ARGC.get(rule[0], 0)
		if not d.has(key):
			if rule.size() > 1 + argc:
				out[key] = rule[1 + argc]
				continue
			return _fail("%s : champ « %s » manquant" % [where, key])
		var v = _value(d[key], rule, "%s.%s" % [where, key])
		if v == null:
			return null
		out[key] = v
	return out


func _value(v: Variant, rule: Array, where: String) -> Variant:
	var out: Variant = null
	match rule[0]:
		"int":
			out = Check.as_int(v, rule[1], rule[2])
		"num":
			out = Check.as_num(v, rule[1], rule[2])
		"bool":
			out = Check.as_bool(v)
		"text":
			out = Check.as_text(v, rule[1])
		"id":
			out = v if Check.is_valid_id(v) else null
			if out == null and typeof(v) == TYPE_STRING and v == "" and rule.size() > 1:
				out = ""  # identifiant facultatif explicitement vide
		"color":
			out = v if Check.is_color(v) else null
	if out == null:
		return _fail("%s : valeur invalide (%s)" % [where, str(v).left(40)])
	return out


func _list(src: Variant, lo: int, hi: int, where: String) -> Variant:
	if typeof(src) != TYPE_ARRAY:
		return _fail("%s : liste attendue" % where)
	var a: Array = src
	if a.size() < lo or a.size() > hi:
		return _fail("%s : %d à %d éléments attendus" % [where, lo, hi])
	return a


func _fail(msg: String) -> Variant:
	if error == "":
		error = msg
	return null

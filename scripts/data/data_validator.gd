class_name DataValidator
extends RefCounted
## Valide le JSON des données du jeu avant de l'utiliser.
## Le fichier entier est rejeté à la première anomalie (rien n'est appliqué),
## les clés inconnues sont ignorées et ne sont pas recopiées.
##
## Règle de schéma : [type, arguments..., (valeur par défaut)].
## Types : "int" (min, max), "num" (min, max), "text" (longueur max), "bool", "id", "color".

const ARGC := {"int": 2, "num": 2, "text": 1}

const PLAYER := {"start_gold": ["int", 0, 100000]}
const COOP_SCALING := {"hp": ["num", 0.0, 5.0], "count": ["num", 0.0, 5.0]}
const DIFFICULTY := {
	"id": ["id"], "name": ["text", 24], "hp": ["num", 0.1, 10.0], "lives": ["int", 1, 1000],
	"gold": ["num", 0.1, 10.0], "reward": ["num", 0.1, 10.0],
}
const SPECIAL := {
	"char": ["text", 1], "id": ["id"], "name": ["text", 24], "color": ["color"],
	"description": ["text", 120, ""], "range": ["num", 0.5, 3.0, 1.0], "damage": ["num", 0.5, 5.0, 1.0],
	"rate": ["num", 0.5, 5.0, 1.0], "gold_per_wave": ["int", 0, 10000, 0],
}
const TOWER := {
	"id": ["id"], "name": ["text", 24], "description": ["text", 120, ""],
	"color": ["color"], "air": ["bool"], "ground": ["bool"],
}
const TOWER_LEVEL := {
	"cost": ["int", 1, 100000], "damage": ["num", 0.0, 100000.0],
	"range": ["num", 0.5, 12.0], "rate": ["num", 0.05, 20.0],
	"projectile_speed": ["num", 1.0, 60.0], "splash": ["num", 0.0, 5.0, 0.0],
	"slow_factor": ["num", 0.1, 1.0, 1.0], "slow_duration": ["num", 0.0, 10.0, 0.0],
	"chain": ["int", 0, 10, 0], "poison_dps": ["num", 0.0, 100000.0, 0.0],
	"poison_duration": ["num", 0.0, 30.0, 0.0],
}
const MONSTER := {
	"id": ["id"], "name": ["text", 24], "color": ["color"],
	"hp": ["num", 1.0, 1000000.0], "speed": ["num", 0.1, 10.0],
	"gold": ["int", 0, 100000], "damage": ["int", 1, 1000], "flying": ["bool"],
	"size": ["num", 0.2, 1.0, 0.5], "send_cost": ["int", 0, 100000, 0],
	"income": ["int", 0, 10000, 0], "armor": ["num", 0.0, 100000.0, 0.0],
	"regen": ["num", 0.0, 100000.0, 0.0], "slow_immune": ["bool", false],
	"heal_radius": ["num", 0.0, 10.0, 0.0], "heal_rate": ["num", 0.0, 100000.0, 0.0],
	"split_into": ["id", ""], "split_count": ["int", 0, 10, 0],
}
const WAVE := {"id": ["id"], "gold": ["int", 0, 100000, 0], "hp": ["num", 0.1, 100.0, 1.0]}
const GROUP := {"monster": ["id"], "count": ["int", 1, 500], "interval": ["num", 0.05, 30.0]}
## flyer_speed : ralentit les volants sur les cartes où leur ligne droite est un raccourci énorme.
const MAP := {"id": ["id"], "name": ["text", 32], "flyer_speed": ["num", 0.2, 1.0, 1.0]}

var error := ""


## Vérifie `root` et, seulement s'il est entièrement valide, remplit `gd`.
func fill(root: Variant, gd: GameData) -> bool:
	if typeof(root) != TYPE_DICTIONARY:
		_fail("racine : objet attendu")
		return false
	var player = _obj(root.get("player"), PLAYER, "player")
	var scaling = _obj(root.get("coop_scaling"), COOP_SCALING, "coop_scaling")
	var difficulties = _collection(root.get("difficulties"), 8, "difficulties", _difficulty)
	var specials = _specials(root.get("special_tiles"))
	var towers = _collection(root.get("towers"), 16, "towers", _tower)
	var monsters = _collection(root.get("monsters"), 32, "monsters", _monster)
	if player == null or scaling == null or difficulties == null or specials == null \
			or towers == null or monsters == null or not _check_splits(monsters[0]):
		return false
	var waves = _collection(root.get("waves"), 100, "waves", _wave.bind(monsters[0]))
	if waves == null:
		return false
	var maps = _maps(root.get("maps"), waves[0], specials)
	if maps == null:
		return false
	gd.player = player
	gd.coop_scaling = scaling
	gd.difficulties.assign(difficulties[1].map(func(id: String) -> Dictionary: return difficulties[0][id]))
	gd.specials.assign(specials)
	gd.towers = towers[0]
	gd.tower_order = towers[1]
	gd.monsters = monsters[0]
	gd.monster_order = monsters[1]
	gd.waves = waves[0]
	gd.maps = maps
	return true


## Liste d'objets avec un « id » unique. Renvoie [dictionnaire par id, ordre des ids] ou null.
func _collection(src: Variant, max_size: int, where: String, check: Callable) -> Variant:
	var list = _list(src, 1, max_size, where)
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


func _tower(src: Variant, where: String) -> Variant:
	var t = _obj(src, TOWER, where)
	if t == null:
		return null
	if not t["air"] and not t["ground"]:
		return _fail("%s : la tourelle doit viser l'air, le sol ou les deux" % where)
	var levels = _list(src.get("levels"), 1, 5, where + ".levels")
	if levels == null:
		return null
	var out_levels := []
	for i in levels.size():
		var lvl = _obj(levels[i], TOWER_LEVEL, "%s.levels[%d]" % [where, i])
		if lvl == null:
			return null
		out_levels.append(lvl)
	t["levels"] = out_levels
	return t


func _monster(src: Variant, where: String) -> Variant:
	var m = _obj(src, MONSTER, where)
	if m != null and (m["split_into"] == "") != (m["split_count"] == 0):
		return _fail("%s : split_into et split_count vont ensemble" % where)
	return m


func _difficulty(src: Variant, where: String) -> Variant:
	return _obj(src, DIFFICULTY, where)


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
		var s = _obj(list[i], SPECIAL, where)
		if s == null:
			return null
		var ch: String = s["char"]
		if MapDef.CHARS.has(ch) or seen.has(ch) or ch == " ":
			return _fail("%s : symbole « %s » déjà utilisé" % [where, ch])
		seen[ch] = true
		out.append(s)
	return out


func _wave(src: Variant, where: String, monsters: Dictionary) -> Variant:
	var w = _obj(src, WAVE, where)
	if w == null:
		return null
	var groups = _list(src.get("groups"), 1, 10, where + ".groups")
	if groups == null:
		return null
	var out_groups := []
	for i in groups.size():
		var g = _obj(groups[i], GROUP, "%s.groups[%d]" % [where, i])
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
		var head = _obj(list[i], MAP, where)
		if head == null:
			return null
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
		parsed.flyer_speed = head["flyer_speed"]
		out.append(parsed)
	return out


func _obj(src: Variant, schema: Dictionary, where: String) -> Variant:
	if typeof(src) != TYPE_DICTIONARY:
		return _fail("%s : objet attendu" % where)
	var d: Dictionary = src
	var out := {}
	for key in schema:
		var rule: Array = schema[key]
		var argc: int = ARGC.get(rule[0], 0)
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

class_name TreeValidator
extends RefCounted
## Validation des classes (tronc commun de tourelles, bonus, arbres de talents) et des paliers,
## avec les outils de DataValidator (même règle : rejet du fichier entier à la première anomalie).

const MAX_BRANCHES := 6  # tronc + spécialisations
const MAX_TALENTS := 8  # par branche


## Tronc commun : tourelles ouvertes à tous, de quoi tirer sur l'air et le sol (hors soutien).
static func common_towers(v: DataValidator, src: Variant, towers: Dictionary) -> Variant:
	var ids = v.tower_ids(src, 1, "common_towers", towers)
	if ids == null:
		return null
	var air := false
	var ground := false
	for id in ids:
		if not towers[id]["support"]:
			air = air or towers[id]["air"]
			ground = ground or towers[id]["ground"]
	if not air or not ground:
		return v._fail("common_towers : il faut au moins une tourelle contre l'air et une contre le sol")
	return ids


## Classe : tourelles en plus du tronc commun et tourelles visées par son bonus (listes
## facultatives), puis ses branches de talents.
static func builder(src: Variant, where: String, v: DataValidator, towers: Dictionary, tier_count: int) -> Variant:
	var b = v._obj(src, DataSchema.BUILDER, where)
	if b == null:
		return null
	var extra = v.tower_ids(src.get("towers", []), 0, where + ".towers", towers)
	var bonus = v.tower_ids(src.get("bonus_towers", []), 0, where + ".bonus_towers", towers)
	if extra == null or bonus == null:
		return null
	b["towers"] = extra
	b["bonus_towers"] = bonus
	var list = branches(v, src.get("branches", []), where, towers, tier_count)
	if list == null:
		return null
	b["branches"] = list
	if src.has("heritage"):  # bonus donné aux autres classes une fois celle-ci au niveau maximum
		var heritage = _talent(v, src["heritage"], where + ".heritage", towers, tier_count)
		if heritage == null:
			return null
		b["heritage"] = heritage
	return b


## Points à dépenser dans une branche pour chaque palier : entiers croissants, le premier à 0.
static func tiers(v: DataValidator, src: Variant) -> Variant:
	var list = v._list(src, 1, 6, "talent_tiers")
	if list == null:
		return null
	var out: Array[int] = []
	for i in list.size():
		var n = Check.as_int(list[i], 0, 100)
		if n == null or (i == 0 and n != 0) or (i > 0 and n < out[i - 1]):
			return v._fail("talent_tiers : entiers croissants attendus, en commençant par 0")
		out.append(n)
	return out


## Branches d'une classe : un tronc au plus, talents aux identifiants uniques (dans tout l'arbre),
## paliers existants, tourelles connues, et au moins un bonus ou un déblocage par talent.
static func branches(v: DataValidator, src: Variant, where: String, towers: Dictionary, tier_count: int) -> Variant:
	var list = v._list(src, 0, MAX_BRANCHES, where + ".branches")
	if list == null:
		return null
	var out := []
	var seen := {}
	var trunks := 0
	for i in list.size():
		var bw := "%s.branches[%d]" % [where, i]
		var branch = v._obj(list[i], DataSchema.BRANCH, bw)
		var talents = v._list(list[i].get("talents") if typeof(list[i]) == TYPE_DICTIONARY else null, 1, MAX_TALENTS, bw + ".talents")
		if branch == null or talents == null:
			return null
		if branch["trunk"]:
			trunks += 1
			if trunks > 1:
				return v._fail("%s : un seul tronc commun par classe" % bw)
		var out_talents := []
		for k in talents.size():
			var t = _talent(v, talents[k], "%s.talents[%d]" % [bw, k], towers, tier_count)
			if t == null:
				return null
			if seen.has(t["id"]):
				return v._fail("%s : talent « %s » en double" % [bw, t["id"]])
			seen[t["id"]] = true
			out_talents.append(t)
		branch["talents"] = out_talents
		out.append(branch)
	return out


static func _talent(v: DataValidator, src: Variant, where: String, towers: Dictionary, tier_count: int) -> Variant:
	var t = v._obj(src, DataSchema.TALENT, where)
	if t == null:
		return null
	if t["tier"] > tier_count:
		return v._fail("%s : palier %d inexistant" % [where, t["tier"]])
	if t["unlock"] != "" and not towers.has(t["unlock"]):
		return v._fail("%s : tourelle à débloquer « %s » inconnue" % [where, t["unlock"]])
	var ids = v.tower_ids(src.get("towers", []), 0, where + ".towers", towers)
	if ids == null:
		return null
	t["towers"] = ids
	var grant = v._obj(src.get("grant", {}), DataSchema.GRANT, where + ".grant")
	if grant == null:
		return null
	t["grant"] = grant
	var effect: bool = t["unlock"] != "" or t["imbue_all"] or grant.values().any(func(x: Variant) -> bool: return x > 0)
	for key in PlayerKit.STATS + PlayerKit.ECONOMY:
		effect = effect or t[key] > 0
	if not effect:
		return v._fail("%s : le talent ne fait rien" % where)
	return t

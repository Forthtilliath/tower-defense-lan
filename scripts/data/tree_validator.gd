class_name TreeValidator
extends RefCounted
## Validation des arbres de talents des bâtisseurs et des paliers, avec les outils de DataValidator
## (même règle : rejet du fichier entier à la première anomalie).

const MAX_BRANCHES := 4
const MAX_TALENTS := 8  # par branche


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


## Branches d'un bâtisseur : talents aux identifiants uniques (dans tout l'arbre), paliers
## existants, tourelles connues, et au moins un bonus ou un déblocage par talent.
static func branches(v: DataValidator, src: Variant, where: String, towers: Dictionary, tier_count: int) -> Variant:
	var list = v._list(src, 0, MAX_BRANCHES, where + ".branches")
	if list == null:
		return null
	var out := []
	var seen := {}
	for i in list.size():
		var bw := "%s.branches[%d]" % [where, i]
		var branch = v._obj(list[i], DataSchema.BRANCH, bw)
		var talents = v._list(list[i].get("talents") if typeof(list[i]) == TYPE_DICTIONARY else null, 1, MAX_TALENTS, bw + ".talents")
		if branch == null or talents == null:
			return null
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
	var targets = v._list(src.get("towers", []), 0, 24, where + ".towers")
	if targets == null:
		return null
	var ids: Array[String] = []
	for id in targets:
		if typeof(id) != TYPE_STRING or not towers.has(id) or ids.has(id):
			return v._fail("%s.towers : tourelle « %s » inconnue ou en double" % [where, str(id).left(30)])
		ids.append(id)
	t["towers"] = ids
	var effect: bool = t["unlock"] != ""
	for key in ["damage", "rate", "range", "cc", "aura", "bounty", "interest", "interest_cap", "start_gold"]:
		effect = effect or t[key] > 0
	if not effect:
		return v._fail("%s : le talent ne fait rien" % where)
	return t

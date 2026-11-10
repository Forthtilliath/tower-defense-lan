class_name ProgressFile
extends RefCounted
## Format et validation du fichier de progression (expérience et talents par classe).
##
## {"v": 1, "last": "<classe>", "classes": {"<classe>": {"xp": <entier>, "talents": {...}}}}
## - Au moindre défaut de structure (type, borne, format), le fichier est rejeté en entier.
## - Les classes inconnues des données sont ignorées (non recopiées).
## - Des talents qui ne respectent plus l'arbre actuel (mise à jour du jeu) sont remis à zéro
##   pour cette classe ; l'expérience est gardée.

const VERSION := 1
const MAX_XP := 100000000
const MAX_CLASSES := 32


## Renvoie [classes, index de la dernière classe] ou null si le fichier est invalide.
static func parse(data: GameData, text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = json.data
	if Check.as_int(d.get("v"), VERSION, VERSION) == null or typeof(d.get("classes")) != TYPE_DICTIONARY:
		return null
	var last_raw = d.get("last", "")
	if typeof(last_raw) != TYPE_STRING:
		return null
	var raw: Dictionary = d["classes"]
	if raw.size() > MAX_CLASSES:
		return null
	var index := {}
	for i in data.builders.size():
		index[data.builders[i]["id"]] = i
	var out := {}
	for key in raw:
		if not Check.is_valid_id(key) or typeof(raw[key]) != TYPE_DICTIONARY:
			return null
		var e: Dictionary = raw[key]
		var amount = Check.as_int(e.get("xp"), 0, MAX_XP)
		if amount == null or typeof(e.get("talents")) != TYPE_DICTIONARY:
			return null
		if not index.has(key):
			continue
		var level := TalentRules.level_for(data, amount)
		var chosen = TalentRules.validate(data, index[key], e["talents"], TalentRules.points(level))
		out[key] = {"xp": amount, "talents": chosen if chosen != null else {}}
	return [out, index.get(last_raw, 0)]


static func serialize(data: GameData, classes: Dictionary, last_builder: int) -> String:
	var last_id: String = data.builders[clampi(last_builder, 0, data.builders.size() - 1)]["id"]
	return JSON.stringify({"v": VERSION, "last": last_id, "classes": classes})

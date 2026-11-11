class_name ProgressFile
extends RefCounted
## Format et validation d'un compte : pseudo, expérience et talents par classe.
##
## {"v": 2, "name": "<pseudo>", "last": "<classe>", "classes": {"<classe>": {"xp": <entier>, "talents": {...}}}}
## - La version 1 (ancien progression.json, sans pseudo) est encore lue, pour la migration.
## - Au moindre défaut de structure (type, borne, format), le fichier est rejeté en entier.
## - Les classes inconnues des données sont ignorées (non recopiées).
## - Des talents qui ne respectent plus l'arbre actuel (mise à jour du jeu) sont remis à zéro
##   pour cette classe ; l'expérience est gardée.
## - Classes renommées (LEGACY) : l'expérience passe à la nouvelle classe, si elle n'en a pas déjà.

const VERSION := 2
const MAX_XP := 100000000
const MAX_CLASSES := 32
## Refonte des classes (2026-11) : l'Enchanteur devient le Support.
const LEGACY := {"enchanter": "support"}


## Renvoie [classes, index de la dernière classe, pseudo] ou null si le fichier est invalide.
## Le pseudo est "" pour un fichier de version 1 ; il est obligatoire et déjà propre en version 2.
static func parse(data: GameData, text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = json.data
	var version = Check.as_int(d.get("v"), 1, VERSION)
	if version == null or typeof(d.get("classes")) != TYPE_DICTIONARY:
		return null
	var name := ""
	if version >= 2:
		name = Check.sanitize_name(d.get("name"))
		if name == "" or name != d.get("name"):
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
		var id: String = key if index.has(key) else LEGACY.get(key, "")
		if not index.has(id) or (id != key and raw.has(id)):
			continue
		var level := TalentRules.level_for(data, amount)
		var chosen = TalentRules.validate(data, index[id], e["talents"], TalentRules.points(level))
		out[id] = {"xp": amount, "talents": chosen if chosen != null else {}}
	return [out, index.get(LEGACY.get(last_raw, last_raw), 0), name]


static func serialize(data: GameData, name: String, classes: Dictionary, last_builder: int) -> String:
	var last_id: String = data.builders[clampi(last_builder, 0, data.builders.size() - 1)]["id"]
	return JSON.stringify({"v": VERSION, "name": name, "last": last_id, "classes": classes})

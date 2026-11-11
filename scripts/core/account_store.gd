class_name AccountStore
extends RefCounted
## Comptes enregistrés sur l'appareil : un fichier par compte, « <id>.json » dans le dossier
## des comptes (pseudo et progression, format et validation : ProgressFile).
## - Écriture dans un fichier temporaire puis renommage : jamais de sauvegarde à moitié écrite.
## - Un fichier illisible n'est jamais effacé : il est renommé « <id>.invalid.json ».
## - Le dossier est un paramètre pour que les tests travaillent à part.

const DIR := "user://accounts"
const MAX_ACCOUNTS := 12
const MAX_SIZE := 64 * 1024
const INVALID_SUFFIX := ".invalid.json"


## Identifiant aléatoire de 16 caractères hexadécimaux (valide pour Check.is_valid_id).
static func new_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x" % [rng.randi(), rng.randi()]


static func path(id: String, dir := DIR) -> String:
	return dir.path_join(id + ".json")


## Comptes valides, du plus récemment modifié au plus ancien :
## {"accounts": [{id, name, classes, last}], "rejected": nombre de fichiers mis de côté}.
static func list(data: GameData, dir := DIR) -> Dictionary:
	var out: Array[Dictionary] = []
	var rejected := 0
	var d := DirAccess.open(dir)
	if d == null:
		return {"accounts": out, "rejected": 0}
	for file in d.get_files():
		if not file.ends_with(".json") or file.ends_with(INVALID_SUFFIX):
			continue
		var id := file.trim_suffix(".json")
		if not Check.is_valid_id(id) or out.size() >= MAX_ACCOUNTS:
			continue
		var account = read(data, id, dir)
		if account == null:
			set_aside(id, dir)
			rejected += 1
			continue
		account["modified"] = FileAccess.get_modified_time(path(id, dir))
		out.append(account)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["modified"] > b["modified"] or (a["modified"] == b["modified"] and a["name"] < b["name"]))
	return {"accounts": out, "rejected": rejected}


## Compte relu et vérifié ({id, name, classes, last, history}), ou null si absent ou invalide.
static func read(data: GameData, id: String, dir := DIR) -> Variant:
	if not Check.is_valid_id(id):
		return null
	var f := FileAccess.open(path(id, dir), FileAccess.READ)
	if f == null or f.get_length() > MAX_SIZE:
		return null
	var parsed = ProgressFile.parse(data, f.get_as_text())
	if parsed == null or parsed[2] == "":
		return null
	return {"id": id, "name": parsed[2], "classes": parsed[0], "last": parsed[1], "history": parsed[3]}


## history : historique des parties (MatchHistory), vide pour un compte neuf.
static func write(data: GameData, id: String, name: String, classes: Dictionary, last: int, dir := DIR, history := {}) -> bool:
	if not Check.is_valid_id(id) or Check.sanitize_name(name) != name or name == "":
		return false
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var tmp := dir.path_join(id + ".tmp")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(ProgressFile.serialize(data, name, classes, last, history))
	f.close()
	return DirAccess.rename_absolute(tmp, path(id, dir)) == OK


static func remove(id: String, dir := DIR) -> bool:
	return Check.is_valid_id(id) and DirAccess.remove_absolute(path(id, dir)) == OK


static func set_aside(id: String, dir := DIR) -> void:
	DirAccess.rename_absolute(path(id, dir), dir.path_join(id + INVALID_SUFFIX))


## Un pseudo déjà pris sur cet appareil (sans tenir compte des majuscules) ?
static func name_taken(accounts: Array, name: String) -> bool:
	return find(accounts, name) != ""


## Identifiant du compte portant ce pseudo (sans tenir compte des majuscules), ou "".
static func find(accounts: Array, name: String) -> String:
	for a in accounts:
		if String(a["name"]).to_lower() == name.to_lower():
			return a["id"]
	return ""


## Texte du fichier d'un compte, revérifié (pour l'envoyer à un autre appareil), ou "".
static func export_text(data: GameData, id: String, dir := DIR) -> String:
	var a = read(data, id, dir)
	return "" if a == null else ProgressFile.serialize(data, a["name"], a["classes"], a["last"], a["history"])


## Ancienne sauvegarde unique (progression.json, avant les comptes) : devient un compte au
## pseudo `name`, et le fichier est renommé (copie gardée). Renvoie l'identifiant créé, ""
## s'il n'y avait rien à migrer, ou null si l'ancien fichier était illisible (mis de côté).
static func migrate(data: GameData, legacy_path: String, name: String, dir := DIR) -> Variant:
	if not FileAccess.file_exists(legacy_path):
		return ""
	var f := FileAccess.open(legacy_path, FileAccess.READ)
	var parsed = null
	if f != null and f.get_length() <= MAX_SIZE:
		parsed = ProgressFile.parse(data, f.get_as_text())
	if f != null:
		f.close()
	var base := legacy_path.get_basename()
	if parsed == null:
		DirAccess.rename_absolute(legacy_path, base + ".invalid.json")
		return null
	var id := new_id()
	if not write(data, id, name, parsed[0], parsed[1], dir):
		return ""
	DirAccess.rename_absolute(legacy_path, base + ".migrated.json")
	return id

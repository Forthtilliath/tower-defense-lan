extends "res://tests/test_base.gd"
## Comptes de l'appareil (AccountStore) : création, relecture, liste, fichiers illisibles mis
## de côté, suppression et migration de l'ancienne progression. Dossier de test à part, vidé.

const DIR := "user://test_accounts"


func _clean() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for file in d.get_files():
		d.remove(file)
	DirAccess.remove_absolute(DIR)


func test_write_read_and_list() -> void:
	var gd := load_data()
	_clean()
	check(AccountStore.list(gd, DIR)["accounts"].is_empty(), "aucun compte au départ")
	var id := AccountStore.new_id()
	check(Check.is_valid_id(id) and id.length() == 16, "identifiant valide : " + id)
	var classes := {"arcanist": {"xp": 300, "talents": {"ar_conductive": 2}}}
	check(AccountStore.write(gd, id, "Forth", classes, 1, DIR), "compte écrit")
	check(not FileAccess.file_exists(DIR.path_join(id + ".tmp")), "fichier temporaire renommé")
	var a = AccountStore.read(gd, id, DIR)
	check(a != null and a["name"] == "Forth" and a["classes"]["arcanist"]["xp"] == 300 and a["last"] == 1, "compte relu")
	check(AccountStore.write(gd, id, "Forth", {"arcanist": {"xp": 500, "talents": {}}}, 0, DIR), "compte réécrit")
	a = AccountStore.read(gd, id, DIR)
	check(a != null and a["classes"]["arcanist"]["xp"] == 500, "réécriture remplace l'ancien fichier")
	check(AccountStore.write(gd, AccountStore.new_id(), "Atthis", {}, 0, DIR), "second compte")
	var listed: Array = AccountStore.list(gd, DIR)["accounts"]
	check(listed.size() == 2, "deux comptes listés")
	check(AccountStore.name_taken(listed, "forth") and not AccountStore.name_taken(listed, "Saucedechoux"), "pseudo déjà pris (sans tenir compte des majuscules)")
	check(AccountStore.remove(id, DIR) and AccountStore.list(gd, DIR)["accounts"].size() == 1, "compte supprimé")
	_clean()


func test_rejects_bad_names_and_ids() -> void:
	var gd := load_data()
	_clean()
	check(not AccountStore.write(gd, "../evil", "Bob", {}, 0, DIR), "identifiant avec chemin refusé")
	check(not AccountStore.write(gd, "abc", "", {}, 0, DIR), "pseudo vide refusé")
	check(not AccountStore.write(gd, "abc", " Bob ", {}, 0, DIR), "pseudo non nettoyé refusé")
	check(AccountStore.read(gd, "../settings", DIR) == null, "lecture hors du dossier refusée")
	check(not AccountStore.remove("..", DIR), "suppression hors du dossier refusée")
	_clean()


func test_invalid_file_set_aside() -> void:
	var gd := load_data()
	_clean()
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR.path_join("deadbeef.json"), FileAccess.WRITE)
	f.store_string("{\"v\": 2, \"name\": \"Bob\", \"classes\": {\"arcanist\": {\"xp\": -1, \"talents\": {}}}}")
	f.close()
	AccountStore.write(gd, "cafe", "Ok", {}, 0, DIR)
	var found := AccountStore.list(gd, DIR)
	check(found["accounts"].size() == 1 and found["rejected"] == 1, "un compte valide, un fichier écarté")
	check(FileAccess.file_exists(DIR.path_join("deadbeef" + AccountStore.INVALID_SUFFIX)), "fichier illisible gardé de côté")
	check(AccountStore.list(gd, DIR)["rejected"] == 0, "fichier écarté une seule fois")
	_clean()


func test_migrates_legacy_progress() -> void:
	var gd := load_data()
	_clean()
	DirAccess.make_dir_recursive_absolute(DIR)
	var legacy := DIR.path_join("legacy/progression.json")
	DirAccess.make_dir_recursive_absolute(legacy.get_base_dir())
	check(AccountStore.migrate(gd, legacy, "Forth", DIR) == "", "rien à migrer")
	var f := FileAccess.open(legacy, FileAccess.WRITE)
	f.store_string("{\"v\": 1, \"last\": \"arcanist\", \"classes\": {\"arcanist\": {\"xp\": 900, \"talents\": {}}}}")
	f.close()
	var id = AccountStore.migrate(gd, legacy, "Forth", DIR)
	check(id is String and id != "", "compte créé à partir de l'ancienne progression")
	var a = AccountStore.read(gd, id, DIR) if id is String and id != "" else null
	check(a != null and a["name"] == "Forth" and a["classes"]["arcanist"]["xp"] == 900, "progression reprise avec le pseudo")
	check(not FileAccess.file_exists(legacy) and FileAccess.file_exists(legacy.get_basename() + ".migrated.json"), "ancien fichier gardé sous un autre nom")
	f = FileAccess.open(legacy, FileAccess.WRITE)
	f.store_string("pas du json")
	f.close()
	check(AccountStore.migrate(gd, legacy, "Forth", DIR) == null, "ancienne progression illisible signalée")
	check(FileAccess.file_exists(legacy.get_basename() + ".invalid.json"), "et mise de côté")
	for file in DirAccess.get_files_at(legacy.get_base_dir()):
		DirAccess.remove_absolute(legacy.get_base_dir().path_join(file))
	DirAccess.remove_absolute(legacy.get_base_dir())
	_clean()

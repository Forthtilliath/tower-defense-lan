extends Node
## Autoload « Progress » : le compte ouvert (pseudo, expérience et talents de chaque classe),
## enregistré à chaque changement (fichiers et validation : AccountStore, ProgressFile).
## Au premier lancement après la mise à jour, l'ancienne progression devient un compte.

const LEGACY_PATH := "user://progression.json"

var account_id := ""
var account_name := ""
var classes := {}  # id du bâtisseur -> {"xp": int, "talents": {id: rang}}
var last_builder := 0
## Parties jouées et étoiles des cartes (MatchHistory).
var history := MatchHistory.empty()
## Message affichable une fois sur l'écran d'accueil (vide sinon).
var load_warning := ""


func _ready() -> void:
	if Data.db.is_valid():
		_migrate()


## Un compte est ouvert (un compte invité, sans fichier, compte aussi : captures d'écran).
func has_account() -> bool:
	return account_name != ""


## Ouvre un compte enregistré. Renvoie "" ou un message d'erreur.
func open_account(id: String) -> String:
	var account = AccountStore.read(Data.db, id)
	if account == null:
		return "Ce compte est illisible ou a été supprimé."
	account_id = id
	account_name = account["name"]
	classes = account["classes"]
	last_builder = account["last"]
	history = account["history"]
	Settings.set_last_account(id)
	return ""


## Crée un compte vierge et l'ouvre. Renvoie "" ou un message d'erreur.
func create_account(raw_name: String) -> String:
	var name := Check.sanitize_name(raw_name)
	if name == "":
		return "Choisis un pseudo."
	var existing: Array = AccountStore.list(Data.db)["accounts"]
	if AccountStore.name_taken(existing, name):
		return "Un compte « %s » existe déjà sur cet appareil : utilise « Continuer »." % name
	if existing.size() >= AccountStore.MAX_ACCOUNTS:
		return "%d comptes au plus sur un appareil : supprimes-en un d'abord." % AccountStore.MAX_ACCOUNTS
	var id := AccountStore.new_id()
	if not AccountStore.write(Data.db, id, name, {}, 0):
		return "Impossible d'enregistrer le compte sur cet appareil."
	return open_account(id)


## Enregistre un compte reçu d'un autre appareil (déjà vérifié par ProgressFile) et l'ouvre.
## Un compte du même pseudo est remplacé (cas du passage du PC au téléphone). Renvoie "" ou une erreur.
func import_account(account: Dictionary) -> String:
	var existing: Array = AccountStore.list(Data.db)["accounts"]
	var id := AccountStore.find(existing, account["name"])
	if id == "":
		if existing.size() >= AccountStore.MAX_ACCOUNTS:
			return "%d comptes au plus sur un appareil : supprimes-en un d'abord." % AccountStore.MAX_ACCOUNTS
		id = AccountStore.new_id()
	if not AccountStore.write(Data.db, id, account["name"], account["classes"], account["last"], AccountStore.DIR, account.get("history", {})):
		return "Impossible d'enregistrer le compte sur cet appareil."
	return open_account(id)


func close_account() -> void:
	account_id = ""
	account_name = ""
	classes = {}
	last_builder = 0
	history = MatchHistory.empty()


## Compte invité, jamais enregistré (captures d'écran automatiques).
func use_guest(name: String) -> void:
	close_account()
	account_name = name


func xp(builder: int) -> int:
	return int(_entry(builder).get("xp", 0))


func level(builder: int) -> int:
	return TalentRules.level_for(Data.db, xp(builder))


func talents(builder: int) -> Dictionary:
	return _entry(builder).get("talents", {}).duplicate()


## Héritage : classes montées au niveau maximum (index), dont le bonus profite aux autres.
func heritage() -> Array[int]:
	var out: Array[int] = []
	for b in Data.db.builders.size():
		if level(b) >= int(Data.db.progression["max_level"]):
			out.append(b)
	return out


func points_left(builder: int) -> int:
	return TalentRules.points(level(builder)) - TalentRules.spent(talents(builder))


## Enregistre de nouveaux talents s'ils sont valables pour le niveau de la classe.
func set_talents(builder: int, value: Dictionary) -> bool:
	var checked = TalentRules.validate(Data.db, builder, value, TalentRules.points(level(builder)))
	if checked == null:
		return false
	_entry_for_write(builder)["talents"] = checked
	_save()
	return true


func set_last_builder(builder: int) -> void:
	if builder >= 0 and builder < Data.db.builders.size() and builder != last_builder:
		last_builder = builder
		_save()


## Ajoute de l'expérience à une classe. Renvoie [ancien niveau, nouveau niveau].
func award(builder: int, amount: int) -> Array:
	var before := level(builder)
	var e := _entry_for_write(builder)
	e["xp"] = clampi(int(e["xp"]) + maxi(0, amount), 0, ProgressFile.MAX_XP)
	_save()
	return [before, level(builder)]


## Ajoute une partie terminée à l'historique (format : MatchHistory). Renvoie true si elle
## bat le record d'étoiles de la carte à cette difficulté.
func record_game(game: Dictionary) -> bool:
	var record := MatchHistory.add(history, game)
	_save()
	return record


## Étoiles gagnées au mieux sur une carte (index) à une difficulté (index), 0 si jamais gagnée.
func best_stars(map_index: int, difficulty: int) -> int:
	if map_index < 0 or map_index >= Data.db.maps.size() or difficulty < 0 or difficulty >= Data.db.difficulties.size():
		return 0
	return MatchHistory.best(history, Data.db.maps[map_index].id, Data.db.difficulties[difficulty]["id"])


func _entry(builder: int) -> Dictionary:
	if builder < 0 or builder >= Data.db.builders.size():
		return {}
	return classes.get(Data.db.builders[builder]["id"], {})


func _entry_for_write(builder: int) -> Dictionary:
	var id: String = Data.db.builders[clampi(builder, 0, Data.db.builders.size() - 1)]["id"]
	if not classes.has(id):
		classes[id] = {"xp": 0, "talents": {}}
	return classes[id]


func _migrate() -> void:
	var name := Settings.legacy_name if Settings.legacy_name != "" else "Joueur"
	var result = AccountStore.migrate(Data.db, LEGACY_PATH, name)
	if result == null:
		load_warning = "Ancienne progression illisible : mise de côté (progression.invalid.json)."
	elif result != "":
		Settings.set_last_account(result)
		load_warning = "Ta progression a été placée dans le compte « %s »." % name


func _save() -> void:
	if account_id != "" and not AccountStore.write(Data.db, account_id, account_name, classes, last_builder, AccountStore.DIR, history):
		push_warning("Progression non enregistrée (compte %s)" % account_id)

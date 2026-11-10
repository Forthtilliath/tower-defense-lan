extends Node
## Autoload « Progress » : expérience et talents de chaque classe, sauvegardés en JSON sur
## l'appareil (format et validation : ProgressFile). Un fichier invalide n'est jamais écrasé
## sans copie : il est mis de côté dans progression.invalid.json et la progression repart de zéro.

const PATH := "user://progression.json"
const BAD_PATH := "user://progression.invalid.json"
const MAX_SIZE := 64 * 1024

var classes := {}  # id du bâtisseur -> {"xp": int, "talents": {id: rang}}
var last_builder := 0
## Message affichable si le fichier a dû être écarté au chargement (vide sinon).
var load_warning := ""


func _ready() -> void:
	if Data.db.is_valid():
		_load()


func xp(builder: int) -> int:
	return int(_entry(builder).get("xp", 0))


func level(builder: int) -> int:
	return TalentRules.level_for(Data.db, xp(builder))


func talents(builder: int) -> Dictionary:
	return _entry(builder).get("talents", {}).duplicate()


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


func _entry(builder: int) -> Dictionary:
	if builder < 0 or builder >= Data.db.builders.size():
		return {}
	return classes.get(Data.db.builders[builder]["id"], {})


func _entry_for_write(builder: int) -> Dictionary:
	var id: String = Data.db.builders[clampi(builder, 0, Data.db.builders.size() - 1)]["id"]
	if not classes.has(id):
		classes[id] = {"xp": 0, "talents": {}}
	return classes[id]


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = ProgressFile.parse(Data.db, f.get_as_text()) if f.get_length() <= MAX_SIZE else null
	f.close()
	if parsed == null:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(BAD_PATH))
		load_warning = "Progression illisible : mise de côté (progression.invalid.json), elle repart de zéro."
		return
	classes = parsed[0]
	last_builder = parsed[1]


func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(ProgressFile.serialize(Data.db, classes, last_builder))

class_name GameData
extends RefCounted
## Données du jeu (joueur, tourelles, monstres, vagues, cartes), chargées et validées.

const DEFAULT_PATH := "res://data/game_data.json"
const MAX_FILE_SIZE := 512 * 1024

var player := {}
var coop_scaling := {}
var difficulties: Array[Dictionary] = []
var builders: Array[Dictionary] = []
## Vagues spéciales, par id.
var modifiers := {}
var specials: Array[Dictionary] = []
var towers := {}
var tower_order: Array[String] = []
var monsters := {}
var monster_order: Array[String] = []
var waves := {}
var maps: Array[MapDef] = []
## Vide si les données sont valides, sinon le message de la première anomalie.
var error := ""


static func load_file(path: String = DEFAULT_PATH) -> GameData:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _failed("fichier introuvable : %s" % path)
	if f.get_length() > MAX_FILE_SIZE:
		return _failed("fichier trop volumineux : %s" % path)
	return from_text(f.get_as_text())


static func from_text(text: String) -> GameData:
	var json := JSON.new()
	if json.parse(text) != OK:
		return _failed("JSON invalide (ligne %d) : %s" % [json.get_error_line(), json.get_error_message()])
	var gd := GameData.new()
	var validator := DataValidator.new()
	if not validator.fill(json.data, gd):
		gd.error = validator.error
	return gd


static func _failed(message: String) -> GameData:
	var gd := GameData.new()
	gd.error = message
	return gd


func is_valid() -> bool:
	return error == ""


func tower_levels(type: String) -> Array:
	return towers[type]["levels"]


## Statistiques d'une tourelle à un niveau donné, avec les bonus de la case spéciale
## et du bâtisseur de son propriétaire (-1 : aucun).
func tower_stats(type: String, level: int, special := -1, builder := -1) -> Dictionary:
	var stats: Dictionary = tower_levels(type)[level].duplicate()
	if special >= 0 and special < specials.size():
		_boost(stats, specials[special])
	if builder >= 0 and builder < builders.size():
		_boost(stats, builders[builder])
	return stats


static func _boost(stats: Dictionary, bonus: Dictionary) -> void:
	stats["range"] *= bonus["range"]
	stats["damage"] *= bonus["damage"]
	stats["poison_dps"] *= bonus["damage"]
	stats["rate"] *= bonus["rate"]


## Le bâtisseur n° builder peut-il construire cette tourelle ?
func builder_allows(builder: int, type: String) -> bool:
	return builder >= 0 and builder < builders.size() and builders[builder]["towers"].has(type)


## Vague spéciale d'une vague (dictionnaire vide si vague normale).
func wave_modifier(wave_id: String) -> Dictionary:
	var w: Dictionary = waves.get(wave_id, {})
	return modifiers.get(w.get("modifier", ""), {})


## Total payé pour une tourelle arrivée au niveau `level` (construction + améliorations).
func tower_invested(type: String, level: int) -> int:
	var total := 0
	var levels := tower_levels(type)
	for i in mini(level + 1, levels.size()):
		total += int(levels[i]["cost"])
	return total


## Monstres que l'on peut envoyer à un adversaire en mode versus.
func sendable_monsters() -> Array[String]:
	var out: Array[String] = []
	for id in monster_order:
		if int(monsters[id]["send_cost"]) > 0:
			out.append(id)
	return out

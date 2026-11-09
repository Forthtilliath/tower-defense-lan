class_name GameData
extends RefCounted
## Données du jeu (joueur, tourelles, monstres, vagues, cartes), chargées et validées.

const DEFAULT_PATH := "res://data/game_data.json"
const MAX_FILE_SIZE := 512 * 1024

var player := {}
var coop_scaling := {}
var difficulties: Array[Dictionary] = []
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


## Statistiques d'une tourelle à un niveau donné, bonus de case spéciale compris (-1 : aucune).
func tower_stats(type: String, level: int, special := -1) -> Dictionary:
	var stats: Dictionary = tower_levels(type)[level].duplicate()
	if special >= 0 and special < specials.size():
		var s: Dictionary = specials[special]
		stats["range"] *= s["range"]
		stats["damage"] *= s["damage"]
		stats["poison_dps"] *= s["damage"]
		stats["rate"] *= s["rate"]
	return stats


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

class_name GameData
extends RefCounted
## Données du jeu (joueur, tourelles, monstres, vagues, cartes), chargées et validées.

const DEFAULT_PATH := "res://data/game_data.json"
const MAX_FILE_SIZE := 512 * 1024
## Étages (Architecte) : niveaux en plus des tourelles du tronc commun.
const FLOORS := 2
const FLOOR_COST := 1.6
const FLOOR_POWER := 1.35
const FLOOR_RANGE := 0.2

var player := {}
var coop_scaling := {}
var progression := {}
## Points à dépenser dans une branche pour atteindre chaque palier de talents.
var talent_tiers: Array[int] = []
## Tourelles ouvertes à toutes les classes (les spécialisations en débloquent d'autres).
var common_towers: Array[String] = []
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
var _floors := {}  # cache de all_levels


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


## Niveaux qu'un joueur peut atteindre : ceux des données, plus ses étages (Architecte) sur une
## tourelle du tronc commun.
func levels_for(type: String, kit: PlayerKit = null) -> Array:
	var floors := int(kit.m("floors")) if kit != null else 0
	if floors <= 0 or not common_towers.has(type):
		return tower_levels(type)
	return all_levels(type).slice(0, tower_levels(type).size() + floors)


## Tous les niveaux possibles : ceux des données, puis FLOORS étages pour une tourelle du tronc
## commun (chacun : dégâts ×FLOOR_POWER, un peu plus de portée, prix ×FLOOR_COST).
func all_levels(type: String) -> Array:
	if not _floors.has(type):
		var out: Array = tower_levels(type).duplicate()
		if common_towers.has(type):
			for k in FLOORS:
				var top: Dictionary = out[-1].duplicate()
				top["cost"] = roundi(float(top["cost"]) * FLOOR_COST)
				scale_damage(top, FLOOR_POWER)
				top["range"] = float(top["range"]) + FLOOR_RANGE
				out.append(top)
		_floors[type] = out
	return _floors[type]


## Statistiques d'une tourelle à un niveau donné, avec les bonus de la case spéciale et du
## kit de son propriétaire (PlayerKit, ou index de bâtisseur sans talents ; null : aucun).
func tower_stats(type: String, level: int, special := -1, kit: Variant = null) -> Dictionary:
	var stats: Dictionary = all_levels(type)[level].duplicate()
	if special >= 0 and special < specials.size():
		var s: Dictionary = specials[special]
		var boost: float = 1.0 + (kit.m("fertile") if kit is PlayerKit else 0.0)  # Terre fertile
		stats["range"] *= 1.0 + (float(s["range"]) - 1.0) * boost
		stats["rate"] *= 1.0 + (float(s["rate"]) - 1.0) * boost
		scale_damage(stats, 1.0 + (float(s["damage"]) - 1.0) * boost)
	if typeof(kit) == TYPE_INT and kit >= 0 and kit < builders.size():
		kit = PlayerKit.make(self, kit)
	if kit is PlayerKit:
		kit.boost(stats, type)
	return stats


## Dégâts directs et dégâts dans le temps (poison, brûlure, saignement, nappes au sol).
static func scale_damage(stats: Dictionary, mult: float) -> void:
	for key in ["damage", "poison_dps", "burn_dps", "bleed", "patch_dps"]:
		stats[key] *= mult


## Contrôles : chances (plafonnées à 100 %) et durées.
static func scale_control(stats: Dictionary, mult: float) -> void:
	if is_equal_approx(mult, 1.0):
		return
	for kind in ["stun", "fear", "charm"]:
		stats[kind + "_chance"] = minf(1.0, stats[kind + "_chance"] * mult)
		stats[kind + "_duration"] *= mult
	stats["slow_duration"] *= mult


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

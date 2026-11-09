class_name NetLobby
extends RefCounted
## Salon côté hôte : options de la partie (hôte), choix personnels des joueurs (bâtisseur, vote de
## difficulté), admission des nouveaux joueurs et diffusion de l'état du salon.
## Toute valeur reçue d'un joueur est revalidée (clé connue, entier borné) et limitée en fréquence.

const DEFAULT_SETTINGS := {"mode": 0, "map": 0, "rhythm": 0, "launch": 0}
const CHOICE_INTERVAL_MS := 150

var net: Node
var _last_choice := {}  # id -> instant du dernier choix accepté


func _init(p_net: Node) -> void:
	net = p_net


static func new_player(player_name: String, color: int) -> Dictionary:
	return {"name": player_name, "color": color, "builder": 0, "vote": mini(1, Data.db.difficulties.size() - 1)}


## Option de partie choisie par l'hôte (mode, carte, rythme, lancement).
func set_option(key: String, value: int) -> void:
	var limits := {
		"mode": net.MODE_NAMES.size(), "map": Data.db.maps.size(),
		"rhythm": SimMatch.RHYTHM_NAMES.size(), "launch": SimMatch.LAUNCH_NAMES.size(),
	}
	if not limits.has(key) or value < 0 or value >= limits[key]:
		return
	net.settings[key] = value
	sync()


## Choix personnel d'un joueur (bâtisseur, vote de difficulté), reçu tel quel du réseau.
func set_choice(id: int, raw_key: Variant, raw_value: Variant) -> void:
	if not net.players.has(id):
		return
	var limits := {"builder": Data.db.builders.size(), "vote": Data.db.difficulties.size()}
	if typeof(raw_key) != TYPE_STRING or not limits.has(raw_key):
		return
	var value = Check.as_int(raw_value, 0, limits[raw_key] - 1)
	if value == null or net.players[id][raw_key] == value:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_choice.get(id, -CHOICE_INTERVAL_MS)) < CHOICE_INTERVAL_MS:
		return
	_last_choice[id] = now
	net.players[id][raw_key] = value
	sync()


func forget(id: int) -> void:
	_last_choice.erase(id)


## Liste des joueurs pour la partie : [[id, nom, couleur, bâtisseur], ...]
func roster() -> Array:
	var out := []
	for id in net.ordered_ids():
		var p: Dictionary = net.players[id]
		out.append([id, p["name"], p["color"], p["builder"]])
	return out


func sync() -> void:
	var list := []
	for id in net.ordered_ids():
		var p: Dictionary = net.players[id]
		list.append([id, p["name"], p["color"], p["builder"], p["vote"]])
	var payload: Dictionary = net.settings.duplicate()
	payload["players"] = list
	for id in net.players:
		if id != 1:
			net.rpc_node().lobby.rpc_id(id, payload)
	net.lobby_changed.emit()

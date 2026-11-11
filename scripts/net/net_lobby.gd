class_name NetLobby
extends RefCounted
## Salon côté hôte : options de la partie (hôte), choix personnels des joueurs (kit : classe,
## niveau et talents ; vote de difficulté), admission des nouveaux joueurs et diffusion du salon.
## Toute valeur reçue d'un joueur est revalidée (clé connue, entiers bornés, talents conformes à
## l'arbre et au niveau annoncé) et limitée en fréquence.
## Limite connue : le niveau annoncé n'est pas vérifiable (progression locale à chaque appareil).

const DEFAULT_SETTINGS := {"mode": 0, "map": 0, "rhythm": 0, "launch": 0}
const CHOICE_INTERVAL_MS := 150

var net: Node
var _last_choice := {}  # id -> instant du dernier choix accepté


func _init(p_net: Node) -> void:
	net = p_net


static func new_player(player_name: String, color: int) -> Dictionary:
	return {
		"name": player_name, "color": color, "builder": 0, "level": 1, "talents": {}, "heritage": [],
		"vote": mini(1, Data.db.difficulties.size() - 1),
	}


## Accueil d'un joueur qui se présente : motif du refus (version, partie commencée, salon complet),
## ou "" s'il entre au salon (pseudo nettoyé et rendu unique, couleur libre).
func admit(id: int, raw_name: Variant, raw_version: Variant) -> String:
	if typeof(raw_version) != TYPE_STRING or raw_version != net.version():
		return "Version différente de l'hôte (%s). Mettez le jeu à jour." % net.version()
	if net.host_loop != null:
		return "La partie a déjà commencé."
	if net.players.size() >= net.MAX_PLAYERS:
		return "Le salon est complet."
	var player_name := Check.sanitize_name(raw_name)
	if player_name == "":
		player_name = "Joueur"
	net.players[id] = new_player(NetPayloads.unique_name(net.players, player_name), NetPayloads.free_color(net.players, net.MAX_PLAYERS))
	sync()
	return ""


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


## Choix personnel d'un joueur, reçu tel quel du réseau : « vote » (index de difficulté) ou
## « kit » ({b: classe, lv: niveau, t: {talent: rang}}).
func set_choice(id: int, raw_key: Variant, raw_value: Variant) -> void:
	if not net.players.has(id) or typeof(raw_key) != TYPE_STRING:
		return
	var change := {}
	if raw_key == "vote":
		var vote = Check.as_int(raw_value, 0, Data.db.difficulties.size() - 1)
		if vote == null:
			return
		change = {"vote": vote}
	elif raw_key == "kit":
		var kit = parse_kit(raw_value)
		if kit == null:
			return
		change = kit
	else:
		return
	var p: Dictionary = net.players[id]
	if change.keys().all(func(k: String) -> bool: return p[k] == change[k]):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_choice.get(id, -CHOICE_INTERVAL_MS)) < CHOICE_INTERVAL_MS:
		return
	_last_choice[id] = now
	p.merge(change, true)
	sync()


## Kit reçu : {b, lv, t, h} → {builder, level, talents, heritage}, ou null au moindre défaut.
static func parse_kit(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY or raw.size() != 4:
		return null
	var builder = Check.as_int(raw.get("b"), 0, Data.db.builders.size() - 1)
	var level = Check.as_int(raw.get("lv"), 1, int(Data.db.progression["max_level"]))
	if builder == null or level == null:
		return null
	var talents = TalentRules.validate(Data.db, builder, raw.get("t"), TalentRules.points(level))
	var heritage = TalentRules.parse_heritage(Data.db, raw.get("h"))
	if talents == null or heritage == null:
		return null
	return {"builder": builder, "level": level, "talents": talents, "heritage": heritage}


func forget(id: int) -> void:
	_last_choice.erase(id)


## Liste des joueurs pour la partie : [[id, nom, couleur, bâtisseur, talents, héritage], ...]
func roster() -> Array:
	var out := []
	for id in net.ordered_ids():
		var p: Dictionary = net.players[id]
		out.append([id, p["name"], p["color"], p["builder"], p["talents"], p["heritage"]])
	return out


func sync() -> void:
	var list := []
	for id in net.ordered_ids():
		var p: Dictionary = net.players[id]
		list.append([id, p["name"], p["color"], p["builder"], p["vote"], p["level"], p["talents"], p["heritage"]])
	var payload: Dictionary = net.settings.duplicate()
	payload["players"] = list
	for id in net.players:
		if id != 1:
			net.rpc_node().lobby.rpc_id(id, payload)
	net.lobby_changed.emit()

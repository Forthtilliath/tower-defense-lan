extends Node
## Autoload « Net » : session réseau local (ENet), salon et boucle de jeu de l'hôte.
##
## L'hôte (identifiant 1) fait autorité : il simule la partie et diffuse l'état ;
## les autres joueurs n'envoient que des commandes, toutes revalidées par l'hôte.
## Les RPC venant des joueurs sont « any_peer » et vérifient l'expéditeur ;
## celles réservées à l'hôte sont « authority » (voir net_rpc.gd).
## Le salon (options, choix des joueurs) est géré par NetLobby.

signal lobby_changed
signal match_started(config: Dictionary)
signal snapshot_received(snap: Dictionary)
signal notice(message: String)
signal session_ended(reason: String)
signal back_to_lobby

enum Role { NONE, HOST, CLIENT }

const PORT := 47800
const MAX_PLAYERS := 4
const REGISTER_TIMEOUT_MS := 5000
const MODE_NAMES := ["Coopération", "Versus"]

var role := Role.NONE
var players := {}  # id -> {name, color, builder, vote}
var settings := NetLobby.DEFAULT_SETTINGS.duplicate()
var config := {}
var host_loop: HostLoop  # partie en cours (hôte uniquement)
var discovery: LanDiscovery
var lobby: NetLobby
var _pending := {}  # id -> instant de connexion, tant que le joueur ne s'est pas présenté
var end_reason := ""
var _my_name := ""
var _rpc: Node
const KIT_INTERVAL_MS := 250
var _pending_kit: Variant = null
var _last_kit_ms := -100000


func _ready() -> void:
	discovery = LanDiscovery.new()
	add_child(discovery)
	lobby = NetLobby.new(self)
	_rpc = preload("res://scripts/net/net_rpc.gd").new()
	_rpc.name = "Rpc"
	_rpc.net = self
	add_child(_rpc)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


func is_host() -> bool:
	return role == Role.HOST


func my_id() -> int:
	return multiplayer.get_unique_id() if role != Role.NONE else 1


func rpc_node() -> Node:
	return _rpc


func ordered_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(players.keys())
	ids.sort()
	return ids


## Crée une partie. Renvoie "" ou un message d'erreur.
func host(player_name: String) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, MAX_PLAYERS - 1) != OK:
		return "Impossible d'ouvrir le port %d : une partie est peut-être déjà hébergée ici." % PORT
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	players = {1: NetLobby.new_player(player_name, 0)}
	settings = NetLobby.DEFAULT_SETTINGS.duplicate()
	discovery.start_broadcast(_announce_info)
	lobby_changed.emit()
	return ""


## Rejoint une partie. Renvoie "" ou un message d'erreur.
func join(ip: String, player_name: String) -> String:
	leave()
	if not Check.is_ipv4(ip):
		return "Adresse IP invalide"
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		return "Connexion impossible"
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	_my_name = player_name
	end_reason = ""
	return ""


func leave() -> void:
	discovery.stop_broadcast()
	host_loop = null
	config = {}
	players = {}
	_pending.clear()
	if role != Role.NONE:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.NONE


## Option de partie (hôte uniquement, dans le salon).
func set_option(key: String, value: int) -> void:
	if is_host() and host_loop == null:
		lobby.set_option(key, value)


## Choix personnel dans le salon : « builder » (bâtisseur) ou « vote » (difficulté).
func choose(key: String, value: Variant) -> void:
	if role == Role.HOST:
		set_choice(1, key, value)
	elif role == Role.CLIENT:
		_rpc.choose.rpc_id(1, key, value)


## Annonce la classe choisie, avec le niveau et les talents enregistrés pour elle sur cet appareil.
## Envois espacés (KIT_INTERVAL_MS) : seul le dernier état part, rien n'est perdu.
func choose_kit(builder: int) -> void:
	_pending_kit = {"b": builder, "lv": Progress.level(builder), "t": Progress.talents(builder), "h": Progress.heritage()}
	_flush_kit()


func _flush_kit() -> void:
	if _pending_kit == null or role == Role.NONE or Time.get_ticks_msec() - _last_kit_ms < KIT_INTERVAL_MS:
		return
	_last_kit_ms = Time.get_ticks_msec()
	var kit = _pending_kit
	_pending_kit = null
	choose("kit", kit)


func set_choice(id: int, raw_key: Variant, raw_value: Variant) -> void:
	if is_host() and host_loop == null:
		lobby.set_choice(id, raw_key, raw_value)


## Difficulté qui sera jouée si l'on lance maintenant (vote des joueurs).
func voted_difficulty() -> int:
	return NetPayloads.voted_difficulty(players, Data.db.difficulties.size())


func start_match() -> void:
	if not is_host() or host_loop != null:
		return
	var roster := lobby.roster()
	config = settings.duplicate()
	config["difficulty"] = voted_difficulty()
	config["roster"] = roster
	var options := {"rhythm": settings["rhythm"], "launch": settings["launch"]}
	host_loop = HostLoop.new(SimMatch.new(Data.db, settings["map"], settings["mode"], roster, config["difficulty"], options))
	for id in players:
		if id != 1:
			_rpc.start.rpc_id(id, config)
	match_started.emit(config)


func return_to_lobby() -> void:
	if not is_host():
		return
	host_loop = null
	config = {}
	for id in players:
		if id != 1:
			_rpc.to_lobby.rpc_id(id)
	back_to_lobby.emit()
	lobby.sync()


func send_command(cmd: Dictionary) -> void:
	if role == Role.HOST:
		handle_command(1, cmd)
	elif role == Role.CLIENT:
		_rpc.command.rpc_id(1, cmd)


func _process(delta: float) -> void:
	_flush_kit()
	if role != Role.HOST:
		return
	_kick_silent_peers()
	if host_loop != null:
		host_loop.advance(delta, _on_tick)


func _on_tick(snap: Dictionary, to_network: bool) -> void:
	snapshot_received.emit(snap)
	if not to_network:
		return
	var net_snap := snap.duplicate()
	net_snap["iv"] = HostLoop.TICK * HostLoop.NET_EVERY / host_loop.speed
	for id in players:
		if id != 1:
			_rpc.snapshot.rpc_id(id, net_snap)


func handle_command(id: int, raw: Variant) -> void:
	if host_loop == null or not players.has(id):
		return
	var err := host_loop.handle(id, raw)
	if err != "":
		_notify(id, err)
	for n in host_loop.sim.notices:
		if players.has(n[0]):
			_notify(n[0], n[1])
	host_loop.sim.notices.clear()


func _notify(id: int, message: String) -> void:
	if id == 1:
		notice.emit(message)
	else:
		_rpc.notice.rpc_id(id, message)


func _announce_info() -> Dictionary:
	return {
		"g": LanDiscovery.MAGIC, "v": version(), "n": players.get(1, {}).get("name", "Hôte"),
		"m": settings["mode"], "p": players.size(), "x": MAX_PLAYERS, "s": host_loop != null,
	}


func _kick(id: int, reason: String) -> void:
	_rpc.kicked.rpc_id(id, reason)
	var peer := multiplayer.multiplayer_peer
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if peer == multiplayer.multiplayer_peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			peer.disconnect_peer(id))


func _kick_silent_peers() -> void:
	var now := Time.get_ticks_msec()
	for id in _pending.keys():
		if now - int(_pending[id]) > REGISTER_TIMEOUT_MS:
			_pending.erase(id)
			multiplayer.multiplayer_peer.disconnect_peer(id)


# --- Évènements de connexion ---

func _on_peer_connected(id: int) -> void:
	if role == Role.HOST:
		_pending[id] = Time.get_ticks_msec()


func _on_peer_disconnected(id: int) -> void:
	if role != Role.HOST:
		return
	_pending.erase(id)
	lobby.forget(id)
	if not players.has(id):
		return
	players.erase(id)
	if host_loop != null:
		host_loop.sim.player_left(id)
		notice.emit("Un joueur a quitté la partie")
	lobby.sync()


func _on_connected() -> void:
	_rpc.register.rpc_id(1, _my_name, version())


func _on_connection_failed() -> void:
	leave()
	session_ended.emit("Impossible de joindre l'hôte. Vérifie l'adresse et que vous êtes sur le même Wi-Fi.")


func _on_server_disconnected() -> void:
	var reason := end_reason if end_reason != "" else "La connexion avec l'hôte a été perdue."
	leave()
	session_ended.emit(reason)


## Présentation d'un joueur qui vient de se connecter (appelé via Rpc.register).
func admit(id: int, raw_name: Variant, raw_version: Variant) -> void:
	if players.has(id) or not _pending.has(id):
		return
	_pending.erase(id)
	if typeof(raw_version) != TYPE_STRING or raw_version != version():
		_kick(id, "Version différente de l'hôte (%s). Mettez le jeu à jour." % version())
	elif host_loop != null:
		_kick(id, "La partie a déjà commencé.")
	elif players.size() >= MAX_PLAYERS:
		_kick(id, "Le salon est complet.")
	else:
		var player_name := Check.sanitize_name(raw_name)
		if player_name == "":
			player_name = "Joueur"
		players[id] = NetLobby.new_player(NetPayloads.unique_name(players, player_name), NetPayloads.free_color(players, MAX_PLAYERS))
		lobby.sync()

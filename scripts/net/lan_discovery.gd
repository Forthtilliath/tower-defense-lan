class_name LanDiscovery
extends Node
## Découverte des parties sur le réseau local par broadcast UDP.
## L'hôte annonce sa partie chaque seconde ; les joueurs qui cherchent écoutent le port.
## Les annonces reçues sont des données externes : taille bornée, JSON validé champ par champ,
## et seules les adresses de réseau local sont acceptées.

signal hosts_changed(hosts: Array)

const PORT := 47801
const MAGIC := "tdlan"
const INTERVAL := 1.0
const EXPIRY := 3.5
const MAX_PACKET := 512
const MAX_HOSTS := 16

var _info_provider := Callable()
var _sender: PacketPeerUDP
var _listener: PacketPeerUDP
var _timer := 0.0
var _hosts := {}  # ip -> {info..., seen}


func start_broadcast(info_provider: Callable) -> void:
	stop_broadcast()
	_info_provider = info_provider
	_sender = PacketPeerUDP.new()
	_sender.set_broadcast_enabled(true)
	_timer = 0.0


func stop_broadcast() -> void:
	if _sender != null:
		_sender.close()
	_sender = null


## Commence à écouter les annonces. Renvoie false si le port est déjà utilisé.
func start_listen() -> bool:
	stop_listen()
	_listener = PacketPeerUDP.new()
	if _listener.bind(PORT) != OK:
		_listener = null
		return false
	return true


func stop_listen() -> void:
	if _listener != null:
		_listener.close()
	_listener = null
	_hosts.clear()


func hosts() -> Array:
	var out := []
	for ip in _hosts:
		out.append(_hosts[ip])
	return out


func _process(delta: float) -> void:
	if _sender != null:
		_timer -= delta
		if _timer <= 0.0:
			_timer = INTERVAL
			_announce()
	if _listener != null:
		var changed := _receive()
		if _expire() or changed:
			hosts_changed.emit(hosts())


func _announce() -> void:
	var bytes := JSON.stringify(_info_provider.call()).to_utf8_buffer()
	for address in broadcast_addresses():
		_sender.set_dest_address(address, PORT)
		_sender.put_packet(bytes)


func _receive() -> bool:
	var changed := false
	var budget := 32
	while _listener.get_available_packet_count() > 0 and budget > 0:
		budget -= 1
		var packet := _listener.get_packet()
		var ip := _listener.get_packet_ip()
		if packet.size() > MAX_PACKET or not Check.is_lan_ipv4(ip):
			continue
		var info = parse_announce(packet.get_string_from_utf8())
		if info == null or (not _hosts.has(ip) and _hosts.size() >= MAX_HOSTS):
			continue
		info["ip"] = ip
		info["seen"] = Time.get_ticks_msec()
		if not _hosts.has(ip) or _differs(_hosts[ip], info):
			changed = true
		_hosts[ip] = info
	return changed


func _expire() -> bool:
	var now := Time.get_ticks_msec()
	var removed := false
	for ip in _hosts.keys():
		if now - int(_hosts[ip]["seen"]) > EXPIRY * 1000.0:
			_hosts.erase(ip)
			removed = true
	return removed


static func _differs(a: Dictionary, b: Dictionary) -> bool:
	for key in ["name", "version", "mode", "players", "max", "started"]:
		if a[key] != b[key]:
			return true
	return false


## Valide une annonce reçue. Renvoie un dictionnaire normalisé, ou null si elle est invalide.
static func parse_announce(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = json.data
	if d.get("g") != MAGIC:
		return null
	var version = Check.as_text(d.get("v"), 16)
	var host_name := Check.sanitize_name(d.get("n"))
	var mode = Check.as_int(d.get("m"), 0, 1)
	var players = Check.as_int(d.get("p"), 0, 8)
	var max_players = Check.as_int(d.get("x"), 1, 8)
	var started = Check.as_bool(d.get("s"))
	if version == null or host_name == "" or mode == null or players == null \
			or max_players == null or started == null:
		return null
	return {
		"version": version, "name": host_name, "mode": mode,
		"players": players, "max": max_players, "started": started,
	}


## Adresses IPv4 de cet appareil sur le réseau local.
static func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for ip in IP.get_local_addresses():
		if Check.is_lan_ipv4(ip) and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			out.append(ip)
	return out


## Diffusion générale + diffusion de chaque sous-réseau (/24) : Windows n'envoie
## parfois 255.255.255.255 que sur une seule interface.
static func broadcast_addresses() -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255"])
	for ip in local_addresses():
		var p := ip.split(".")
		var address := "%s.%s.%s.255" % [p[0], p[1], p[2]]
		if not out.has(address):
			out.append(address)
	return out

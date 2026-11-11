class_name AccountSender
extends RefCounted
## Appareil qui envoie un compte : écoute les annonces des appareils en attente de réception,
## puis se connecte à l'un d'eux et envoie le compte avec le code affiché là-bas.
## Appeler poll() à chaque image.

signal receivers_changed(list: Array)  # [{ip, name, version}]
signal finished(error: String)  # "" : compte accepté par l'autre appareil

const EXPIRY_MS := 3500
const MAX_RECEIVERS := 16

var _udp: PacketPeerUDP
var _receivers := {}  # ip -> {ip, name, version, seen}
var _tcp: StreamPeerTCP
var _stream: PacketPeerStream
var _offer := PackedByteArray()
var _sent := false
var _since := 0


## Écoute les annonces. Renvoie false si le port est déjà pris (on peut encore saisir l'IP).
func start_browse() -> bool:
	_udp = PacketPeerUDP.new()
	if _udp.bind(AccountTransfer.UDP_PORT) != OK:
		_udp = null
		return false
	return true


func stop() -> void:
	if _udp != null:
		_udp.close()
	_udp = null
	_close()


func is_sending() -> bool:
	return _tcp != null


## Envoie le compte (texte du fichier de compte) à `ip`. Renvoie "" ou un message d'erreur.
func send(ip: String, code: String, account_text: String) -> String:
	if not Check.is_lan_ipv4(ip):
		return "Adresse IP de réseau local invalide (exemple : 192.168.1.20)."
	if code.length() != 4 or not code.is_valid_int():
		return "Le code fait 4 chiffres."
	_close()
	_tcp = StreamPeerTCP.new()
	if _tcp.connect_to_host(ip, AccountTransfer.TCP_PORT) != OK:
		_tcp = null
		return "Connexion impossible."
	_stream = AccountTransfer.wrap(_tcp)
	_offer = AccountTransfer.offer_bytes(code, account_text)
	_sent = false
	_since = Time.get_ticks_msec()
	return ""


func poll() -> void:
	if _udp != null:
		_browse()
	if _tcp != null:
		_poll_send()


func _browse() -> void:
	var changed := false
	var budget := 32
	while _udp.get_available_packet_count() > 0 and budget > 0:
		budget -= 1
		var packet := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		if packet.size() > AccountTransfer.MAX_ANNOUNCE or not Check.is_lan_ipv4(ip):
			continue
		var info = AccountTransfer.parse_announce(packet.get_string_from_utf8())
		if info == null or (not _receivers.has(ip) and _receivers.size() >= MAX_RECEIVERS):
			continue
		changed = changed or not _receivers.has(ip) or _receivers[ip]["name"] != info["name"]
		info["ip"] = ip
		info["seen"] = Time.get_ticks_msec()
		_receivers[ip] = info
	var now := Time.get_ticks_msec()
	for ip in _receivers.keys():
		if now - int(_receivers[ip]["seen"]) > EXPIRY_MS:
			_receivers.erase(ip)
			changed = true
	if changed:
		receivers_changed.emit(_receivers.values())


func _poll_send() -> void:
	_tcp.poll()
	var status := _tcp.get_status()
	if Time.get_ticks_msec() - _since > AccountTransfer.TIMEOUT_MS:
		_finish("Pas de réponse : l'autre appareil attend-il toujours (« Recevoir un compte ») ?")
	elif status == StreamPeerTCP.STATUS_ERROR or (status == StreamPeerTCP.STATUS_NONE and not _sent):
		_finish("Connexion impossible : vérifie que l'autre appareil attend un compte, sur le même Wi-Fi.")
	elif status == StreamPeerTCP.STATUS_CONNECTED and not _sent:
		_sent = true
		_stream.put_packet(_offer)
	elif _sent and _stream.get_available_packet_count() > 0:
		var reply = AccountTransfer.parse_reply(_stream.get_packet().get_string_from_utf8())
		match reply:
			"":
				_finish("")
			"code":
				_finish("Code incorrect : vérifie le code affiché sur l'autre appareil.")
			"invalid":
				_finish("Compte refusé par l'autre appareil (versions du jeu différentes ?).")
			_:
				_finish("Réponse illisible de l'autre appareil.")
	elif _sent and status == StreamPeerTCP.STATUS_NONE:
		_finish("L'autre appareil a coupé la connexion.")


func _finish(error: String) -> void:
	_close()
	finished.emit(error)


func _close() -> void:
	if _tcp != null:
		_tcp.disconnect_from_host()
	_tcp = null
	_stream = null

class_name AccountReceiver
extends RefCounted
## Appareil qui reçoit un compte : port TCP ouvert seulement pendant l'attente, annonce UDP
## chaque seconde, code à 4 chiffres. Une connexion à la fois, du réseau local seulement, un
## message borné, 8 s au plus ; après MAX_TRIES codes faux, tout s'arrête. Appeler poll() à
## chaque image. Le compte reçu est déjà vérifié, mais rien n'est enregistré ici : l'écran le
## montre et demande confirmation.

signal received(account: Dictionary)
signal failed(message: String)

var code := ""
var tries_left := AccountTransfer.MAX_TRIES
var _data: GameData
var _label := ""
var _server: TCPServer
var _udp: PacketPeerUDP
var _tcp: StreamPeerTCP
var _stream: PacketPeerStream
var _since := 0
var _announce_at := 0


func _init(data: GameData) -> void:
	_data = data


## Ouvre le port et commence à s'annoncer. Renvoie "" ou un message d'erreur.
func start(label: String) -> String:
	stop()
	_server = TCPServer.new()
	if _server.listen(AccountTransfer.TCP_PORT) != OK:
		_server = null
		return "Port %d occupé : ferme les autres fenêtres du jeu sur cet appareil." % AccountTransfer.TCP_PORT
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_label = label
	code = AccountTransfer.new_code()
	tries_left = AccountTransfer.MAX_TRIES
	_announce_at = 0
	return ""


func is_running() -> bool:
	return _server != null


func stop() -> void:
	_drop()
	if _server != null:
		_server.stop()
	_server = null
	if _udp != null:
		_udp.close()
	_udp = null


func poll() -> void:
	if _server == null:
		return
	var now := Time.get_ticks_msec()
	if now >= _announce_at:
		_announce_at = now + 1000
		_announce()
	if _tcp == null and _server.is_connection_available():
		var tcp := _server.take_connection()
		if tcp != null and Check.is_lan_ipv4(tcp.get_connected_host()):
			_tcp = tcp
			_stream = AccountTransfer.wrap(tcp)
			_since = now
		elif tcp != null:
			tcp.disconnect_from_host()
	if _tcp != null:
		_poll_peer(now)


func _announce() -> void:
	var bytes := AccountTransfer.announce_bytes(_label)
	for address in LanDiscovery.broadcast_addresses():
		_udp.set_dest_address(address, AccountTransfer.UDP_PORT)
		_udp.put_packet(bytes)


func _poll_peer(now: int) -> void:
	_tcp.poll()
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED or now - _since > AccountTransfer.TIMEOUT_MS:
		_drop()
		return
	if _stream.get_available_packet_count() == 0:
		return
	var text := _stream.get_packet().get_string_from_utf8()
	var result = AccountTransfer.read_offer(_data, text, code)
	if result is Dictionary:
		_stream.put_packet(AccountTransfer.reply_bytes(""))
		stop()
		received.emit(result)
		return
	_stream.put_packet(AccountTransfer.reply_bytes(result))
	_drop()
	if result == "code":
		tries_left -= 1
		if tries_left <= 0:
			stop()
			failed.emit("Trop de codes faux : réception arrêtée. Recommence depuis le début.")


func _drop() -> void:
	if _tcp != null:
		_tcp.disconnect_from_host()
	_tcp = null
	_stream = null

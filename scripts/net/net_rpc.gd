extends Node
## Points d'entrée réseau (RPC) de l'autoload Net, sur le nœud enfant « Rpc »
## (même chemin /root/Net/Rpc sur tous les appareils).
##
## Joueurs vers hôte : « any_peer », l'expéditeur est vérifié par Net.
## Hôte vers joueurs : « authority » (seul l'hôte peut les appeler), et le contenu
## est revalidé à la réception : un message invalide est ignoré en entier.

var net: Node


# --- Joueurs vers hôte ---

@rpc("any_peer", "call_remote", "reliable")
func register(raw_name: Variant, raw_version: Variant) -> void:
	if net.is_host():
		net.admit(multiplayer.get_remote_sender_id(), raw_name, raw_version)


@rpc("any_peer", "call_remote", "reliable")
func command(raw: Variant) -> void:
	if net.is_host():
		net.handle_command(multiplayer.get_remote_sender_id(), raw)


# --- Hôte vers joueurs ---

@rpc("authority", "call_remote", "reliable")
func lobby(payload: Variant) -> void:
	var parsed = NetPayloads.parse_lobby(payload, Data.db.maps.size(), net.MODE_NAMES.size(), net.MAX_PLAYERS)
	if parsed == null:
		return
	net.players = parsed["players"]
	net.settings = {"mode": parsed["mode"], "map": parsed["map"]}
	net.lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func start(raw: Variant) -> void:
	var parsed = NetPayloads.parse_config(raw, Data.db.maps.size(), net.MODE_NAMES.size(), net.MAX_PLAYERS)
	if parsed == null:
		return
	net.config = parsed
	net.match_started.emit(parsed)


@rpc("authority", "call_remote", "reliable")
func to_lobby() -> void:
	net.config = {}
	net.back_to_lobby.emit()


@rpc("authority", "call_remote", "unreliable_ordered")
func snapshot(snap: Variant) -> void:
	# Le contenu est vérifié champ par champ par ViewState.apply
	if typeof(snap) == TYPE_DICTIONARY and not net.config.is_empty():
		net.snapshot_received.emit(snap)


@rpc("authority", "call_remote", "reliable")
func notice(message: Variant) -> void:
	var text = Check.as_text(message, 120)
	if text != null:
		net.notice.emit(text)


@rpc("authority", "call_remote", "reliable")
func kicked(reason: Variant) -> void:
	var text = Check.as_text(reason, 120)
	net.end_reason = text if text != null else "Exclu par l'hôte."

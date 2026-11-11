extends Node
## Test réseau de bout en bout, lancé par main.gd avec « -- --autotest=host » ou « --autotest=client ».
## L'hôte attend un joueur ; le client choisit son bâtisseur et vote pour une difficulté dans le
## salon ; l'hôte lance la partie coop une fois ces choix reçus ; le client construit une tourelle ;
## chacun vérifie dans les instantanés que la tourelle du client existe, puis quitte (code 0).

const TIMEOUT := 25.0
const CLIENT_BUILDER := 2
const CLIENT_VOTE := 2

var role := ""
var main: Node
var _elapsed := 0.0
var _built := false
var _done := false
var _started := false


func _ready() -> void:
	Net.snapshot_received.connect(_on_snapshot)
	Net.match_started.connect(func(_c: Dictionary) -> void: _started = true)
	Net.session_ended.connect(func(reason: String) -> void: _finish(false, "session terminée : " + reason))
	if role == "host":
		var err := Net.host("Hôte test")
		if err != "":
			_finish(false, err)
		else:
			Net.lobby_changed.connect(_on_lobby)
	elif role == "client":
		var ip := "127.0.0.1"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--ip="):
				ip = arg.trim_prefix("--ip=")
		var err := Net.join(ip, "Invité test")
		if err != "":
			_finish(false, err)
		else:
			Net.lobby_changed.connect(_on_client_lobby)
	else:
		_finish(false, "rôle inconnu : " + role)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT and not _done:
		_finish(false, "délai dépassé")


func _on_lobby() -> void:
	if Net.players.size() < 2 or _started:
		return
	var guest: Dictionary = Net.players[Net.ordered_ids()[1]]
	if guest["builder"] == CLIENT_BUILDER and guest["vote"] == CLIENT_VOTE:
		print("AUTOTEST hôte : joueur connecté (%s), bâtisseur et vote reçus" % guest["name"])
		_started = true
		Net.start_match()


## Côté client : choix personnels dès l'arrivée dans le salon (un par message, limite de fréquence).
func _on_client_lobby() -> void:
	var me: Dictionary = Net.players.get(Net.my_id(), {})
	if me.is_empty():
		return
	if me["builder"] != CLIENT_BUILDER:
		Net.choose_kit(CLIENT_BUILDER)
	elif me["vote"] != CLIENT_VOTE:
		await get_tree().create_timer(0.3).timeout
		Net.choose("vote", CLIENT_VOTE)


func _on_snapshot(snap: Dictionary) -> void:
	if _done:
		return
	var boards: Array = snap.get("b", [])
	if boards.is_empty():
		return
	if role == "client" and not _built:
		_built = true
		# Vote 1 contre 1 (hôte : Normal, client : Difficile) : égalité, la plus facile l'emporte
		if Net.config["difficulty"] != 1 or Net.config["roster"][1][3] != CLIENT_BUILDER:
			_finish(false, "configuration reçue sans les choix du salon : %s" % str(Net.config))
			return
		var map: MapDef = Data.db.maps[Net.config["map"]]
		for cell in map.cell_count():
			if map.is_buildable(cell):
				Net.send_command({"a": "build", "cell": cell, "tower": 0})
				break
		# Commandes invalides : doivent être refusées par l'hôte sans le perturber
		Net.send_command({"a": "build", "cell": -5, "tower": 0})
		Net.send_command({"a": "sell", "cell": "x"})
		return
	for t in boards[0].get("t", []):
		if t[3] != 1:
			print("AUTOTEST %s : tourelle du client vue (case %d, propriétaire %d)" % [role, t[0], t[3]])
			_finish(true, "")
			return


func _finish(ok: bool, reason: String) -> void:
	if _done:
		return
	_done = true
	print("AUTOTEST %s : %s" % [role, "OK" if ok else "ÉCHEC — " + reason])
	# Laisse le temps aux derniers paquets de partir avant de couper
	await get_tree().create_timer(1.0).timeout
	Net.leave()
	get_tree().quit(0 if ok else 1)

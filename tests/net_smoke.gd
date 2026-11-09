extends Node
## Test réseau de bout en bout, lancé par main.gd avec « -- --autotest=host » ou « --autotest=client ».
## L'hôte attend un joueur et lance une partie coop ; le client construit une tourelle ;
## chacun vérifie dans les instantanés que la tourelle du client existe, puis quitte (code 0).

const TIMEOUT := 25.0

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
		_finish(false, "rôle inconnu : " + role)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT and not _done:
		_finish(false, "délai dépassé")


func _on_lobby() -> void:
	if Net.players.size() >= 2 and not _started:
		print("AUTOTEST hôte : joueur connecté (%s)" % Net.players.values()[1]["name"])
		Net.start_match()


func _on_snapshot(snap: Dictionary) -> void:
	if _done:
		return
	var boards: Array = snap.get("b", [])
	if boards.is_empty():
		return
	if role == "client" and not _built:
		_built = true
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

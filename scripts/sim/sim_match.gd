class_name SimMatch
extends RefCounted
## Partie complète simulée par l'hôte : joueurs, plateaux, vagues, règles, fin de partie.
##
## Coopération : un plateau partagé, vies communes, chacun son or.
## Versus : un plateau par joueur ; envoyer des monstres chez l'adversaire augmente le revenu.
## Après la dernière vague, le versus continue en « mort subite » (vagues de plus en plus dures).

enum Mode { COOP, VERSUS }

const FIRST_WAVE_DELAY := 20.0
const BETWEEN_WAVES := 12.0
const SELL_RATIO := 0.7
const VERSUS_BASE_INCOME := 10
const COOP_HP_PER_EXTRA_PLAYER := 0.5
const ENDLESS_HP_GROWTH := 1.3

var data: GameData
var map: MapDef
var mode := Mode.COOP
var players := {}  # id -> {name, gold, income, board, ready, alive, connected}
var order: Array[int] = []
var boards: Array[SimBoard] = []
var wave_index := -1
## Secondes avant la prochaine vague ; négatif quand aucun compte à rebours n'est en cours.
var countdown := FIRST_WAVE_DELAY
var ended := false
var result := ""  # "victory", "defeat" ou "winner"
var winner := 0
var tick := 0


## roster : [[id, nom, couleur], ...] dans l'ordre d'arrivée des joueurs.
func _init(p_data: GameData, map_index: int, p_mode: int, roster: Array) -> void:
	data = p_data
	map = data.maps[map_index]
	mode = p_mode
	var lives: int = data.player["start_lives"]
	for entry in roster:
		var id: int = entry[0]
		if mode == Mode.VERSUS or boards.is_empty():
			boards.append(SimBoard.new(data, map, lives))
		players[id] = {
			"name": entry[1], "gold": int(data.player["start_gold"]), "income": 0,
			"board": boards.size() - 1, "ready": false, "alive": true, "connected": true,
		}
		order.append(id)


func step(dt: float) -> void:
	if ended:
		return
	tick += 1
	_update_countdown(dt)
	for i in boards.size():
		var b := boards[i]
		if not b.alive:
			continue
		for reward in b.step(dt):
			_credit(reward[0], reward[1])
		if not b.alive:
			_on_board_lost(i)
	_check_end()


## Applique la commande d'un joueur. Renvoie "" si elle est acceptée, sinon la raison du refus.
func apply_command(id: int, cmd: Dictionary) -> String:
	if ended:
		return "La partie est terminée"
	var p: Dictionary = players.get(id, {})
	if p.is_empty() or not p["connected"]:
		return "Joueur inconnu"
	if not p["alive"]:
		return "Tu as été éliminé"
	var board: SimBoard = boards[int(p["board"])]
	match cmd["a"]:
		"build":
			return MatchActions.build(self, id, p, board, cmd["cell"], cmd["tower"])
		"upgrade":
			return MatchActions.upgrade(self, id, p, board, cmd["cell"])
		"sell":
			return MatchActions.sell(id, p, board, cmd["cell"])
		"mode":
			return MatchActions.cycle_target(id, board, cmd["cell"])
		"send":
			return MatchActions.send(self, id, p, cmd["monster"])
		"ready":
			return _set_ready(id)
	return "Commande inconnue"


func player_left(id: int) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	p["connected"] = false
	p["ready"] = false
	if mode == Mode.VERSUS and p["alive"]:
		p["alive"] = false
		boards[int(p["board"])].eliminate()
	if countdown >= 0.0 and _active_count() > 0 and _all_ready():
		launch_next_wave()
	_check_end()


func launch_next_wave() -> void:
	var bonus := int(maxf(countdown, 0.0))
	wave_index += 1
	countdown = -1.0
	var total := map.waves.size()
	var wave: Dictionary = data.waves[map.waves[mini(wave_index, total - 1)]]
	var hp_mult := float(wave["hp"])
	if mode == Mode.COOP:
		hp_mult *= 1.0 + COOP_HP_PER_EXTRA_PLAYER * maxi(0, _active_count() - 1)
	hp_mult *= endless_mult()
	for b in boards:
		if b.alive:
			b.queue_wave(wave, hp_mult)
	for id in order:
		var p: Dictionary = players[id]
		p["ready"] = false
		if not p["alive"] or not p["connected"]:
			continue
		p["gold"] += int(wave["gold"]) + bonus
		if mode == Mode.VERSUS:
			p["gold"] += VERSUS_BASE_INCOME + int(p["income"])


func snapshot() -> Dictionary:
	var pl := []
	for id in order:
		var p: Dictionary = players[id]
		pl.append([id, p["gold"], p["income"], p["ready"], p["alive"], p["board"]])
	var bs := []
	for b in boards:
		bs.append(b.snapshot())
	return {
		"tick": tick, "wave": wave_index + 1, "total": map.waves.size(),
		"cd": snappedf(countdown, 0.1), "end": ended, "res": result, "win": winner,
		"pl": pl, "b": bs,
	}


func _update_countdown(dt: float) -> void:
	if countdown < 0.0:
		if _has_next_wave() and not _wave_spawning():
			countdown = BETWEEN_WAVES
		return
	countdown -= dt
	if countdown <= 0.0:
		countdown = 0.0
		launch_next_wave()


func _has_next_wave() -> bool:
	return mode == Mode.VERSUS or wave_index + 1 < map.waves.size()


func _wave_spawning() -> bool:
	for b in boards:
		if b.alive and b.spawns_pending():
			return true
	return false


## Multiplicateur de PV de la « mort subite » (après la dernière vague, en versus).
func endless_mult() -> float:
	return pow(ENDLESS_HP_GROWTH, maxi(0, wave_index - map.waves.size() + 1))


func _active_count() -> int:
	var n := 0
	for id in order:
		if players[id]["connected"] and players[id]["alive"]:
			n += 1
	return n


func _all_ready() -> bool:
	for id in order:
		var p: Dictionary = players[id]
		if p["connected"] and p["alive"] and not p["ready"]:
			return false
	return true


func _credit(owner: int, gold: int) -> void:
	var p: Dictionary = players.get(owner, {})
	if not p.is_empty() and p["connected"]:
		p["gold"] += gold


func _on_board_lost(index: int) -> void:
	if mode != Mode.VERSUS:
		return
	for id in order:
		if players[id]["board"] == index:
			players[id]["alive"] = false
			players[id]["ready"] = false


func _check_end() -> void:
	if ended:
		return
	if mode == Mode.COOP:
		if not boards[0].alive:
			_finish("defeat", 0)
		elif wave_index >= map.waves.size() - 1 and boards[0].is_clear():
			_finish("victory", 0)
		return
	var alive_ids: Array[int] = []
	for id in order:
		if players[id]["alive"]:
			alive_ids.append(id)
	if order.size() >= 2 and alive_ids.size() <= 1:
		_finish("winner", alive_ids[0] if alive_ids.size() == 1 else 0)
	elif alive_ids.is_empty():
		_finish("defeat", 0)


func _finish(p_result: String, p_winner: int) -> void:
	ended = true
	result = p_result
	winner = p_winner
	countdown = -1.0


func _set_ready(id: int) -> String:
	if countdown < 0.0:
		return "Aucune vague en attente"
	players[id]["ready"] = true
	if _all_ready():
		launch_next_wave()
	return ""


## Plateau du prochain adversaire encore en jeu, dans l'ordre des joueurs (-1 si aucun).
func next_opponent_board(id: int) -> int:
	var start := order.find(id)
	for k in range(1, order.size()):
		var other: int = order[(start + k) % order.size()]
		if players[other]["alive"]:
			return players[other]["board"]
	return -1

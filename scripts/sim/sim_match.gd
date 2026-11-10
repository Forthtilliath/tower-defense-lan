class_name SimMatch
extends RefCounted
## Partie complète simulée par l'hôte : joueurs, plateaux, vagues, règles, fin de partie.
##
## Coopération : un plateau partagé, vies communes, chacun son or (dons possibles entre alliés).
## Versus : un plateau par joueur ; envoyer des monstres chez l'adversaire augmente le revenu.
## Après la dernière vague, le versus continue en « mort subite » (vagues de plus en plus dures).
## La difficulté choisie règle les PV des monstres, les vies, l'or de départ et les primes ;
## en coopération, chaque joueur en plus ajoute des monstres et des PV (coop_scaling).
## L'enchaînement des vagues (rythme, appel de vague) est dans MatchFlow.

enum Mode { COOP, VERSUS }
## Rythme de construction (coopération) : à tout moment, ou seulement entre deux vagues.
enum Rhythm { FREE, BETWEEN }
## Qui lance la vague suivante : tous les joueurs prêts, ou l'hôte seul (coopération).
enum Launch { VOTE, HOST }

const RHYTHM_NAMES := ["Libre", "Entre les vagues"]
const LAUNCH_NAMES := ["Vote de tous", "Hôte seul"]
const BETWEEN_WAVES := 12.0
const BUILD_PHASE := 20.0
const SELL_RATIO := 0.7
const VERSUS_BASE_INCOME := 10
const ENDLESS_HP_GROWTH := 1.3

var data: GameData
var map: MapDef
var mode := Mode.COOP
var rhythm := Rhythm.FREE
var launch := Launch.VOTE
var difficulty: Dictionary
## id -> {name, gold, income, board, ready, alive, connected, builder, gold_mult}
## gold_mult : multiplicateur de l'or de départ et des vagues (voir gold_mult_for).
var players := {}
var order: Array[int] = []
var boards: Array[SimBoard] = []
var wave_index := -1
## Secondes avant la prochaine vague ; négatif quand aucun compte à rebours n'est en cours.
## Avant la première vague : 0, sans décompte (elle attend d'être lancée par les joueurs).
var countdown := 0.0
var ended := false
var result := ""  # "victory", "defeat" ou "winner"
var winner := 0
var tick := 0
## Messages à transmettre à d'autres joueurs que l'auteur d'une action : [[id, texte], ...]
var notices: Array = []
## Vies de chaque plateau au départ de la vague précédente (vagues sans fuite du Parieur).
var _lives_mark := {}
## Coopération sur une carte à plusieurs couloirs : couloirs ouverts, un par joueur (MapDef.open_paths).
var open_paths: Array[int] = []


## roster : [[id, nom, couleur, bâtisseur, talents], ...] dans l'ordre d'arrivée (bâtisseur et
## talents facultatifs ; les talents sont déjà validés par le salon).
## difficulty_index : index dans GameData.difficulties (1 = Normal dans les données fournies).
## options : {rhythm, launch} (coopération uniquement).
func _init(p_data: GameData, map_index: int, p_mode: int, roster: Array, difficulty_index := 1, options := {}) -> void:
	data = p_data
	map = data.maps[map_index]
	mode = p_mode
	difficulty = data.difficulties[clampi(difficulty_index, 0, data.difficulties.size() - 1)]
	if mode == Mode.COOP:
		rhythm = clampi(int(options.get("rhythm", Rhythm.FREE)), 0, RHYTHM_NAMES.size() - 1)
		launch = clampi(int(options.get("launch", Launch.VOTE)), 0, LAUNCH_NAMES.size() - 1)
	var lives: int = difficulty["lives"]
	if mode == Mode.COOP:
		open_paths = map.open_paths(roster.size())
		lives *= lanes_open()  # chaque couloir défendu à part laisse passer ses propres monstres
	for i in roster.size():
		var entry: Array = roster[i]
		var id: int = entry[0]
		var builder: int = clampi(int(entry[3]) if entry.size() > 3 else 0, 0, data.builders.size() - 1)
		var kit := PlayerKit.make(data, builder, entry[4] if entry.size() > 4 else {})
		if mode == Mode.VERSUS or boards.is_empty():
			boards.append(SimBoard.new(data, map, lives, difficulty["reward"]))
			boards[-1].armor_bonus = float(difficulty["armor"])
			boards[-1].open_paths = open_paths
		var mult := gold_mult_for(i, roster.size()) if mode == Mode.COOP else 1.0
		players[id] = {
			"name": entry[1], "builder": builder, "kit": kit, "gold_mult": mult, "income": 0,
			"gold": int(roundf(float(data.player["start_gold"]) * difficulty["gold"] * mult)) + kit.start_gold,
			"board": boards.size() - 1, "ready": false, "alive": true, "connected": true,
		}
		order.append(id)


func step(dt: float) -> void:
	if ended:
		return
	tick += 1
	MatchFlow.update(self, dt)
	for i in boards.size():
		var b := boards[i]
		if not b.alive:
			continue
		for reward in b.step(dt):
			MatchEconomy.credit_bounty(self, reward[0], reward[1])
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
			return MatchActions.sell(self, id, p, board, cmd["cell"])
		"mode":
			return MatchActions.cycle_target(id, board, cmd["cell"])
		"raze":
			return MatchActions.raze(self, id, p, board, cmd["cell"])
		"tile":
			return MatchActions.place_tile(self, id, p, board, cmd["cell"], cmd["special"])
		"send":
			return MatchActions.send(self, id, p, cmd["monster"])
		"give":
			return MatchActions.give(self, id, p, cmd["to"], cmd["amount"])
		"ready":
			return MatchFlow.call_wave(self, id)
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
	if launch == Launch.VOTE and _active_count() > 0 and all_ready() and MatchFlow.can_call(self):
		launch_next_wave()
	_check_end()


func launch_next_wave() -> void:
	var bonus := MatchFlow.early_bonus(self)
	wave_index += 1
	countdown = -1.0
	var total := map.waves.size()
	var wave: Dictionary = data.waves[map.waves[mini(wave_index, total - 1)]]
	var hp_mult := float(wave["hp"]) * monster_hp_mult()
	var count_mult := 1.0
	if mode == Mode.COOP:
		var scaling := coop_scaling(_active_count())
		hp_mult *= scaling[0]
		count_mult = scaling[1]
	var clean := {}
	for i in boards.size():
		var b := boards[i]
		if b.alive:
			if wave_index > 0 and b.lives == _lives_mark.get(i, -1):
				clean[i] = true
			_lives_mark[i] = b.lives
			b.queue_wave(wave, hp_mult, count_mult, wave_index)
	MatchEconomy.pay_wave(self, wave, bonus, clean)


func snapshot() -> Dictionary:
	var pl := []
	for id in order:
		var p: Dictionary = players[id]
		pl.append([id, p["gold"], p["income"], p["ready"], p["alive"], p["board"],
			MatchActions.charges_left(p, "raze"), MatchActions.charges_left(p, "tile")])
	var bs := []
	for b in boards:
		bs.append(b.snapshot())
	return {
		"tick": tick, "wave": wave_index + 1, "total": map.waves.size(),
		"cd": snappedf(countdown, 0.1), "end": ended, "res": result, "win": winner,
		"nx": MatchFlow.can_call(self), "tr": MatchFlow.can_trade(self),
		"pl": pl, "b": bs,
	}


## La première vague a-t-elle été lancée ?
func started() -> bool:
	return wave_index >= 0


func has_next_wave() -> bool:
	return mode == Mode.VERSUS or wave_index + 1 < map.waves.size()


## Renforcement coop selon le nombre de joueurs : [PV, nombre de monstres, or des joueurs].
## Sur une carte à plusieurs couloirs, seuls les couloirs ouverts (un par joueur au départ)
## reçoivent des monstres, chacun une vague solo complète. Si des joueurs partent, les couloirs
## restent ouverts : ceux qui restent en défendent plusieurs, avec l'or en proportion.
func coop_scaling(player_count: int) -> Array:
	var lanes := float(lanes_open())
	var per_lane := maxf(1.0, float(player_count)) / lanes
	if per_lane < 1.0:
		return [1.0, lanes, 1.0 / per_lane]
	var extra := per_lane - 1.0
	var hp := 1.0 + float(data.coop_scaling["hp"]) * extra
	var count := lanes * (1.0 + float(data.coop_scaling["count"]) * extra)
	return [hp, count, 1.0]


## Couloirs qui reçoivent des monstres (1 sur une carte à un seul couloir).
func lanes_open() -> int:
	return open_paths.size() if map.lanes > 1 and not open_paths.is_empty() else map.lanes


## Or de départ et des vagues du joueur n° index (chacun défend son couloir : or normal).
func gold_mult_for(_index: int, player_count: int) -> float:
	return coop_scaling(player_count)[2]


## Joueur qui mène la partie (l'hôte : premier de la liste).
func leader() -> int:
	return order[0]


## PV des monstres selon la difficulté et la « mort subite » (hors bonus coop).
func monster_hp_mult() -> float:
	return float(difficulty["hp"]) * endless_mult()


## Multiplicateur de PV de la « mort subite » (après la dernière vague, en versus).
func endless_mult() -> float:
	return pow(ENDLESS_HP_GROWTH, maxi(0, wave_index - map.waves.size() + 1))


func all_ready() -> bool:
	for id in order:
		var p: Dictionary = players[id]
		if p["connected"] and p["alive"] and not p["ready"]:
			return false
	return true


func _active_count() -> int:
	var n := 0
	for id in order:
		if players[id]["connected"] and players[id]["alive"]:
			n += 1
	return n


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


## Plateau du prochain adversaire encore en jeu, dans l'ordre des joueurs (-1 si aucun).
func next_opponent_board(id: int) -> int:
	var start := order.find(id)
	for k in range(1, order.size()):
		var other: int = order[(start + k) % order.size()]
		if players[other]["alive"]:
			return players[other]["board"]
	return -1

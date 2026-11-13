extends RefCounted
## Joueur automatique des tests d'équilibrage et des bilans (docs/BOT.md). Il joue chaque
## spécialisation comme un joueur qui la connaît : talents répartis dans sa branche (BotTalents),
## tourelles choisies d'après ses talents, les monstres à venir et les meilleures cases
## (BotPlayer, BotDefense, BotEval, BotCells), Terrassier qui façonne la carte (BotTerrain),
## pouvoir lancé dès qu'il est prêt, vagues appelées en avance tant qu'il ne perd pas de vie.

const Player := preload("res://tests/bot/bot_player.gd")
const Talents := preload("res://tests/bot/bot_talents.gd")
const Cells := preload("res://tests/bot/bot_cells.gd")

const DT := 0.05
## Secondes entre deux réflexions d'un bot.
const THINK_EVERY := 1.0
## Monstres présents à partir desquels il lance son pouvoir.
const POWER_CROWD := 5
const FIRST_WAVE_AFTER := 20.0
## Niveau des bots : un joueur qui a déjà quelques parties.
const BOT_LEVEL := 10
## Classe sans spécialisation précisée : l'Artilleur Tireur d'élite, le plus polyvalent.
const DEFAULT_SPEC := 1
const MAX_SECONDS := 2400.0

## Appelle la vague suivante en avance tant qu'il ne perd pas de vie (désactivable pour comparer).
var calls_early := true
## Trace des actions des bots (bilans).
var verbose := false
var players := {}  # id -> Player
var _elapsed := 0.0
var _timer := 0.0
var _wave := -1
var _lives := 0
var _lives_now := 0


func spec_branches(gd: GameData, builder: int) -> Array:
	return Talents.spec_branches(gd, builder)


func spec_count(gd: GameData, builder: int) -> int:
	return spec_branches(gd, builder).size()


func spec_id(gd: GameData, builder: int, spec: int) -> String:
	return spec_branches(gd, builder)[spec]["id"]


## Talents d'un bot : voir BotTalents.plan.
func auto_talents(gd: GameData, builder: int, level: int, spec := 0) -> Dictionary:
	return Talents.plan(gd, builder, level, spec)


## builders : une classe par bot (index, ou [index, spécialisation]) ; Artilleur par défaut.
## heritage : classes déjà montées au niveau maximum (les mêmes pour tous les bots).
func play(gd: GameData, map_index: int, count: int, difficulty: int, options := {}, builders := [], level := BOT_LEVEL, heritage := []) -> SimMatch:
	var sim := SimMatch.new(gd, map_index, SimMatch.Mode.COOP, roster(gd, count, builders, level, heritage), difficulty, options)
	run(sim)
	return sim


## Joueurs d'une partie de bots : [[id, nom, couleur, classe, talents, héritage], ...].
func roster(gd: GameData, count: int, builders := [], level := BOT_LEVEL, heritage := []) -> Array:
	var out := []
	for i in count:
		var entry: Variant = builders[i] if i < builders.size() else 0
		var b: int = entry[0] if entry is Array else entry
		var s: int = entry[1] if entry is Array else DEFAULT_SPEC
		out.append([i + 1, "Bot%d" % i, i, b, auto_talents(gd, b, level, s), heritage])
	return out


## Joue une partie déjà créée dont tous les joueurs sont des bots, jusqu'à sa fin.
## on_wave(sim) est appelé à chaque vague lancée ; s'il renvoie vrai, la partie s'arrête là.
func run(sim: SimMatch, on_wave := Callable()) -> void:
	start(sim)
	var wave := -1
	while not sim.ended and _elapsed < MAX_SECONDS:
		tick(sim)
		if wave != sim.wave_index:
			wave = sim.wave_index
			if on_wave.is_valid() and on_wave.call(sim):
				return


## Prépare les bots d'une partie ; tick() la fait ensuite avancer d'un pas (une interface peut
## ainsi la jouer image par image, pour les captures d'écran).
func start(sim: SimMatch) -> void:
	var cells := Cells.new()
	cells.reset(sim.boards[0].map)
	players = {}
	for id in sim.order:
		players[id] = Player.new(sim, id, cells)
		players[id].verbose = verbose
	_elapsed = 0.0
	_timer = 0.0
	_wave = -1
	_lives = 0
	_lives_now = sim.boards[0].lives


## Un pas de simulation (DT) : les bots réfléchissent toutes les THINK_EVERY secondes, appellent
## la vague suivante en avance tant qu'ils ne perdent pas de vie, lancent la première après
## FIRST_WAVE_AFTER secondes de préparation (elle ne part jamais seule).
func tick(sim: SimMatch) -> void:
	_timer -= DT
	if _timer <= 0.0:
		_timer = THINK_EVERY
		for id in sim.order:
			players[id].act(THINK_EVERY)
			use_power(sim, id)
		if _wave != sim.wave_index:
			_wave = sim.wave_index
			_lives = sim.boards[0].lives
		if calls_early and sim.started() and sim.boards[0].lives == _lives and MatchFlow.can_call(sim):
			for id in sim.order:
				sim.apply_command(id, {"a": "ready"})
	if not sim.started() and _elapsed >= FIRST_WAVE_AFTER:
		for id in sim.order:
			sim.apply_command(id, {"a": "ready"})
	var before := _snapshot_monsters(sim) if verbose else {}
	sim.step(DT)
	_elapsed += DT
	if verbose and sim.boards[0].lives < _lives_now:
		_trace_leaks(sim, before)
	_lives_now = sim.boards[0].lives


static func _snapshot_monsters(sim: SimMatch) -> Dictionary:
	var out := {}
	for m in sim.boards[0].monsters:
		out[m.id] = [m.type, m.ratio()]
	return out


## Trace : monstres sortis de la carte pendant le dernier pas (ceux qui ont disparu près de la sortie).
static func _trace_leaks(sim: SimMatch, before: Dictionary) -> void:
	var gone := []
	for id in before:
		if sim.boards[0].monster_by_id(id) == null and float(before[id][1]) > 0.9:
			gone.append(before[id][0])
	print("      fuite à %ds (vies %d) : %s" % [int(sim.boards[0].clock), sim.boards[0].lives, ", ".join(gone)])


## Pouvoir de son talent ultime, lancé dès qu'il est prêt et que la vague est là (au moins
## POWER_CROWD monstres) : visé sur le monstre le plus avancé, ou sur sa meilleure tourelle (Coup de génie).
func use_power(sim: SimMatch, id: int) -> void:
	var p: Dictionary = sim.players[id]
	var board := sim.boards[int(p["board"])]
	if MatchPowers.waves_left(sim, p) != 0 or board.monsters.size() < POWER_CROWD:
		return
	var cell := 0
	if p["kit"].power == "genius":
		var best: SimTower = null
		for c in board.towers:
			var t: SimTower = board.towers[c]
			if t.owner == id and (best == null or t.invested > best.invested):
				best = t
		cell = best.cell if best != null else 0
	else:
		var lead := board.monsters[0]
		for m in board.monsters:
			if m.ratio() > lead.ratio():
				lead = m
		var at := Vector2i(lead.pos.floor())
		cell = clampi(at.y, 0, board.map.height - 1) * board.map.width + clampi(at.x, 0, board.map.width - 1)
	sim.apply_command(id, {"a": "power", "cell": maxi(0, cell)})

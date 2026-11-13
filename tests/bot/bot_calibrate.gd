extends RefCounted
## Étalonnage de l'évaluateur du joueur automatique sur la vraie simulation : chaque tourelle,
## seule au bord d'une route droite, tire sur une file de monstres (au sol et volants) ; les
## dégâts réellement infligés, rapportés à ceux que BotEval prévoit, donnent un coefficient par
## tourelle et par niveau (temps de vol des projectiles, montée des brûlures, changements de cible,
## coups perdus…). Calculé une fois par processus.

const Eval := preload("res://tests/bot/bot_eval.gd")
const Foes := preload("res://tests/bot/bot_foes.gd")

const ROWS := ["........................", "........................", "S======================E",
	"........................", "........................"]
const TOWER_CELL := 11 + 24  # (11, 1) : contre la route
const LEVELS := [0, 3]
const GROUPS := [{"monster": "orc", "count": 10, "interval": 1.0}, {"monster": "goblin", "count": 10, "interval": 0.7},
	{"monster": "bat", "count": 8, "interval": 0.9}]
const SECONDS := 70.0
const DT := 0.05
const MIN_FACTOR := 0.3
const MAX_FACTOR := 1.6

static var _factors := {}  # id des données -> {type -> [facteur niveau 1, facteur niveau 4]}


## Coefficient à appliquer aux dégâts prévus de cette tourelle à ce niveau (1 : prévision juste).
static func factor(data: GameData, type: String, level: int) -> float:
	var table := _table(data)
	if not table.has(type):
		return 1.0
	var f: Array = table[type]
	return lerpf(f[0], f[1], clampf(float(level) / float(LEVELS[1]), 0.0, 1.0))


static func _table(data: GameData) -> Dictionary:
	var key := str(data.get_instance_id())
	if not _factors.has(key):
		_factors[key] = _measure(data)
	return _factors[key]


static func _measure(data: GameData) -> Dictionary:
	var out := {}
	var map = MapDef.parse("etalon", "Étalon", ROWS, ["x"], [])
	if map is String:
		return out
	var foes := _foes(data, map)
	for type in data.tower_order:
		var def: Dictionary = data.towers[type]
		if def["support"]:
			continue
		var l0: Dictionary = def["levels"][0]
		# Tourelles de contrôle pur : leur valeur est ailleurs (BotEval.control)
		if float(l0["damage"]) + float(l0["poison_dps"]) + float(l0["burn_dps"]) + float(l0["bleed"]) + float(l0["patch_dps"]) <= 0.0:
			continue
		var pair := []
		for level in LEVELS:
			var predicted := _predicted(data, map, type, level, foes)
			var measured := _played(data, map, type, level)
			pair.append(clampf(measured / predicted, MIN_FACTOR, MAX_FACTOR) if predicted > 0.0 else 1.0)
		out[type] = pair
	return out


## Groupes de la file d'essai, comme BotFoes les décrit.
static func _foes(data: GameData, map: MapDef) -> Array:
	var out := []
	var total := 0.0
	for g in GROUPS:
		var m := SimMonster.new()
		m.setup(data.monsters[g["monster"]], 1.0, 1.0, {})
		var speed := m.speed * (map.flyer_speed if m.flying else 1.0)
		out.append({"type": g["monster"], "hp": m.max_hp, "speed": speed, "count": float(g["count"]),
			"gap": maxf(0.3, speed * float(g["interval"])), "weight": 1.0, "flying": m.flying, "armor": m.armor,
			"mech": m.mechanical, "hover": m.hover, "big": false, "slow_immune": m.slow_immune, "cc_resist": m.cc_resist,
			"taken": m.element_taken, "path": 0, "regen": m.regen})
		total += m.max_hp * g["count"]
	return out


## Dégâts prévus par BotEval pour la file entière (même calcul que BotDefense, sans auras).
static func _predicted(data: GameData, map: MapDef, type: String, level: int, foes: Array) -> float:
	var s := data.tower_stats(type, level, -1, null)
	var def: Dictionary = data.towers[type]
	var reach := float(s["range"])
	var c := map.cell_center(TOWER_CELL)
	var total := 0.0
	for f in foes:
		if f["flying"] and not def["air"]:
			continue
		var cov := 0.0
		var last := -1.0
		var d := 0.0
		var length := map.path_length(0, f["flying"])
		while d < length:
			if c.distance_to(map.position_at(0, d, f["flying"])) <= reach:
				cov += 0.25
				last = d
			d += 0.25
		var count := float(f["count"])
		if cov <= 0.0:
			continue
		var time := (cov + (count - 1.0) * minf(float(f["gap"]), cov)) / float(f["speed"]) / count
		var parts := Eval.dps_parts(data, type, s, f, false, false, false, time)
		var tail := clampf((length - last) / (float(f["speed"]) * 3.5), 0.25, 1.0) if last >= 0.0 else 0.25
		total += (float(parts[0]) + (float(parts[1]) + float(parts[2])) * tail) * time * count
	return total


## Dégâts réellement infligés (contributions des monstres) par la tourelle seule.
static func _played(data: GameData, map: MapDef, type: String, level: int) -> float:
	var board := SimBoard.new(data, map, 100000)
	var t := board.add_tower(TOWER_CELL, type, 1, 0, null)
	t.level = level
	board.refresh_stats(t)
	if data.towers[type].get("attack", "shot") == "beam":
		t.target_mode = SimTower.Target.STRONGEST
	board.queue_wave({"groups": GROUPS, "hp": 1.0, "gold": 0}, 1.0, 1.0, 0)
	var seen := {}
	for i in int(SECONDS / DT):
		board.step(DT)
		for m in board.monsters:
			seen[m.id] = m
		if i * DT > 30.0 and board.is_clear():
			break
	var dealt := 0.0
	for id in seen:
		var m: SimMonster = seen[id]
		dealt += float(m.contrib.get(1, 0.0))
	return dealt

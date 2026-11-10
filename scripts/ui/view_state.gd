class_name ViewState
extends RefCounted
## État affiché à l'écran, reconstruit à partir des instantanés de l'hôte.
## Chaque instantané est vérifié en entier : au moindre champ invalide, il est ignoré.
## Les positions sont interpolées entre deux instantanés pour un mouvement fluide.

const MAX_ENTITIES := 3000
const RESULTS := ["", "victory", "defeat", "winner"]

var data: GameData
var map: MapDef
var board_count := 1
var received := false
var wave := 0
var total := 0
var countdown := -1.0
var ended := false
var result := ""
var winner := 0
var speed := 1
var interval := 0.1
## La vague suivante peut être appelée / construire, améliorer et vendre sont permis.
var can_call := false
var can_trade := true
var players := {}  # id -> {gold, income, ready, alive, board}
var boards: Array[Dictionary] = []
var _t := 0.0


func _init(p_data: GameData, p_map: MapDef, p_board_count: int) -> void:
	data = p_data
	map = p_map
	board_count = p_board_count


func advance(dt: float) -> void:
	_t += dt


func alpha() -> float:
	return clampf(_t / interval, 0.0, 1.0)


func monster_progress(m: Dictionary) -> float:
	return lerpf(m["from"], m["to"], alpha())


func projectile_pos(p: Dictionary) -> Vector2:
	return (p["from"] as Vector2).lerp(p["to"], alpha())


## Intègre un instantané. Renvoie false (et ne change rien) s'il est invalide.
func apply(snap: Variant) -> bool:
	var parsed = _parse(snap)
	if parsed == null:
		return false
	var a := alpha()
	for i in parsed["boards"].size():
		if i >= boards.size():
			continue
		var nb: Dictionary = parsed["boards"][i]
		var ob: Dictionary = boards[i]
		for id in nb["monsters"]:
			if ob["monsters"].has(id):
				var om: Dictionary = ob["monsters"][id]
				nb["monsters"][id]["from"] = lerpf(om["from"], om["to"], a)
		for id in nb["proj"]:
			if ob["proj"].has(id):
				var op: Dictionary = ob["proj"][id]
				nb["proj"][id]["from"] = (op["from"] as Vector2).lerp(op["to"], a)
	wave = parsed["wave"]
	total = parsed["total"]
	countdown = parsed["cd"]
	ended = parsed["end"]
	result = parsed["res"]
	winner = parsed["win"]
	speed = parsed["speed"]
	interval = parsed["iv"]
	can_call = parsed["nx"]
	can_trade = parsed["tr"]
	players = parsed["players"]
	boards.assign(parsed["boards"])
	received = true
	_t = 0.0
	return true


func _parse(snap: Variant) -> Variant:
	if typeof(snap) != TYPE_DICTIONARY:
		return null
	var s: Dictionary = snap
	var out := {
		"wave": Check.as_int(s.get("wave"), 0, 100000),
		"total": Check.as_int(s.get("total"), 0, 1000),
		"cd": Check.as_num(s.get("cd"), -1.0, 1000.0),
		"end": Check.as_bool(s.get("end")),
		"res": s.get("res") if typeof(s.get("res")) == TYPE_STRING and RESULTS.has(s.get("res")) else null,
		"win": Check.as_int(s.get("win"), 0, NetPayloads.MAX_PEER_ID),
		"speed": Check.as_int(s.get("speed", 1), 1, 4),
		"iv": Check.as_num(s.get("iv", 0.1), 0.01, 1.0),
		"nx": Check.as_bool(s.get("nx")),
		"tr": Check.as_bool(s.get("tr")),
		"players": _parse_players(s.get("pl")),
		"boards": _parse_boards(s.get("b")),
	}
	for key in out:
		if out[key] == null:
			return null
	return out


func _parse_players(raw: Variant) -> Variant:
	if not _is_list(raw, 8):
		return null
	var out := {}
	for e in raw:
		if not _is_tuple(e, 6):
			return null
		var id = Check.as_int(e[0], 1, NetPayloads.MAX_PEER_ID)
		var gold = Check.as_int(e[1], 0, 1000000000)
		var income = Check.as_int(e[2], 0, 1000000000)
		var ready = Check.as_bool(e[3])
		var alive = Check.as_bool(e[4])
		var board = Check.as_int(e[5], 0, board_count - 1)
		if id == null or gold == null or income == null or ready == null or alive == null or board == null:
			return null
		out[id] = {"gold": gold, "income": income, "ready": ready, "alive": alive, "board": board}
	return out


func _parse_boards(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_ARRAY or raw.size() != board_count:
		return null
	var out := []
	for b in raw:
		var parsed = _parse_board(b)
		if parsed == null:
			return null
		out.append(parsed)
	return out


func _parse_board(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var b: Dictionary = raw
	var lives = Check.as_int(b.get("lives"), 0, 100000)
	var alive = Check.as_bool(b.get("alive"))
	var towers = _parse_towers(b.get("t"))
	var monsters = _parse_monsters(b.get("m"))
	var proj = _parse_projectiles(b.get("p"))
	var fx = _parse_fx(b.get("fx"))
	var patches = _parse_patches(b.get("z"))
	if lives == null or alive == null or towers == null or monsters == null or proj == null or fx == null or patches == null:
		return null
	return {"lives": lives, "alive": alive, "towers": towers, "monsters": monsters, "proj": proj, "fx": fx, "patches": patches}


func _parse_towers(raw: Variant) -> Variant:
	if not _is_list(raw, map.cell_count()):
		return null
	var out := {}
	for e in raw:
		if not _is_tuple(e, 7):
			return null
		var cell = Check.as_int(e[0], 0, map.cell_count() - 1)
		var type = Check.as_int(e[1], 0, data.tower_order.size() - 1)
		var invested = Check.as_int(e[6], 0, 1000000)  # or payé (revente exacte, réductions comprises)
		if cell == null or type == null or not map.is_buildable(cell):
			return null
		var id: String = data.tower_order[type]
		var level = Check.as_int(e[2], 0, data.tower_levels(id).size() - 1)
		var owner = Check.as_int(e[3], 1, NetPayloads.MAX_PEER_ID)
		var mode = Check.as_int(e[4], 0, SimTower.TARGET_NAMES.size() - 1)
		var buffs = Check.as_int(e[5], 0, 127)  # auras reçues, et 8 : brouillée
		if level == null or owner == null or mode == null or buffs == null or invested == null:
			return null
		out[cell] = {"type": id, "level": level, "owner": owner, "mode": mode, "buffs": buffs, "invested": invested}
	return out


func _parse_monsters(raw: Variant) -> Variant:
	if not _is_list(raw, MAX_ENTITIES):
		return null
	var out := {}
	for e in raw:
		if not _is_tuple(e, 6):
			return null
		var id = Check.as_int(e[0], 0, NetPayloads.MAX_PEER_ID)
		var type = Check.as_int(e[1], 0, data.monster_order.size() - 1)
		var path = Check.as_int(e[2], 0, map.start_count() - 1)
		var progress = Check.as_num(e[3], 0.0, 100000.0)
		var hp = Check.as_int(e[4], 0, 255)
		var flags = Check.as_int(e[5], 0, 4095)
		if id == null or type == null or path == null or progress == null or hp == null or flags == null:
			return null
		var type_id: String = data.monster_order[type]
		out[id] = {
			"type": type_id, "path": path, "flying": data.monsters[type_id]["flying"],
			"from": progress, "to": progress, "hp": hp,
			"slowed": flags & 1 != 0, "poisoned": flags & 2 != 0, "elite": flags & 4 != 0,
			"burning": flags & 8 != 0, "bleeding": flags & 16 != 0, "stunned": flags & 32 != 0,
			"feared": flags & 64 != 0, "charmed": flags & 128 != 0, "warded": flags & 256 != 0,
			"frostbitten": flags & 512 != 0, "shocked": flags & 1024 != 0, "grounded": flags & 2048 != 0,
		}
	return out


func _parse_projectiles(raw: Variant) -> Variant:
	if not _is_list(raw, MAX_ENTITIES):
		return null
	var out := {}
	for e in raw:
		if not _is_tuple(e, 3):
			return null
		var id = Check.as_int(e[0], 0, NetPayloads.MAX_PEER_ID)
		var x = Check.as_num(e[1], -2.0, map.width + 2.0)
		var y = Check.as_num(e[2], -2.0, map.height + 2.0)
		if id == null or x == null or y == null:
			return null
		out[id] = {"from": Vector2(x, y), "to": Vector2(x, y)}
	return out


func _parse_fx(raw: Variant) -> Variant:
	if not _is_list(raw, MAX_ENTITIES):
		return null
	var out := []
	for e in raw:
		if not _is_tuple(e, 6):
			return null
		var kind = Check.as_int(e[0], 0, SimBoard.Fx.size() - 1)
		var x = Check.as_num(e[1], -2.0, map.width + 2.0)
		var y = Check.as_num(e[2], -2.0, map.height + 2.0)
		var life = Check.as_num(e[5], 0.0, 1.0)
		if kind == null or x == null or y == null or life == null:
			return null
		var f := {"kind": kind, "pos": Vector2(x, y), "life": life}
		if SimBoard.is_round_fx(kind):  # rayon et teinte (index de tourelle)
			f["radius"] = Check.as_num(e[3], 0.0, 40.0)
			f["tint"] = Check.as_int(e[4], 0, data.tower_order.size() - 1)
			if f["radius"] == null or f["tint"] == null:
				return null
		else:  # point d'arrivée
			var a = Check.as_num(e[3], -2.0, map.width + 2.0)
			var b = Check.as_num(e[4], -2.0, map.height + 2.0)
			if a == null or b == null:
				return null
			f["to"] = Vector2(a, b)
		out.append(f)
	return out


## Nappes au sol : [x, y, rayon, vie restante, index de tourelle].
func _parse_patches(raw: Variant) -> Variant:
	if not _is_list(raw, MAX_ENTITIES):
		return null
	var out := []
	for e in raw:
		if not _is_tuple(e, 5):
			return null
		var x = Check.as_num(e[0], -2.0, map.width + 2.0)
		var y = Check.as_num(e[1], -2.0, map.height + 2.0)
		var radius = Check.as_num(e[2], 0.0, 5.0)
		var life = Check.as_num(e[3], 0.0, 1.0)
		var tint = Check.as_int(e[4], 0, data.tower_order.size() - 1)
		if x == null or y == null or radius == null or life == null or tint == null:
			return null
		out.append({"pos": Vector2(x, y), "radius": radius, "life": life, "type": data.tower_order[tint]})
	return out


static func _is_list(raw: Variant, max_size: int) -> bool:
	return typeof(raw) == TYPE_ARRAY and raw.size() <= max_size


static func _is_tuple(raw: Variant, size: int) -> bool:
	return typeof(raw) == TYPE_ARRAY and raw.size() == size

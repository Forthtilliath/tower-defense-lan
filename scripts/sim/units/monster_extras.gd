class_name MonsterExtras
extends RefCounted
## Capacités des monstres des thèmes (champs DataSchema.EXTRAS, lus dans la définition du
## monstre), jouées à chaque pas après les déplacements et les autres capacités :
## - meute (Loup des neiges) et piétinement (Mammouth) : vitesse du moment (MonsterMarks.pace) ;
## - rôdeur (Vautour) : ne dépasse pas le monstre au sol le plus avancé ;
## - bosquet (Sylvain) : régénération multipliée à côté d'un arbre ;
## - enfoui (Ver des sables) : ni visé ni touché pendant burrow_duration ;
## - ponte (Araignée : à intervalles ; Hydre : par paliers de PV perdus) et relève des morts
##   (Nécromancien) : petits monstres ajoutés au plateau à la fin du pas, comme une division.
## Un monstre charmé, étourdi ou apeuré n'use plus de ses capacités actives.

## Tombes : monstres au sol morts récemment, qu'un nécromancien peut relever.
const GRAVES_MAX := 40
const LURK_PACE := 0.3
## Une tombe reste relevable un peu plus longtemps que l'intervalle du nécromancien.
const RAISE_GRACE := 1.0


static func update(b: SimBoard, dt: float) -> void:
	var front := _ground_front(b)
	for m in b.monsters:
		m.marks.pace = 1.0
		m.marks.regen_mult = 1.0
	for m in b.monsters:
		if not m.is_alive():
			continue
		var def: Dictionary = b.data.monsters[m.type]
		if def["haste"] > 0.0 and not m.is_charmed():
			var r2: float = def["haste_radius"] * def["haste_radius"]
			for o in b.monsters:
				if o != m and not o.flying and o.pos.distance_squared_to(m.pos) <= r2:
					o.marks.pace = maxf(o.marks.pace, 1.0 + def["haste"])
		if def["pack_count"] > 0.0 and _kin(b, m, def["pack_radius"]) >= int(def["pack_count"]):
			m.marks.pace *= 1.0 + def["pack_speed"]
		if def["lurk"] and m.flying and m.ratio() > front:
			m.marks.pace *= LURK_PACE
		if def["grove_regen"] > 0.0 and _near_tree(b.map, m.pos):
			m.marks.regen_mult = def["grove_regen"]
		var busy := m.is_charmed() or m.is_stunned() or m.is_feared()
		if def["burrow_interval"] > 0.0:
			_burrow(m, def, dt, busy)
		if busy:
			continue
		if def["brood_into"] != "":
			_brood(b, m, def, dt)
		if def["raise_into"] != "":
			_raise(b, m, def, dt)


## Mort d'un monstre au sol : sa tombe reste quelques secondes (relève du nécromancien).
static func on_death(b: SimBoard, m: SimMonster) -> void:
	if m.flying:
		return
	var graves: Array = b.get_meta("graves", [])
	graves.append([m.pos, m.path, m.progress, b.clock])
	if graves.size() > GRAVES_MAX:
		graves.pop_front()
	b.set_meta("graves", graves)


## Part de route du monstre au sol le plus avancé (1 s'il n'y en a aucun).
static func _ground_front(b: SimBoard) -> float:
	var front := -1.0
	for m in b.monsters:
		if m.is_alive() and not m.flying:
			front = maxf(front, m.ratio())
	return front if front >= 0.0 else 1.0


static func _kin(b: SimBoard, m: SimMonster, radius: float) -> int:
	var n := 0
	for o in b.monsters:
		if o != m and o.type == m.type and o.is_alive() and o.pos.distance_squared_to(m.pos) <= radius * radius:
			n += 1
	return n


static func _near_tree(map: MapDef, pos: Vector2) -> bool:
	var c := Vector2i(pos.floor())
	for d in MapDef.DIRS + [Vector2i.ZERO]:
		var at: Vector2i = c + d
		if map.in_bounds(at) and map.cell_at(at) == MapDef.Cell.TREE:
			return true
	return false


static func _burrow(m: SimMonster, def: Dictionary, dt: float, busy: bool) -> void:
	var clock := float(m.marks.clocks.get("burrow", 0.0)) + (0.0 if busy and not m.marks.burrowed else dt * m.marks.ability_pace())
	if m.marks.burrowed and clock >= def["burrow_duration"]:
		m.marks.burrowed = false
		clock = 0.0
	elif not m.marks.burrowed and clock >= def["burrow_interval"]:
		m.marks.burrowed = true
		clock = 0.0
	m.marks.clocks["burrow"] = clock


static func _brood(b: SimBoard, m: SimMonster, def: Dictionary, dt: float) -> void:
	if def["brood_steps"] > 0:  # un petit par palier de PV perdus (l'hydre perd une tête)
		var steps: int = def["brood_steps"]
		var due := mini(steps - 1, floori((1.0 - m.hp / m.max_hp) * steps))
		while int(m.marks.clocks.get("steps", 0)) < due:
			m.marks.clocks["steps"] = int(m.marks.clocks.get("steps", 0)) + 1
			_add(b, def["brood_into"], m.hp_mult, m.path, maxf(0.0, m.progress - 0.3), m.modifier)
	if def["brood_interval"] > 0.0:
		var clock := float(m.marks.clocks.get("brood", 0.0)) + dt * m.marks.ability_pace()
		if clock >= def["brood_interval"]:
			clock -= def["brood_interval"]
			_add(b, def["brood_into"], m.hp_mult, m.path, maxf(0.0, m.progress - 0.3), m.modifier)
		m.marks.clocks["brood"] = clock


static func _raise(b: SimBoard, m: SimMonster, def: Dictionary, dt: float) -> void:
	var clock := float(m.marks.clocks.get("raise", 0.0)) + dt * m.marks.ability_pace()
	if clock < def["raise_interval"]:
		m.marks.clocks["raise"] = clock
		return
	m.marks.clocks["raise"] = 0.0
	var graves: Array = b.get_meta("graves", [])
	var r2: float = def["raise_radius"] * def["raise_radius"]
	for i in graves.size():
		var g: Array = graves[i]
		if b.clock - float(g[3]) <= def["raise_interval"] + RAISE_GRACE and m.pos.distance_squared_to(g[0]) <= r2:
			graves.remove_at(i)
			_add(b, def["raise_into"], m.hp_mult, g[1], g[2], m.modifier)
			b.add_fx(SimBoard.Fx.RING, g[0], Vector2.ZERO, 0.6)
			return


static func _add(b: SimBoard, type: String, hp_mult: float, path: int, progress: float, mod: Dictionary) -> void:
	if b.monsters.size() + b._born.size() >= SimBoard.MAX_MONSTERS:
		return
	b._born.append(b.spawn(type, hp_mult, path, progress, false, mod))

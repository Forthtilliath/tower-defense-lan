class_name SimBoard
extends RefCounted
## Plateau simulé par l'hôte : apparitions, déplacements, tirs et dégâts.
## En coopération il n'y a qu'un plateau partagé ; en versus, un par joueur.

const FX_DURATION := 0.35
const MAX_QUEUE := 400

var data: GameData
var map: MapDef
var lives := 20
var alive := true
var monsters: Array[SimMonster] = []
var towers := {}  # index de case -> SimTower
var projectiles: Array[SimProjectile] = []
var clock := 0.0
var _queue: Array[Dictionary] = []  # {time, type, hp_mult, wave}
var _fx: Array[Dictionary] = []  # {pos, radius, ttl}
var _by_id := {}
var _next_id := 1
var _spawn_turn := 0


func _init(p_data: GameData, p_map: MapDef, p_lives: int) -> void:
	data = p_data
	map = p_map
	lives = p_lives


## Programme les monstres d'une vague, à la suite de ceux déjà prévus.
func queue_wave(wave: Dictionary, hp_mult: float) -> void:
	var t := maxf(clock, _last_wave_time()) + 0.5
	for group in wave["groups"]:
		for i in int(group["count"]):
			_queue.append({"time": t, "type": group["monster"], "hp_mult": hp_mult, "wave": true})
			t += float(group["interval"])
		t += 1.0


## Ajoute un monstre envoyé par un adversaire (mode versus).
func queue_monster(type: String, hp_mult: float) -> bool:
	if _queue.size() >= MAX_QUEUE:
		return false
	_queue.append({"time": clock + 0.3, "type": type, "hp_mult": hp_mult, "wave": false})
	return true


## Vrai tant que des monstres de vague restent à faire apparaître.
func spawns_pending() -> bool:
	for e in _queue:
		if e["wave"]:
			return true
	return false


func is_clear() -> bool:
	return _queue.is_empty() and monsters.is_empty()


func can_build(cell: int) -> bool:
	return alive and map.is_buildable(cell) and not towers.has(cell)


func add_tower(cell: int, type: String, owner: int, cost: int) -> SimTower:
	var t := SimTower.new()
	t.cell = cell
	t.type = type
	t.owner = owner
	t.invested = cost
	t.center = map.cell_center(cell)
	towers[cell] = t
	return t


## Plateau perdu ou abandonné : plus rien n'y bouge.
func eliminate() -> void:
	alive = false
	_queue.clear()
	projectiles.clear()
	monsters.clear()
	_by_id.clear()


## Avance la simulation de dt secondes.
## Renvoie les primes à créditer : [[propriétaire de la tourelle, or], ...]
func step(dt: float) -> Array:
	var rewards := []
	if not alive:
		return rewards
	clock += dt
	_spawn_due()
	_move_monsters(dt)
	if lives <= 0:
		eliminate()
		return rewards
	_fire_towers(dt)
	_move_projectiles(dt, rewards)
	_remove_dead()
	_age_fx(dt)
	return rewards


func snapshot() -> Dictionary:
	var mons := []
	for m in monsters:
		var hp := int(roundf(clampf(m.hp / m.max_hp, 0.0, 1.0) * 255.0))
		mons.append([m.id, m.type_index, m.path, snappedf(m.progress, 0.01), hp, m.slow_timer > 0.0])
	var tws := []
	for cell in towers:
		var t: SimTower = towers[cell]
		tws.append([t.cell, data.tower_order.find(t.type), t.level, t.owner, t.target_mode])
	var prs := []
	for p in projectiles:
		prs.append([p.id, snappedf(p.pos.x, 0.01), snappedf(p.pos.y, 0.01)])
	var fx := []
	for f in _fx:
		var pos: Vector2 = f["pos"]
		fx.append([snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), f["radius"], snappedf(f["ttl"] / FX_DURATION, 0.01)])
	return {"lives": lives, "alive": alive, "m": mons, "t": tws, "p": prs, "fx": fx}


func _last_wave_time() -> float:
	var t := 0.0
	for e in _queue:
		if e["wave"]:
			t = maxf(t, e["time"])
	return t


func _spawn_due() -> void:
	var i := 0
	while i < _queue.size():
		if _queue[i]["time"] <= clock:
			_spawn(_queue[i]["type"], _queue[i]["hp_mult"])
			_queue.remove_at(i)
		else:
			i += 1


func _spawn(type: String, hp_mult: float) -> void:
	var def: Dictionary = data.monsters[type]
	var m := SimMonster.new()
	m.id = _new_id()
	m.type = type
	m.type_index = data.monster_order.find(type)
	m.max_hp = float(def["hp"]) * hp_mult
	m.hp = m.max_hp
	m.speed = def["speed"]
	m.gold = def["gold"]
	m.damage = def["damage"]
	m.flying = def["flying"]
	m.path = _spawn_turn % map.start_count()
	_spawn_turn += 1
	m.length = map.path_length(m.path, m.flying)
	m.pos = map.position_at(m.path, 0.0, m.flying)
	monsters.append(m)
	_by_id[m.id] = m


func _move_monsters(dt: float) -> void:
	for m in monsters:
		if not m.is_alive():
			continue
		m.move(dt)
		if m.reached_end():
			m.hp = 0.0  # le monstre quitte la carte, sans prime
			lives = maxi(0, lives - m.damage)
		else:
			m.pos = map.position_at(m.path, m.progress, m.flying)


func _fire_towers(dt: float) -> void:
	for cell in towers:
		var t: SimTower = towers[cell]
		t.cooldown -= dt
		if t.cooldown > 0.0:
			continue
		var def: Dictionary = data.towers[t.type]
		var stats: Dictionary = def["levels"][t.level]
		var target := _find_target(t, def, stats["range"])
		if target == null:
			t.cooldown = 0.0
			continue
		t.cooldown += 1.0 / float(stats["rate"])
		_launch(t, def, stats, target)


func _find_target(t: SimTower, def: Dictionary, reach: float) -> SimMonster:
	var best: SimMonster = null
	var best_score := -INF
	var r2 := reach * reach
	for m in monsters:
		if not m.is_alive():
			continue
		if (m.flying and not def["air"]) or (not m.flying and not def["ground"]):
			continue
		var d2 := t.center.distance_squared_to(m.pos)
		if d2 > r2:
			continue
		var score := m.ratio()
		if t.target_mode == SimTower.Target.STRONGEST:
			score = m.hp
		elif t.target_mode == SimTower.Target.CLOSEST:
			score = -d2
		if score > best_score:
			best_score = score
			best = m
	return best


func _launch(t: SimTower, def: Dictionary, stats: Dictionary, target: SimMonster) -> void:
	var p := SimProjectile.new()
	p.id = _new_id()
	p.pos = t.center
	p.target_id = target.id
	p.target_pos = target.pos
	p.speed = stats["projectile_speed"]
	p.damage = stats["damage"]
	p.splash = stats["splash"]
	p.slow_factor = stats["slow_factor"]
	p.slow_duration = stats["slow_duration"]
	p.owner = t.owner
	p.hits_air = def["air"]
	p.hits_ground = def["ground"]
	projectiles.append(p)


func _move_projectiles(dt: float, rewards: Array) -> void:
	var keep: Array[SimProjectile] = []
	for p in projectiles:
		var target: SimMonster = _by_id.get(p.target_id)
		if target != null and target.is_alive():
			p.target_pos = target.pos
		var reach := p.speed * dt
		if p.pos.distance_to(p.target_pos) > reach:
			p.pos = p.pos.move_toward(p.target_pos, reach)
			keep.append(p)
			continue
		p.pos = p.target_pos
		_impact(p, target, rewards)
	projectiles = keep


func _impact(p: SimProjectile, target: SimMonster, rewards: Array) -> void:
	if p.splash > 0.0:
		_fx.append({"pos": p.pos, "radius": p.splash, "ttl": FX_DURATION})
		var r2 := p.splash * p.splash
		for m in monsters:
			if m.is_alive() and _can_hit(p, m) and m.pos.distance_squared_to(p.pos) <= r2:
				_hurt(m, p, rewards)
	elif target != null and target.is_alive():
		_hurt(target, p, rewards)


func _can_hit(p: SimProjectile, m: SimMonster) -> bool:
	return p.hits_air if m.flying else p.hits_ground


func _hurt(m: SimMonster, p: SimProjectile, rewards: Array) -> void:
	m.hp -= p.damage
	m.apply_slow(p.slow_factor, p.slow_duration)
	if m.hp <= 0.0:
		m.hp = 0.0
		rewards.append([p.owner, m.gold])


func _remove_dead() -> void:
	var keep: Array[SimMonster] = []
	for m in monsters:
		if m.is_alive():
			keep.append(m)
		else:
			_by_id.erase(m.id)
	monsters = keep


func _age_fx(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for f in _fx:
		f["ttl"] -= dt
		if f["ttl"] > 0.0:
			keep.append(f)
	_fx = keep


func _new_id() -> int:
	_next_id += 1
	return _next_id

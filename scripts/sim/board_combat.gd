class_name BoardCombat
extends RefCounted
## Combat d'un plateau : effets continus (régénération, soins, poison), tirs des tourelles,
## projectiles, zone, arc électrique en chaîne et armure.

## L'armure retire des dégâts fixes, mais chaque coup garde au moins 25 % de sa force.
const ARMOR_MIN_RATIO := 0.25
const CHAIN_RANGE := 1.8
const CHAIN_FALLOFF := 0.8


## Régénération, soins des chamans, dégâts du poison (qui ignore l'armure).
static func update_effects(b: SimBoard, dt: float, rewards: Array) -> void:
	for m in b.monsters:
		if not m.is_alive():
			continue
		if m.regen > 0.0:
			m.hp = minf(m.max_hp, m.hp + m.regen * dt)
		if m.poison_timer > 0.0:
			m.poison_timer = maxf(0.0, m.poison_timer - dt)
			damage(b, m, m.poison_dps * dt, true, m.poison_owner, rewards)
	for healer in b.monsters:
		if not healer.is_alive() or healer.heal_rate <= 0.0:
			continue
		var r2 := healer.heal_radius * healer.heal_radius
		for m in b.monsters:
			if m != healer and m.is_alive() and m.hp < m.max_hp and m.pos.distance_squared_to(healer.pos) <= r2:
				m.hp = minf(m.max_hp, m.hp + healer.heal_rate * dt)


static func fire_towers(b: SimBoard, dt: float) -> void:
	for cell in b.towers:
		var t: SimTower = b.towers[cell]
		t.cooldown -= dt
		if t.cooldown > 0.0:
			continue
		var def: Dictionary = b.data.towers[t.type]
		var target := find_target(b, t, def)
		if target == null:
			t.cooldown = 0.0
			continue
		t.cooldown += 1.0 / float(t.stats["rate"])
		_launch(b, t, def, target)


static func find_target(b: SimBoard, t: SimTower, def: Dictionary) -> SimMonster:
	var best: SimMonster = null
	var best_score := -INF
	var reach: float = t.stats["range"]
	var r2 := reach * reach
	for m in b.monsters:
		if not m.is_alive() or not _can_target(def["air"], def["ground"], m):
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


static func move_projectiles(b: SimBoard, dt: float, rewards: Array) -> void:
	var keep: Array[SimProjectile] = []
	for p in b.projectiles:
		var target := b.monster_by_id(p.target_id)
		if target != null and target.is_alive():
			p.target_pos = target.pos
		var reach := p.speed * dt
		if p.pos.distance_to(p.target_pos) > reach:
			p.pos = p.pos.move_toward(p.target_pos, reach)
			keep.append(p)
			continue
		p.pos = p.target_pos
		_impact(b, p, target, rewards)
	b.projectiles = keep


## Inflige des dégâts ; pierce : ignore l'armure (poison). Gère la mort et la prime.
static func damage(b: SimBoard, m: SimMonster, amount: float, pierce: bool, owner: int, rewards: Array) -> void:
	if not m.is_alive() or amount <= 0.0:
		return
	if not pierce and m.armor > 0.0:
		amount = maxf(amount - m.armor, amount * ARMOR_MIN_RATIO)
	m.hp -= amount
	if m.hp <= 0.0:
		m.hp = 0.0
		b.kill(m, owner, rewards)


static func _launch(b: SimBoard, t: SimTower, def: Dictionary, target: SimMonster) -> void:
	var s := t.stats
	var p := SimProjectile.new()
	p.id = b.new_id()
	p.pos = t.center
	p.target_id = target.id
	p.target_pos = target.pos
	p.speed = s["projectile_speed"]
	p.damage = s["damage"]
	p.splash = s["splash"]
	p.slow_factor = s["slow_factor"]
	p.slow_duration = s["slow_duration"]
	p.chain = s["chain"]
	p.poison_dps = s["poison_dps"]
	p.poison_duration = s["poison_duration"]
	p.owner = t.owner
	p.hits_air = def["air"]
	p.hits_ground = def["ground"]
	b.projectiles.append(p)


static func _impact(b: SimBoard, p: SimProjectile, target: SimMonster, rewards: Array) -> void:
	if p.splash > 0.0:
		b.add_fx(SimBoard.Fx.RING, p.pos, Vector2.ZERO, p.splash)
		var r2 := p.splash * p.splash
		for m in b.monsters:
			if m.is_alive() and _can_target(p.hits_air, p.hits_ground, m) and m.pos.distance_squared_to(p.pos) <= r2:
				_hit(b, m, p, p.damage, rewards)
	elif target != null and target.is_alive():
		_hit(b, target, p, p.damage, rewards)
		if p.chain > 0:
			_chain(b, p, target, rewards)


## Arc électrique : rebondit vers le monstre le plus proche non encore touché.
static func _chain(b: SimBoard, p: SimProjectile, first: SimMonster, rewards: Array) -> void:
	var touched := {first.id: true}
	var current_pos := first.pos
	var dmg := p.damage
	for k in p.chain:
		dmg *= CHAIN_FALLOFF
		var next: SimMonster = null
		var best := CHAIN_RANGE * CHAIN_RANGE
		for m in b.monsters:
			if m.is_alive() and not touched.has(m.id) and _can_target(p.hits_air, p.hits_ground, m):
				var d2 := m.pos.distance_squared_to(current_pos)
				if d2 <= best:
					best = d2
					next = m
		if next == null:
			return
		touched[next.id] = true
		b.add_fx(SimBoard.Fx.BOLT, current_pos, next.pos)
		_hit(b, next, p, dmg, rewards)
		current_pos = next.pos


static func _hit(b: SimBoard, m: SimMonster, p: SimProjectile, amount: float, rewards: Array) -> void:
	m.apply_slow(p.slow_factor, p.slow_duration)
	m.apply_poison(p.poison_dps, p.poison_duration, p.owner)
	damage(b, m, amount, false, p.owner, rewards)


static func _can_target(air: bool, ground: bool, m: SimMonster) -> bool:
	return air if m.flying else ground

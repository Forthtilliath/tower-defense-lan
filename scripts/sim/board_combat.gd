class_name BoardCombat
extends RefCounted
## Combat d'un plateau : tirs des tourelles (auras comprises), projectiles, zone, arc électrique
## en chaîne, effets à l'impact (ralentissement, poison, brûlure, saignement, contrôles), armure,
## et crédit des dégâts et contrôles pour le partage des primes.
## Les effets continus sont dans MonsterEffects, les auras dans BoardAuras.

## L'armure retire des dégâts fixes, mais chaque coup garde au moins 25 % de sa force.
const ARMOR_MIN_RATIO := 0.25
const CHAIN_RANGE := 1.8
const CHAIN_FALLOFF := 0.8
const CONTROLS := {"stun": SimMonster.Crowd.STUN, "fear": SimMonster.Crowd.FEAR, "charm": SimMonster.Crowd.CHARM}


static func solo(owner: int) -> Array:
	return [[owner, 1.0]]


static func fire_towers(b: SimBoard, dt: float) -> void:
	for cell in b.towers:
		var t: SimTower = b.towers[cell]
		if t.support:
			continue
		t.cooldown -= dt
		if t.cooldown > 0.0:
			continue
		var def: Dictionary = b.data.towers[t.type]
		var target := find_target(b, t, def)
		if target == null:
			t.cooldown = 0.0
			continue
		t.cooldown += BoardAuras.fire_delay(t)
		_launch(b, t, def, target)


static func find_target(b: SimBoard, t: SimTower, def: Dictionary) -> SimMonster:
	var best: SimMonster = null
	var best_score := -INF
	var reach: float = t.stats["range"]
	var r2 := reach * reach
	for m in b.monsters:
		if not m.is_alive() or m.is_charmed() or not _can_target(def["air"], def["ground"], m):
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


## Inflige des dégâts ; pierce : ignore l'armure (effets continus). Crédite les joueurs
## (dégâts réellement retirés), gère la mort et le partage de la prime.
static func damage(b: SimBoard, m: SimMonster, amount: float, pierce: bool, credit: Array, rewards: Array) -> void:
	if not m.is_alive() or amount <= 0.0:
		return
	if not pierce and m.armor > 0.0:
		amount = maxf(amount - m.armor, amount * ARMOR_MIN_RATIO)
	m.add_contrib(credit, minf(amount, m.hp))
	m.hp -= amount
	if m.hp <= 0.0:
		m.hp = 0.0
		b.kill(m, int(credit[0][0]) if not credit.is_empty() else 0, rewards)


static func _launch(b: SimBoard, t: SimTower, def: Dictionary, target: SimMonster) -> void:
	var p := SimProjectile.new()
	p.id = b.new_id()
	p.pos = t.center
	p.target_id = target.id
	p.target_pos = target.pos
	p.stats = BoardAuras.effective_stats(t)
	p.speed = p.stats["projectile_speed"]
	p.credit = BoardAuras.credit(t)
	p.owner = t.owner
	p.hits_air = def["air"]
	p.hits_ground = def["ground"]
	b.projectiles.append(p)


static func _impact(b: SimBoard, p: SimProjectile, target: SimMonster, rewards: Array) -> void:
	var splash := p.stat("splash")
	if splash > 0.0:
		b.add_fx(SimBoard.Fx.RING, p.pos, Vector2.ZERO, splash)
		var r2 := splash * splash
		for m in b.monsters:
			if m.is_alive() and not m.is_charmed() and _can_target(p.hits_air, p.hits_ground, m) and m.pos.distance_squared_to(p.pos) <= r2:
				_hit(b, m, p, p.stat("damage"), rewards)
	elif target != null and target.is_alive():
		_hit(b, target, p, p.stat("damage"), rewards)
		if p.stat("chain") > 0:
			_chain(b, p, target, rewards)


## Arc électrique : rebondit vers le monstre le plus proche non encore touché.
static func _chain(b: SimBoard, p: SimProjectile, first: SimMonster, rewards: Array) -> void:
	var touched := {first.id: true}
	var current_pos := first.pos
	var dmg := p.stat("damage")
	for k in int(p.stat("chain")):
		dmg *= CHAIN_FALLOFF
		var next: SimMonster = null
		var best := CHAIN_RANGE * CHAIN_RANGE
		for m in b.monsters:
			if m.is_alive() and not m.is_charmed() and not touched.has(m.id) and _can_target(p.hits_air, p.hits_ground, m):
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


## Un coup : effets, contrôles (tirés au hasard selon leur chance), puis dégâts.
static func _hit(b: SimBoard, m: SimMonster, p: SimProjectile, amount: float, rewards: Array) -> void:
	var slowed := m.apply_slow(p.stat("slow_factor") if p.stats.has("slow_factor") else 1.0, p.stat("slow_duration"))
	m.add_contrib(p.credit, slowed * (1.0 - p.stat("slow_factor")) * m.max_hp * SimMonster.SLOW_POINTS)
	m.apply_poison(p.stat("poison_dps"), p.stat("poison_duration"), p.owner)
	m.apply_burn(p.stat("burn_dps"), p.stat("burn_duration"), int(p.stat("burn_stacks")), p.owner)
	m.apply_bleed(p.stat("bleed"), p.stat("bleed_duration"), p.owner)
	for kind in CONTROLS:
		var chance := p.stat(kind + "_chance")
		if chance > 0.0 and b.rng.randf() < chance:
			var applied := m.apply_control(CONTROLS[kind], p.stat(kind + "_duration"), p.owner)
			m.add_contrib(p.credit, applied * m.max_hp * SimMonster.CONTROL_POINTS)
	damage(b, m, amount, false, p.credit, rewards)


static func _can_target(air: bool, ground: bool, m: SimMonster) -> bool:
	return air if m.flying else ground

class_name BoardCombat
extends RefCounted
## Combat d'un plateau : tirs des tourelles (auras comprises), projectiles, zone, arc électrique
## en chaîne, effets à l'impact (ralentissement, poison, brûlure, saignement, armure rongée,
## contrôles), armure, et crédit des dégâts et contrôles pour le partage des primes.
## Les tirs instantanés (onde, trait, souffle, rayon) sont dans BoardAttacks, les nappes au sol
## dans BoardPatches, les effets continus dans MonsterEffects, les auras dans BoardAuras.

## L'armure retire des dégâts fixes, mais chaque coup garde au moins 25 % de sa force.
const ARMOR_MIN_RATIO := 0.25
const CHAIN_RANGE := 1.8
const CHAIN_FALLOFF := 0.8
const CONTROLS := {"stun": SimMonster.Crowd.STUN, "fear": SimMonster.Crowd.FEAR, "charm": SimMonster.Crowd.CHARM}


static func solo(owner: int) -> Array:
	return [[owner, 1.0]]


static func fire_towers(b: SimBoard, dt: float, rewards: Array) -> void:
	for cell in b.towers:
		var t: SimTower = b.towers[cell]
		if t.support:
			continue
		if t.is_jammed():  # brouillée : elle lâche sa cible et attend
			t.beam_target = 0
			continue
		t.cooldown -= dt
		if t.cooldown > 0.0:
			continue
		var def: Dictionary = b.data.towers[t.type]
		var target := find_target(b, t, def)
		if target == null:
			t.cooldown = 0.0
			t.beam_target = 0
			continue
		t.cooldown += BoardAuras.fire_delay(t)
		if def["attack"] != "shot":
			BoardAttacks.fire(b, t, def, target, rewards)
			continue
		_launch(b, t, def, target)
		var skip := {target.id: true}
		for k in int(t.stats["multishot"]) - 1:  # tir multiple : les cibles suivantes
			var next := find_target(b, t, def, skip)
			if next == null:
				break
			skip[next.id] = true
			_launch(b, t, def, next)


## Meilleure cible à portée selon le mode de visée (en dehors des monstres de `skip`).
static func find_target(b: SimBoard, t: SimTower, def: Dictionary, skip := {}) -> SimMonster:
	var best: SimMonster = null
	var best_score := -INF
	var reach := BoardAuras.reach(t)
	var r2 := reach * reach
	for m in b.monsters:
		if skip.has(m.id) or not can_hit(def["air"], def["ground"], m) or t.center.distance_squared_to(m.pos) > r2 \
				or m.taken(def["element"]) <= 0.0:  # insensible à ses coups (fantôme, squelette…)
			continue
		var score := m.ratio()
		if t.target_mode == SimTower.Target.STRONGEST:
			score = m.hp
		elif t.target_mode == SimTower.Target.CLOSEST:
			score = -t.center.distance_squared_to(m.pos)
		if score > best_score:
			best_score = score
			best = m
	return best


## Un coup de la tourelle : statistiques du moment (auras comprises) et crédit.
## Un tir sur crit_every est critique.
static func shot(b: SimBoard, t: SimTower, def: Dictionary) -> SimProjectile:
	var p := SimProjectile.new()
	p.pos = t.center
	p.stats = BoardAuras.effective_stats(t)
	p.speed = p.stats["projectile_speed"]
	p.credit = BoardAuras.credit(t)
	p.owner = t.owner
	p.frost_owner = int(t.buffs["frostbite"][1]) if t.buffs.has("frostbite") else t.owner
	p.kind = b.data.tower_order.find(t.type)
	p.element = def["element"]
	p.hits_air = def["air"]
	p.hits_ground = def["ground"]
	t.shots += 1
	var every := int(p.stat("crit_every"))
	if every > 0 and t.shots % every == 0:
		p.stats["damage"] *= p.stat("crit_mult")
	return p


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


## Inflige des dégâts ; pierce : ignore l'armure (effets continus) ; sinon armor_pierce est la
## part d'armure ignorée (l'armure rongée compte aussi). Un monstre électrifié en subit une part
## de plus, puis la protection d'un monstre voisin (ward) retire sa part. Crédite les joueurs
## (dégâts réellement retirés), gère la mort et le partage de la prime.
static func damage(b: SimBoard, m: SimMonster, amount: float, pierce: bool, credit: Array, rewards: Array, armor_pierce := 0.0) -> void:
	if not m.is_alive() or amount <= 0.0:
		return
	if not pierce:
		var armor := m.armor_against(armor_pierce)
		if armor > 0.0:
			amount = maxf(amount - armor, amount * ARMOR_MIN_RATIO)
	amount *= (1.0 + m.marks.vulnerability()) * (1.0 - m.warded)
	m.add_contrib(credit, minf(amount, m.hp))
	m.hp -= amount
	if m.hp <= 0.0:
		m.hp = 0.0
		b.kill(m, int(credit[0][0]) if not credit.is_empty() else 0, rewards)


static func _launch(b: SimBoard, t: SimTower, def: Dictionary, target: SimMonster) -> void:
	var p := shot(b, t, def)
	p.id = b.new_id()
	p.target_id = target.id
	p.target_pos = target.pos
	b.projectiles.append(p)


static func _impact(b: SimBoard, p: SimProjectile, target: SimMonster, rewards: Array) -> void:
	var splash := p.stat("splash")
	if p.stat("patch_radius") > 0.0:
		BoardPatches.add(b, p)
	if splash > 0.0:
		b.add_fx(SimBoard.Fx.RING, p.pos, Vector2.ZERO, splash)
		for m in in_radius(b, p, p.pos, splash):
			hit(b, m, p, p.stat("damage"), rewards)
	elif target != null and target.is_alive():
		hit(b, target, p, p.stat("damage"), rewards)
		if p.stat("chain") > 0:
			_chain(b, p, target, rewards)


## Monstres visables par le coup p (ni charmés, ni hors de sa portée air/sol) dans un disque.
static func in_radius(b: SimBoard, p: SimProjectile, at: Vector2, radius: float) -> Array[SimMonster]:
	var out: Array[SimMonster] = []
	var r2 := radius * radius
	for m in b.monsters:
		if can_hit(p.hits_air, p.hits_ground, m) and m.pos.distance_squared_to(at) <= r2:
			out.append(m)
	return out


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
			if not touched.has(m.id) and can_hit(p.hits_air, p.hits_ground, m):
				var d2 := m.pos.distance_squared_to(current_pos)
				if d2 <= best:
					best = d2
					next = m
		if next == null:
			return
		touched[next.id] = true
		b.add_fx(SimBoard.Fx.BOLT, current_pos, next.pos)
		hit(b, next, p, dmg, rewards)
		current_pos = next.pos


## Un coup : bonus contre un monstre ralenti ou gelé (avant les effets du coup), effets,
## contrôles, puis dégâts (réduits si le monstre résiste à l'élément de la tourelle).
static func hit(b: SimBoard, m: SimMonster, p: SimProjectile, amount: float, rewards: Array) -> void:
	if m.is_stunned():
		amount *= 1.0 + p.stat("vs_stunned")
	elif m.is_slowed():
		amount *= 1.0 + p.stat("vs_slowed")
	afflict(b, m, p)
	damage(b, m, amount * m.taken(p.element), false, p.credit, rewards, p.stat("armor_pierce"))


## Effets d'un coup sans ses dégâts directs : ralentissement (affaibli par la résistance à
## l'élément du tir), poison, brûlure, saignement, armure rongée, et contrôles (tirés au
## hasard selon leur chance).
static func afflict(b: SimBoard, m: SimMonster, p: SimProjectile) -> void:
	var factor := p.stat("slow_factor") if p.stats.has("slow_factor") else 1.0
	factor = 1.0 - (1.0 - factor) * m.taken(p.element)
	var slowed := m.apply_slow(factor, p.stat("slow_duration"))
	m.add_contrib(p.credit, slowed * (1.0 - factor) * m.max_hp * SimMonster.SLOW_POINTS)
	m.apply_poison(p.stat("poison_dps"), p.stat("poison_duration"), p.owner, p.stat("poison_spread"), int(p.stat("poison_stacks")))
	m.apply_burn(p.stat("burn_dps"), p.stat("burn_duration"), int(p.stat("burn_stacks")), p.owner)
	m.apply_bleed(p.stat("bleed"), p.stat("bleed_duration"), p.owner, int(p.stat("bleed_stacks")))
	m.apply_shred(p.stat("shred"), p.stat("shred_duration"))
	_mark(m, p)
	for kind in CONTROLS:
		var chance := p.stat(kind + "_chance")
		if chance > 0.0 and b.rng.randf() < chance:
			var applied := m.apply_control(CONTROLS[kind], p.stat(kind + "_duration"), p.owner)
			m.add_contrib(p.credit, applied * m.max_hp * SimMonster.CONTROL_POINTS)


## États des spécialisations : gelure et électrifié (apportés par les tourelles d'imprégnation,
## réduits par la résistance au gel ou à la foudre ; un véhicule ne gèle pas), soins coupés,
## volant cloué au sol (moins longtemps pour un boss).
static func _mark(m: SimMonster, p: SimProjectile) -> void:
	if p.stat("frostbite_dps") > 0.0 and not m.mechanical:
		m.marks.apply_frostbite(p.stat("frostbite_dps") * m.taken("ice"), p.frost_owner)
	m.marks.apply_shock(p.stat("shock") * m.taken("lightning"))
	m.marks.apply_heal_block(p.stat("heal_block"), p.stat("heal_block_duration"))
	if m.flying and p.stat("ground_duration") > 0.0:
		m.marks.ground(p.stat("ground_duration") * (1.0 - m.cc_resist))


## Monstre vivant, non charmé, que la tourelle sait viser : un volant par les tourelles qui visent
## l'air (et par toutes s'il est cloué au sol), un monstre au sol par celles qui visent le sol.
static func can_hit(air: bool, ground: bool, m: SimMonster) -> bool:
	if not m.is_alive() or m.is_charmed():
		return false
	return (air or m.marks.is_grounded()) if m.flying else ground

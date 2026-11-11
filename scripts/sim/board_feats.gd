class_name BoardFeats
extends RefCounted
## Effets des talents sur les tirs et les coups (statistiques de DataSchema.FEATS, nulles sur les
## tourelles de base) : série, échauffement, coup critique, gros monstres, réactions entre
## éléments, résonance, marque, armure brisée, recul, exécution, perforation, ricochet, et, à la
## mort d'un monstre, onde, éclats et contagion des effets.

const MARK_DURATION := 3.0
## Gros monstre (vs_big) : au moins ces PV max, ou un boss (qui résiste aux contrôles).
const BIG_HP := 500.0
## Rayon autour d'un monstre pour la perforation, l'onde à la mort, les éclats et la contagion.
const NEAR := 1.2
const RICOCHET_RANGE := 1.8
const KNOCKBACK := 0.5
const SHARDS := 3
## Réactions : explosion de la foudre sur un monstre qui brûle, étourdissement de la glace.
const BLAST_RADIUS := 1.0
const REACTION_STUN := 0.3
const SPREAD_DURATION := 3.0
const SPREADS := ["burn", "poison", "shock"]


## Au tir : la tourelle signe le coup ; série : +streak par monstre tué depuis que la carte était vide.
static func on_shot(t: SimTower, p: SimProjectile) -> void:
	p.cell = t.cell
	var s := p.stat("streak")
	if s > 0.0 and t.kills > 0:
		GameData.scale_damage(p.stats, 1.0 + minf(p.stat("streak_cap"), s * t.kills))


## Délai jusqu'au tir suivant, échauffement compris (+warmup de cadence par seconde de tir continu).
static func next_delay(t: SimTower, base: float) -> float:
	var w := float(t.stats.get("warmup", 0.0))
	var delay := base
	if w > 0.0:
		delay = base / (1.0 + minf(float(t.stats["warmup_cap"]), w * t.warm))
	t.warm += delay
	return delay


## Carte vide : les séries repartent de zéro.
static func reset_streaks(b: SimBoard) -> void:
	if b.monsters.is_empty():
		for cell in b.towers:
			b.towers[cell].kills = 0


static func is_big(m: SimMonster) -> bool:
	return m.max_hp >= BIG_HP or m.cc_resist > 0.0


## Part des dégâts subie, résonance comprise (elle n'ouvre pas une insensibilité totale).
static func taken(m: SimMonster, p: SimProjectile) -> float:
	var t := m.taken(p.element)
	var r := p.stat("resonance")
	return t + (1.0 - t) * r if t > 0.0 and r > 0.0 and DataSchema.ELEMENTS.has(p.element) else t


## Dégâts d'un coup : critique, gros monstre, feu sur un monstre ralenti ou gelé.
static func scale_hit(b: SimBoard, m: SimMonster, p: SimProjectile, amount: float) -> float:
	var crit := p.stat("crit_chance")
	if crit > 0.0 and b.rng.randf() < crit:
		amount *= 2.0 + p.stat("crit_bonus")
	if p.stat("vs_big") > 0.0 and is_big(m):
		amount *= 1.0 + p.stat("vs_big")
	if p.stat("reaction") > 0.0 and p.element == "fire" and (m.is_slowed() or m.is_stunned()):
		amount *= 1.0 + p.stat("reaction")
	return amount


## États posés par le coup avant ses dégâts : marque, armure brisée, contagion à la mort.
static func mark(m: SimMonster, p: SimProjectile) -> void:
	m.marks.apply_mark(p.stat("mark"), MARK_DURATION)
	if int(p.stat("armor_break")) > 0:
		m.marks.break_armor(int(p.stat("armor_break")))
	for kind in SPREADS:
		if int(p.stat("death_" + kind)) > 0:
			m.marks.spread_on_death(kind, int(p.stat("death_" + kind)))


## Après les dégâts d'un coup : réactions de la foudre et de la glace sur un monstre qui brûle,
## recul, exécution ; si le coup a tué : série de la tourelle, onde et éclats.
static func after_hit(b: SimBoard, m: SimMonster, p: SimProjectile, amount: float, rewards: Array) -> void:
	var reaction := p.stat("reaction")
	if reaction > 0.0 and m.is_burning():
		if p.element == "lightning":
			b.add_fx(SimBoard.Fx.RING, m.pos, Vector2.ZERO, BLAST_RADIUS)
			for o in near(b, m, BLAST_RADIUS, 99):
				BoardCombat.damage(b, o, amount * reaction, false, p.credit, rewards)
		elif p.element == "ice" and m.is_alive():
			m.apply_control(SimMonster.Crowd.STUN, REACTION_STUN * reaction, p.owner)
	if m.is_alive():
		if p.stat("knockback") > 0.0 and m.cc_resist < 0.5 and b.rng.randf() < p.stat("knockback"):
			m.progress = maxf(0.0, m.progress - KNOCKBACK * (1.0 - m.cc_resist))
		var e := p.stat("execute") * (0.5 if is_big(m) else 1.0)
		if e > 0.0 and m.hp < m.max_hp * e:
			BoardCombat.damage(b, m, m.hp, true, p.credit, rewards)
	if m.is_alive():
		return
	var t: SimTower = b.towers.get(p.cell)
	if t != null:
		t.kills += 1
	if p.stat("kill_splash") > 0.0:
		b.add_fx(SimBoard.Fx.RING, m.pos, Vector2.ZERO, NEAR)
		for o in near(b, m, NEAR, 99):
			BoardCombat.damage(b, o, amount * p.stat("kill_splash"), false, p.credit, rewards)
	if p.stat("frag") > 0.0:
		for o in near(b, m, NEAR, SHARDS):
			b.add_fx(SimBoard.Fx.BOLT, m.pos, o.pos)
			BoardCombat.damage(b, o, amount * p.stat("frag"), false, p.credit, rewards)


## Coups en plus d'un projectile qui a touché sa cible : perforation (les monstres juste derrière),
## ricochet (un monstre voisin, selon sa chance).
static func extra_targets(b: SimBoard, p: SimProjectile, target: SimMonster, amount: float, rewards: Array) -> void:
	var others := near(b, target, NEAR, int(p.stat("pierce")), p)
	if p.stat("ricochet") > 0.0 and b.rng.randf() < p.stat("ricochet"):
		for o in near(b, target, RICOCHET_RANGE, 1, p):
			if not others.has(o):
				others.append(o)
				b.add_fx(SimBoard.Fx.BOLT, target.pos, o.pos)
	for o in others:
		BoardCombat.hit(b, o, p, amount, rewards)


## Mort d'un monstre : il transmet brûlure, poison ou électrifié à ses voisins (talents de contagion).
static func on_death(b: SimBoard, m: SimMonster) -> void:
	for kind in m.marks.death_spread:
		var count := int(m.marks.death_spread[kind])
		if (kind == "burn" and not m.is_burning()) or (kind == "poison" and not m.is_poisoned()) \
				or (kind == "shock" and not m.marks.is_shocked()):
			continue
		for o in near(b, m, NEAR, count):
			b.add_fx(SimBoard.Fx.SPREAD, m.pos, o.pos)
			match kind:
				"burn":
					o.apply_burn(m.burn_dps, SPREAD_DURATION, m.burn_stacks, m.burn_owner)
				"poison":
					o.apply_poison(m.poison_dps, SPREAD_DURATION, m.poison_owner, m.poison_spread, m.poison_stacks)
				"shock":
					o.marks.apply_shock(m.marks.shock)
			o.marks.spread_on_death(kind, count)


## Jusqu'à `count` monstres vivants les plus proches de m (lui exclu) dans le rayon ; avec un coup
## p, seulement ceux qu'il sait viser.
static func near(b: SimBoard, m: SimMonster, radius: float, count: int, p: SimProjectile = null) -> Array[SimMonster]:
	var found: Array[SimMonster] = []
	if count <= 0:
		return found
	var r2 := radius * radius
	for o in b.monsters:
		if o != m and o.is_alive() and o.pos.distance_squared_to(m.pos) <= r2 \
				and (p == null or BoardCombat.can_hit(p.hits_air, p.hits_ground, o)):
			found.append(o)
	found.sort_custom(func(x: SimMonster, y: SimMonster) -> bool:
		return x.pos.distance_squared_to(m.pos) < y.pos.distance_squared_to(m.pos))
	return found.slice(0, count)

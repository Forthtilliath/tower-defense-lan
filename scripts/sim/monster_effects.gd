class_name MonsterEffects
extends RefCounted
## Effets continus sur les monstres : régénération, soins des chamans, poison, brûlure,
## saignement (dégâts qui ignorent l'armure), et coups portés par les monstres charmés.

## Les boss (cc_resist) ne subissent qu'une partie du saignement.
const BLEED_RESIST := 0.5
## Un monstre charmé frappe le monstre le plus proche à portée : part de ses PV max par seconde.
const CHARM_DPS := 0.2
const CHARM_REACH := 0.8


static func update(b: SimBoard, dt: float, rewards: Array) -> void:
	for m in b.monsters:
		if not m.is_alive():
			continue
		if m.regen > 0.0:
			m.hp = minf(m.max_hp, m.hp + m.regen * dt)
		_damage_over_time(b, m, dt, rewards)
	_heal(b, dt)
	_charmed_attacks(b, dt, rewards)


static func _damage_over_time(b: SimBoard, m: SimMonster, dt: float, rewards: Array) -> void:
	if m.poison_timer > 0.0:
		m.poison_timer = maxf(0.0, m.poison_timer - dt)
		BoardCombat.damage(b, m, m.poison_dps * dt, true, BoardCombat.solo(m.poison_owner), rewards)
	if m.burn_timer > 0.0 and m.is_alive():
		m.burn_timer = maxf(0.0, m.burn_timer - dt)
		BoardCombat.damage(b, m, m.burn_dps * m.burn_stacks * dt, true, BoardCombat.solo(m.burn_owner), rewards)
	if m.bleed_timer > 0.0 and m.is_alive():
		m.bleed_timer = maxf(0.0, m.bleed_timer - dt)
		var rate := m.bleed_rate * (1.0 - m.cc_resist * BLEED_RESIST)
		BoardCombat.damage(b, m, m.max_hp * rate * dt, true, BoardCombat.solo(m.bleed_owner), rewards)


static func _heal(b: SimBoard, dt: float) -> void:
	for healer in b.monsters:
		if not healer.is_alive() or healer.heal_rate <= 0.0 or healer.is_charmed():
			continue
		var r2 := healer.heal_radius * healer.heal_radius
		for m in b.monsters:
			if m != healer and m.is_alive() and m.hp < m.max_hp and m.pos.distance_squared_to(healer.pos) <= r2:
				m.hp = minf(m.max_hp, m.hp + healer.heal_rate * dt)


## Chaque monstre charmé frappe le monstre non charmé le plus proche (au sol, à portée).
static func _charmed_attacks(b: SimBoard, dt: float, rewards: Array) -> void:
	for c in b.monsters:
		if not c.is_alive() or not c.is_charmed():
			continue
		var target: SimMonster = null
		var best := CHARM_REACH * CHARM_REACH
		for m in b.monsters:
			if m == c or not m.is_alive() or m.is_charmed() or m.flying:
				continue
			var d2 := m.pos.distance_squared_to(c.pos)
			if d2 <= best:
				best = d2
				target = m
		if target != null:
			# Coups continus : comptés hors armure, sinon de si petits coups seraient presque annulés
			BoardCombat.damage(b, target, c.max_hp * CHARM_DPS * dt, true, BoardCombat.solo(c.charm_owner), rewards)

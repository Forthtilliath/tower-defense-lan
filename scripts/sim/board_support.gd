class_name BoardSupport
extends RefCounted
## Talents du Support : auras reçues par les tourelles (critique, Garde rapprochée, Vétérans,
## Charge, Ralliement, Heures sup, étourdissement, Sanctuaire, Lumière, anti-aérien, Fanfare dans
## MonsterAbilities) et effets des coups sur les monstres (affaiblis, résistances réduites,
## maléfice, monstres de vague spéciale, contrôles répétés, peur contagieuse, charme renforcé).

const VETERAN_CAP := 0.3
const CHARGE_TIME := 5.0
const RUSH_TIME := 10.0
const RALLY_TIME := 8.0
## Garde rapprochée : monstres passés à cette part de la route ; Sanctuaire : sur le dernier quart.
const LATE := 0.5
const SANCTUARY := 0.75
const SANCTUARY_SLOW := 1.0
const AURA_STUN := 0.5


## Au tir : effets des auras du Support. Renvoie le multiplicateur de dégâts.
static func on_shot(b: SimBoard, t: SimTower, p: SimProjectile) -> float:
	if t.buffs.is_empty():
		return 1.0
	var mult := 1.0 + minf(VETERAN_CAP, t.buff("veteran") * t.kills_total)
	if b.clock - float(b.get_meta("leak_at", -INF)) < RALLY_TIME:
		mult *= 1.0 + t.buff("rally")
	if since_wave(b) < RUSH_TIME:
		mult *= 1.0 + t.buff("rush")
	p.stats["crit_chance"] = minf(1.0, p.stat("crit_chance") + t.buff("crit"))
	p.stats["vs_late"] = t.buff("late")
	p.stats["sanctuary"] = t.buff("sanct")
	p.stats["light"] = t.buff("light")
	if t.buff("stun") > 0.0:
		p.stats["stun_chance"] = minf(1.0, p.stat("stun_chance") + t.buff("stun"))
		p.stats["stun_duration"] = maxf(p.stat("stun_duration"), AURA_STUN)
	if t.buff("air") > 0.0:
		p.hits_air = true
	return mult


## Cadence en plus : Charge, les CHARGE_TIME s qui suivent le départ d'une vague.
static func rate_mult(b: SimBoard, t: SimTower) -> float:
	var charge := 1.0 + t.buff("charge") if since_wave(b) < CHARGE_TIME else 1.0
	return charge * MatchPowers.rate_mult(b, t)


static func since_wave(b: SimBoard) -> float:
	return b.clock - float(b.get_meta("wave_at", -INF))


## À chaque tir du plateau : retient l'instant de la dernière vie perdue (Ralliement).
static func track(b: SimBoard) -> void:
	if b.lives < int(b.get_meta("lives_seen", b.lives)):
		b.set_meta("leak_at", b.clock)
	b.set_meta("lives_seen", b.lives)


## Dégâts d'un coup : Garde rapprochée, monstres de vague spéciale.
static func scale_hit(m: SimMonster, p: SimProjectile, amount: float) -> float:
	if p.stat("vs_late") > 0.0 and m.ratio() > LATE:
		amount *= 1.0 + p.stat("vs_late")
	if p.stat("vs_elite") > 0.0 and m.is_elite():
		amount *= 1.0 + p.stat("vs_elite")
	return amount


## États posés par un coup : affaibli, résistances réduites, maléfice, charme renforcé.
static func mark(m: SimMonster, p: SimProjectile, duration: float) -> void:
	if p.stat("weaken") > 0.0:
		m.marks.weakened = true
	m.marks.apply_resist_down(p.stat("resist_down"), duration)
	m.marks.apply_hex(p.stat("hex"), duration)
	if p.stat("charm_power") > 0.0 and m.is_charmed():
		m.marks.charm_power = maxf(m.marks.charm_power, p.stat("charm_power"))


## Après un coup : Sanctuaire (ralentit sur le dernier quart de la route), peur contagieuse.
static func after_hit(b: SimBoard, m: SimMonster, p: SimProjectile) -> void:
	if not m.is_alive():
		return
	if p.stat("sanctuary") > 0.0 and m.ratio() > SANCTUARY:
		m.apply_slow(1.0 - p.stat("sanctuary"), SANCTUARY_SLOW)
	if int(p.stat("fear_spread")) > 0 and m.is_feared():
		for o in BoardFeats.near(b, m, BoardFeats.NEAR, int(p.stat("fear_spread"))):
			if not o.is_feared():
				o.apply_control(SimMonster.Crowd.FEAR, p.stat("fear_duration") * 0.5, p.owner)


## Chance d'un contrôle : plus forte sur un monstre déjà contrôlé (Mauvais souvenirs).
static func control_mult(m: SimMonster, p: SimProjectile) -> float:
	return 1.0 + p.stat("vs_controlled") if m.marks.controlled > 0 else 1.0


## Vies perdues quand le monstre atteint la sortie : une de moins s'il a été affaibli (au moins 1).
static func leak_damage(m: SimMonster) -> int:
	return maxi(1, m.damage - 1) if m.marks.weakened else m.damage

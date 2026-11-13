extends RefCounted
## Évaluation des tourelles par le joueur automatique : dégâts par seconde d'une tourelle contre
## un groupe de monstres (cible sol ou air, armure, résistances, véhicules, zone, rebonds, effets
## continus, bonus des talents), gain de temps apporté par ses contrôles, et objectif global
## (part de chaque groupe à venir que la défense sait tuer, à rendements décroissants).

const Foes := preload("res://tests/bot/bot_foes.gd")

## Part de temps arrêté au plus comptée pour un contrôle (les monstres en sont protégés 1 s).
const CONTROL_CAP := 0.5
## Les auras de contrôle et la glace des voisines comptent pour cette part (chevauchement des portées).
const OVERLAP := 0.3
## Secondes de tir par monstre supposées quand on compare des tourelles sans case précise.
const DEFAULT_EXPOSURE := 2.0


## Dégâts par seconde de la tourelle (statistiques effectives `s`, définition `def`) contre le
## groupe `f`, zone et effets continus compris ; 0 si elle ne peut pas le toucher.
## slowed / stunned : un ralentissement ou un étourdissement voisin profite à ses coups ;
## grounded : un Tourbillon voisin cloue les volants (les tourelles de sol les touchent alors).
static func dps(data: GameData, type: String, s: Dictionary, f: Dictionary, slowed := false, stunned := false, grounded := false, exposure := -1.0) -> float:
	var parts := dps_parts(data, type, s, f, slowed, stunned, grounded, exposure)
	return parts[0] + parts[1] + parts[2]


## Dégâts par seconde en trois parts : [coups directs, effets continus qui se cumulent entre
## tourelles (nappes, poison et saignement à charges), effets continus qui ne se cumulent pas
## (brûlure, poison et saignement à une charge : un monstre ne subit que le plus fort)].
## exposure : secondes de tir dont la tourelle dispose par monstre du groupe (voir BotDefense).
static func dps_parts(data: GameData, type: String, s: Dictionary, f: Dictionary, slowed := false, stunned := false, grounded := false, exposure := -1.0) -> Array:
	var def: Dictionary = data.towers[type]
	var all := int(s.get("all_targets", 0)) > 0
	if f["flying"] and not (def["air"] or all or grounded):
		return [0.0, 0.0, 0.0]
	if not f["flying"] and not (def["ground"] or all):
		return [0.0, 0.0, 0.0]
	var element: String = def["element"]
	var taken := float(f["taken"].get(element, 1.0))
	if taken <= 0.0:
		return [0.0, 0.0, 0.0]
	if DataSchema.ELEMENTS.has(element):
		taken = 1.0 - (1.0 - taken) * (1.0 - float(s.get("resonance", 0.0)))
	var grounded_part := 0.6 if f["flying"] and not def["air"] and not all else 1.0
	var d := float(s["damage"])
	var rate := float(s["rate"])
	var crit := float(s.get("crit_chance", 0.0))
	if crit > 0.0:
		d *= 1.0 + crit * (1.0 + float(s.get("crit_bonus", 0.0)))
	if int(s.get("crit_every", 0)) > 0:
		d *= 1.0 + (float(s["crit_mult"]) - 1.0) / float(s["crit_every"])
	if f["big"]:
		d *= 1.0 + float(s.get("vs_big", 0.0))
	if float(s.get("vs_armored", 0.0)) > 0.0 and (f["mech"] or float(f["armor"]) >= BoardFeats.ARMORED):
		d *= 1.0 + float(s.get("vs_armored", 0.0))
	if slowed:
		d *= 1.0 + float(s.get("vs_slowed", 0.0)) * 0.7
		if element == "fire":
			d *= 1.0 + float(s.get("reaction", 0.0)) * 0.5
	if stunned:
		d *= 1.0 + float(s.get("vs_stunned", 0.0)) * 0.3
	var armor := float(f["armor"]) * (1.0 - float(s.get("armor_pierce", 0.0)))
	armor = maxf(0.0, armor - float(s.get("armor_break", 0)) * 0.5)
	var direct := maxf(d - armor, d * BoardCombat.ARMOR_MIN_RATIO) if armor > 0.0 else d
	direct = minf(direct, float(f["hp"]))  # un coup ne tue qu'un monstre : le surplus est perdu
	var attack: String = def.get("attack", "shot")
	var reach := float(s["range"])
	var hits := 1.0
	match attack:
		"pulse":
			hits = Foes.hits(f, reach)
		"line":
			hits = 1.0 + 0.5 * (Foes.hits(f, 2.0) - 1.0)
		"cone":
			hits = 1.0 + 0.5 * (Foes.hits(f, reach) - 1.0)
		"beam":
			direct *= (1.0 + float(s.get("ramp_max", 1.0))) * 0.5
		_:
			var splash := float(s.get("splash", 0.0))
			if splash > 0.0:
				hits = Foes.hits(f, splash)
			var chain := int(s.get("chain", 0))
			if chain > 0:
				var keep := BoardCombat.CHAIN_FALLOFF + float(s.get("chain_keep", 0.0))
				var extra := Foes.hits(f, BoardCombat.CHAIN_RANGE) - 1.0
				var falloff := 1.0
				for k in chain:
					if extra <= 0.0:
						break
					falloff *= keep
					hits += falloff * minf(1.0, extra)
					extra -= 1.0
			hits *= clampf(float(s.get("multishot", 1)), 1.0, Foes.hits(f, 1.5))
			hits += minf(float(s.get("pierce", 0)), Foes.hits(f, BoardFeats.NEAR) - 1.0)
	var out := direct * rate * hits * taken
	var dots := 0.0
	var single := 0.0
	var hp := float(f["hp"])
	if not f["mech"]:
		var span := 1.0 + float(s.get("dot_duration", 0.0))
		# Un effet continu se pose coup par coup : en T secondes de tir par monstre, la tourelle en
		# pose rate × T (au plus ses charges), et il ne fait jamais plus que les PV du monstre.
		var T := exposure if exposure > 0.0 else DEFAULT_EXPOSURE
		var shots := rate * T
		var poison_time := float(s.get("poison_duration", 0.0)) * span
		var poison_stacks := minf(float(s.get("poison_stacks", 1)), shots)
		var poison := minf(float(s.get("poison_dps", 0.0)) * poison_stacks * poison_time, hp) * float(f["taken"].get("poison", 1.0))
		poison *= (1.0 + 0.4 * float(s.get("poison_spread", 0.0))) / T
		var burn_time := float(s.get("burn_duration", 0.0)) * span
		var burn_stacks := minf(float(s.get("burn_stacks", 0)), shots * (hits if attack == "cone" else 1.0))
		var burn := minf(float(s.get("burn_dps", 0.0)) * burn_stacks * burn_time, hp) * float(f["taken"].get("fire", 1.0)) / T
		single += burn  # brûlure partagée entre tourelles
		var bleed_time := float(s.get("bleed_duration", 0.0)) * span
		var bleed_stacks := minf(float(s.get("bleed_stacks", 1)), shots)
		var bleed := float(s.get("bleed", 0.0)) * bleed_stacks * (1.0 - float(f["cc_resist"]) * 0.5) * bleed_time
		bleed = minf(bleed, 1.0) * hp * float(f["taken"].get("bleed", 1.0)) / T
		if int(s.get("poison_stacks", 1)) > 1:
			dots += poison
		else:
			single += poison
		if int(s.get("bleed_stacks", 1)) > 1:
			dots += bleed
		else:
			single += bleed
	if not f["flying"] and not f["hover"] and float(s.get("patch_dps", 0.0)) > 0.0:
		var radius := float(s.get("patch_radius", 0.0))
		dots += float(s.get("patch_dps", 0.0)) * Foes.hits(f, radius) * minf(1.0, rate * float(s.get("patch_duration", 0.0))) * 0.7
	var m := grounded_part * bonus(s)
	return [out * m, dots * m, single * m]


## Bonus des mécaniques de talents qui n'entrent pas dans les dégâts par seconde.
static func bonus(s: Dictionary) -> float:
	var m := 1.0
	m *= 1.0 + float(s.get("mark", 0.0)) * 1.5 + float(s.get("execute", 0.0)) * 2.0
	m *= 1.0 + float(s.get("frag", 0.0)) + float(s.get("kill_splash", 0.0)) + 0.5 * float(s.get("static_charge", 0.0))
	m *= 1.0 + 0.1 * float(s.get("storm", 0.0)) + 0.5 * float(s.get("knockback", 0.0)) + 0.4 * float(s.get("ricochet", 0.0))
	m *= 1.0 + 0.08 * (float(s.get("death_burn", 0)) + float(s.get("death_poison", 0)) + float(s.get("death_shock", 0)))
	m *= 1.0 + 0.3 * float(s.get("streak_cap", 0.0)) + 4.0 * float(s.get("growth", 0.0)) + 0.5 * float(s.get("warmup_cap", 0.0))
	m *= 1.0 + 0.3 * float(s.get("vs_afflicted", 0.0)) + 0.2 * float(s.get("vs_wounded", 0.0)) + 0.2 * float(s.get("vs_late", 0.0))
	m *= 1.0 + 0.15 * float(s.get("heal_block", 0.0)) + 0.3 * float(s.get("shred", 0.0)) + 0.3 * float(s.get("armor_break", 0)) * 0.1
	return m


## Temps gagné par les contrôles de la tourelle sur ce groupe : part du temps où il est arrêté
## (étourdi, apeuré, charmé) ou perdue au ralenti, en multiplicateur de temps sous le feu (0 : rien).
static func control(data: GameData, type: String, s: Dictionary, f: Dictionary) -> float:
	var def: Dictionary = data.towers[type]
	if f["flying"] and not def["air"] and int(s.get("all_targets", 0)) == 0:
		return 0.0
	var element: String = def["element"]
	var taken := float(f["taken"].get(element, 1.0))
	if taken <= 0.0:
		return 0.0
	var rate := float(s["rate"])
	var stopped := 0.0
	var resist := 1.0 - float(f["cc_resist"])
	stopped += float(s.get("stun_chance", 0.0)) * float(s.get("stun_duration", 0.0)) * resist
	if not f["mech"]:
		stopped += float(s.get("fear_chance", 0.0)) * float(s.get("fear_duration", 0.0)) * resist * 1.4
		if float(f["cc_resist"]) < SimMonster.CHARM_IMMUNE_FROM:
			stopped += float(s.get("charm_chance", 0.0)) * float(s.get("charm_duration", 0.0)) * 1.4
	var frac := minf(CONTROL_CAP, stopped * rate)
	var slow := 0.0
	if not f["slow_immune"]:
		var factor := float(s.get("slow_factor", 1.0)) if s.has("slow_factor") else 1.0
		if float(s.get("slow", 0.0)) > 0.0:
			factor *= 1.0 - float(s.get("slow", 0.0))
		factor = 1.0 - (1.0 - factor) * taken
		var duration := maxf(float(s.get("slow_duration", 0.0)), 1.0 if float(s.get("slow", 0.0)) > 0.0 else 0.0)
		slow = (1.0 - factor) * minf(1.0, rate * duration)
	var lost := minf(0.8, frac + slow * (1.0 - frac))
	return 1.0 / (1.0 - lost) - 1.0


## Dégâts d'un monstre charmé infligés aux autres (part de ses PV par seconde de charme).
static func charm_damage(s: Dictionary, f: Dictionary) -> float:
	var chance := float(s.get("charm_chance", 0.0))
	if chance <= 0.0 or f["flying"] or f["mech"] or float(f["cc_resist"]) >= SimMonster.CHARM_IMMUNE_FROM:
		return 0.0
	return chance * float(s["rate"]) * float(s.get("charm_duration", 0.0)) * 0.2 * (1.0 + float(s.get("charm_power", 0.0))) * float(f["hp"])


## Objectif de la défense : somme, sur les groupes à venir, de leur poids (part des PV de leur
## vague) × r / (1 + r), où r est le nombre de fois que la défense tuerait un de leurs monstres
## sur son trajet. ratios : r par groupe (même ordre que foes).
static func objective(foes: Array, ratios: PackedFloat32Array) -> float:
	var total := 0.0
	for i in foes.size():
		var r := ratios[i]
		total += float(foes[i]["weight"]) * r / (1.0 + r)
	return total

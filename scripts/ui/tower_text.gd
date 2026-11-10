class_name TowerText
extends RefCounted
## Textes des statistiques d'une tourelle (panneau latéral) : dégâts, portée, cadence, façon
## de frapper, effets, auras de soutien.

const ATTACK_TEXT := {
	"pulse": "onde autour d'elle", "line": "traverse les monstres alignés",
	"cone": "souffle en cône", "beam": "rayon continu",
}
const PHYSICAL_NAMES := {"pierce": "coups perçants (sans effet sur squelettes et fantômes)", "blunt": "coups contondants (sans effet sur les fantômes)"}
const ELEMENT_NAMES := {"fire": "feu", "ice": "glace", "lightning": "foudre", "poison": "poison", "bleed": "saignement", "wind": "vent"}


static func stats_text(def: Dictionary, s: Dictionary) -> String:
	if def.get("support", false):
		return _aura_text(s)
	var parts := ["Dégâts %s" % num(s["damage"]) if s["damage"] > 0.0 else "Aucun dégât", "portée %s" % num(s["range"]), "%s tir/s" % num(s["rate"])]
	if ELEMENT_NAMES.has(def.get("element", "")):
		parts.append("élément %s" % ELEMENT_NAMES[def["element"]])
	elif PHYSICAL_NAMES.has(def.get("element", "")):
		parts.append(PHYSICAL_NAMES[def["element"]])
	if ATTACK_TEXT.has(def.get("attack", "shot")):
		parts.append(ATTACK_TEXT[def["attack"]])
	if s["splash"] > 0.0:
		parts.append("zone %s" % num(s["splash"]))
	if s["armor_pierce"] > 0.0:
		parts.append("ignore %d %% de l'armure" % roundi(s["armor_pierce"] * 100.0))
	if s["ramp"] > 0.0:
		parts.append("+%d %% par coup sur la même cible (jusqu'à ×%s)" % [roundi(s["ramp"] * 100.0), num(s["ramp_max"])])
	if s["crit_every"] > 0:
		parts.append("critique ×%s un coup sur %d" % [num(s["crit_mult"]), s["crit_every"]])
	if s["vs_slowed"] > 0.0 or s["vs_stunned"] > 0.0:
		parts.append("+%d %% contre un ralenti, +%d %% contre un gelé" % [roundi(s["vs_slowed"] * 100.0), roundi(s["vs_stunned"] * 100.0)])
	if s["slow_factor"] < 1.0:
		parts.append("ralentit de %d %% (%s s)" % [roundi((1.0 - s["slow_factor"]) * 100.0), num(s["slow_duration"])])
	if s["chain"] > 0:
		parts.append("%d rebonds" % s["chain"])
	if s["poison_dps"] > 0.0:
		parts.append("poison %s/s pendant %s s" % [num(s["poison_dps"]), num(s["poison_duration"])])
	if s["poison_dps"] > 0.0 and s["poison_stacks"] > 1:
		parts.append("le poison se cumule (%d charges)" % s["poison_stacks"])
	if s["bleed"] > 0.0 and s["bleed_stacks"] > 1:
		parts.append("le saignement se cumule (%d charges)" % s["bleed_stacks"])
	if s["poison_spread"] > 0.0:
		parts.append("contagieux à %s cases" % num(s["poison_spread"]))
	if s["shred"] > 0.0:
		parts.append("ronge %d %% de l'armure (%s s)" % [roundi(s["shred"] * 100.0), num(s["shred_duration"])])
	if s["burn_dps"] > 0.0:
		parts.append("brûlure %s/s par charge, %d charges, %s s" % [num(s["burn_dps"]), s["burn_stacks"], num(s["burn_duration"])])
	if s["bleed"] > 0.0:
		parts.append("saignement %s %% des PV max/s pendant %s s" % [num(s["bleed"] * 100.0), num(s["bleed_duration"])])
	if s["multishot"] > 1:
		parts.append("vise %d monstres à la fois" % s["multishot"])
	if s["ground_duration"] > 0.0:
		parts.append("cloue les volants au sol %s s" % num(s["ground_duration"]))
	if s["heal_block"] > 0.0:
		parts.append("coupe %d %% des soins (%s s)" % [roundi(s["heal_block"] * 100.0), num(s["heal_block_duration"])])
	if s["patch_radius"] > 0.0:
		var hurt := " · %s dégâts/s" % num(s["patch_dps"]) if s["patch_dps"] > 0.0 else ""
		parts.append("nappe au sol de %s cases, %s s%s" % [num(s["patch_radius"]), num(s["patch_duration"]), hurt])
	for kind in [["stun", "étourdit"], ["fear", "effraie"], ["charm", "charme"]]:
		if s[kind[0] + "_chance"] > 0.0:
			parts.append("%s %d %% du temps (%s s)" % [kind[1], roundi(s[kind[0] + "_chance"] * 100.0), num(s[kind[0] + "_duration"])])
	parts.append("air et sol" if def["air"] and def["ground"] else ("sol" if def["ground"] else "air"))
	return " · ".join(parts)


static func _aura_text(s: Dictionary) -> String:
	var parts := ["Aura de portée %s" % num(s["range"])]
	if s["aura_rate"] > 0.0:
		parts.append("+%d %% de cadence" % roundi(s["aura_rate"] * 100.0))
	if s["aura_damage"] > 0.0:
		parts.append("+%d %% de dégâts" % roundi(s["aura_damage"] * 100.0))
	if s["aura_cc"] > 0.0:
		parts.append("+%d %% de chances et durées de contrôle" % roundi(s["aura_cc"] * 100.0))
	if s["aura_range"] > 0.0:
		parts.append("+%d %% de portée" % roundi(s["aura_range"] * 100.0))
	if s["aura_frostbite"] > 0.0:
		parts.append("les tourelles de glace ajoutent une gelure de %s/s (×1,5 sur un ralenti, ×2 sur un gelé)" % num(s["aura_frostbite"]))
	if s["aura_shock"] > 0.0:
		parts.append("les tourelles de foudre électrifient : +%d %% de dégâts subis" % roundi(s["aura_shock"] * 100.0))
	if s["aura_bounty"] > 0.0:
		parts.append("+%d %% de prime pour les monstres tués à portée" % roundi(s["aura_bounty"] * 100.0))
	if s["aura_discount"] > 0.0:
		parts.append("−%d %% sur les constructions et améliorations à portée" % roundi(s["aura_discount"] * 100.0))
	parts.append("la plus forte aura de chaque type s'applique")
	return " · ".join(parts)


## Auras reçues par une tourelle et brouillage (drapeaux de l'instantané).
static func buffs_text(flags: int) -> String:
	var names := []
	if flags & 1:
		names.append("dégâts")
	if flags & 2:
		names.append("cadence")
	if flags & 4:
		names.append("contrôles")
	if flags & 16:
		names.append("portée")
	if flags & 32:
		names.append("gelure")
	if flags & 64:
		names.append("électrification")
	var text := "" if names.is_empty() else "Renforcée par une aura : " + ", ".join(names) + "."
	if flags & 8:
		text += ("\n" if text != "" else "") + "Brouillée par un saboteur : elle ne fait rien quelques secondes."
	return text


## « · 9,6 dégâts/s » (coups directs seulement), vide pour une tourelle sans dégâts directs.
static func dps(def: Dictionary, s: Dictionary) -> String:
	if def.get("support", false) or s["damage"] <= 0.0:
		return ""
	if s["ramp"] > 0.0:
		return " · %s à %s dégâts/s" % [num(s["damage"] * s["rate"]), num(s["damage"] * s["rate"] * s["ramp_max"])]
	return " · %s dégâts/s" % num(s["damage"] * s["rate"])


static func num(v: float) -> String:
	return str(snappedf(v, 0.01)).replace(".", ",")

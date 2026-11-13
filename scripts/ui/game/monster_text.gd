class_name MonsterText
extends RefCounted
## Textes des bonus d'un monstre (prochaine vague, dans le panneau de coopération).

const RESIST_TEXT := {"fire": "au feu", "ice": "à la glace", "lightning": "à la foudre", "poison": "au poison"}
const FAST_FROM := 2.0


## « vole, armure 3, résiste au feu (70 %)… », vide pour un monstre sans particularité.
static func traits_text(def: Dictionary) -> String:
	var parts := []
	if def["flying"]:
		parts.append("vole")
	if def["speed"] >= FAST_FROM:
		parts.append("rapide")
	if def["hover"]:
		parts.append("lévite (ignore les nappes au sol)")
	if def["armor"] > 0.0:
		parts.append("armure %s" % _n(def["armor"]))
	if def["mechanical"]:
		parts.append("véhicule (insensible au poison, à la brûlure, au saignement, à la peur et au charme)")
	if def["slow_immune"]:
		parts.append("insensible au ralentissement")
	if def["cc_resist"] > 0.0:
		parts.append("résiste aux contrôles (%d %%)" % _pct(def["cc_resist"]))
	for e in RESIST_TEXT:
		if def["resist_" + e] > 0.0:
			parts.append("résiste %s (%d %%)" % [RESIST_TEXT[e], _pct(def["resist_" + e])])
	if def["resist_elements"] > 0.0:
		parts.append("résiste à tous les éléments (%d %%)" % _pct(def["resist_elements"]))
	for e in [["physical", "aux coups physiques"], ["pierce", "aux coups perçants (flèches, carreaux)"], ["blunt", "aux coups contondants (boulets, obus)"]]:
		var part: float = def["resist_" + e[0]]
		if part >= 1.0:
			parts.append("insensible %s" % e[1])
		elif part > 0.0:
			parts.append("résiste %s (%d %%)" % [e[1], _pct(part)])
	if def["regen"] > 0.0:
		parts.append("se régénère")
	if def["heal_rate"] > 0.0:
		parts.append("soigne ses voisins")
	if def["split_count"] > 0:
		parts.append("se divise en mourant")
	if def["blink_interval"] > 0.0:
		parts.append("bondit de %s cases toutes les %s s" % [_n(def["blink_distance"]), _n(def["blink_interval"])])
	if def["ward"] > 0.0:
		parts.append("protège ses voisins (%d %% de dégâts en moins)" % _pct(def["ward"]))
	if def["jam_interval"] > 0.0:
		parts.append("brouille les tourelles proches (%s s toutes les %s s)" % [_n(def["jam_duration"]), _n(def["jam_interval"])])
	_extras_text(def, parts)
	return ", ".join(parts)


## Capacités des monstres des thèmes (MonsterExtras).
static func _extras_text(def: Dictionary, parts: Array) -> void:
	if def["pack_count"] > 0.0:
		parts.append("chasse en meute (+%d %% de vitesse entouré des siens)" % _pct(def["pack_speed"]))
	if def["haste"] > 0.0:
		parts.append("entraîne ses voisins (+%d %% de vitesse)" % _pct(def["haste"]))
	if def["burrow_interval"] > 0.0:
		parts.append("s'enfouit %s s toutes les %s s (ni visé ni touché)" % [_n(def["burrow_duration"]), _n(def["burrow_interval"])])
	if def["brood_steps"] > 0:
		parts.append("perd une tête à chaque coup dur (un monstre de plus)")
	if def["brood_interval"] > 0.0:
		parts.append("pond un petit toutes les %s s" % _n(def["brood_interval"]))
	if def["raise_into"] != "":
		parts.append("relève les morts voisins toutes les %s s" % _n(def["raise_interval"]))
	if def["lurk"]:
		parts.append("ne dépasse pas les monstres au sol")
	if def["grove_regen"] > 0.0:
		parts.append("se régénère bien plus vite près des arbres")


## Monstres d'une vague, un par ligne avec leurs bonus : « Feu follet : lévite… ».
## mult > 0 : nombre de monstres en tête de ligne (« 12 × Loup »), voir WaveScaling.count_mult.
static func wave_text(data: GameData, wave: Dictionary, mult := 0.0) -> String:
	var counts := {}
	for g in wave["groups"]:
		var id: String = g["monster"]
		counts[id] = int(counts.get(id, 0)) + (WaveScaling.group_count(data, wave, g, mult) if mult > 0.0 else 0)
	var lines := []
	for id in counts:
		var def: Dictionary = data.monsters[id]
		var traits := traits_text(def)
		var head := "%d × " % counts[id] if mult > 0.0 else ""
		lines.append("• %s%s%s" % [head, def["name"], " : " + traits if traits != "" else ""])
	return "\n".join(lines)


## Caractéristiques de base (PV du Normal, avant le renfort des vagues) : « PV 52 · vitesse 1,6 · 3 or · 1 vie ».
static func stats_text(data: GameData, def: Dictionary) -> String:
	var hp := roundi(float(def["hp"]) * float(data.monster_scaling["hp"]))
	return "PV %d · vitesse %s · %d or · %s" % [hp, _n(def["speed"]), int(def["gold"]), lives_text(int(def["damage"]))]


static func lives_text(damage: int) -> String:
	return "%d vie%s s'il passe" % [damage, "s" if damage > 1 else ""]


const STATES := [["slowed", "ralenti"], ["poisoned", "empoisonné"], ["burning", "en feu"], ["bleeding", "saigne"],
	["stunned", "étourdi"], ["feared", "apeuré"], ["charmed", "charmé"], ["warded", "protégé"],
	["frostbitten", "gelure"], ["shocked", "électrocuté"], ["grounded", "cloué au sol"], ["burrowed", "enfoui"]]


## Info-bulle d'un monstre du plateau (m : monstre de ViewState, PV de 0 à 255).
static func hover_text(data: GameData, m: Dictionary) -> String:
	var def: Dictionary = data.monsters[m["type"]]
	var lines := [def["name"] + (" (vague spéciale)" if m.get("elite", false) else "")]
	lines.append("PV : %d %% · vitesse %s · %d or · %s" % [
		roundi(float(m["hp"]) / 2.55), _n(def["speed"]), int(def["gold"]), lives_text(int(def["damage"]))])
	var traits := traits_text(def)
	if traits != "":
		lines.append(traits.left(1).to_upper() + traits.substr(1))
	var states := []
	for s in STATES:
		if m.get(s[0], false):
			states.append(s[1])
	if not states.is_empty():
		lines.append("État : " + ", ".join(states))
	return "\n".join(lines)


static func _pct(part: float) -> int:
	return roundi(part * 100.0)


## Nombre sans « ,0 » inutile : 3 ; 2,5.
static func _n(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else TowerText.num(v)

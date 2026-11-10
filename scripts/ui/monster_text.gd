class_name MonsterText
extends RefCounted
## Textes des bonus d'un monstre (prochaine vague, dans le panneau de coopération).

const RESIST_TEXT := {"fire": "au feu", "ice": "à la glace", "lightning": "à la foudre"}
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
	return ", ".join(parts)


## Monstres d'une vague, un par ligne avec leurs bonus : « Feu follet : lévite… ».
static func wave_text(data: GameData, wave: Dictionary) -> String:
	var lines := []
	var seen := {}
	for g in wave["groups"]:
		var id: String = g["monster"]
		if seen.has(id):
			continue
		seen[id] = true
		var def: Dictionary = data.monsters[id]
		var traits := traits_text(def)
		lines.append("• %s%s" % [def["name"], " : " + traits if traits != "" else ""])
	return "\n".join(lines)


static func _pct(part: float) -> int:
	return roundi(part * 100.0)


## Nombre sans « ,0 » inutile : 3 ; 2,5.
static func _n(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else TowerText.num(v)

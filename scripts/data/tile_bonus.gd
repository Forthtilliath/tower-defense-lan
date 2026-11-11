class_name TileBonus
extends RefCounted
## Bonus d'une case spéciale sur la tourelle posée dessus (GameData.tower_stats). Une case peut
## être réservée à une famille de tourelles (« only » : un élément, « physical » ou « support ») ;
## les autres tourelles n'en tirent rien.
##
## range / rate / damage : multiplicateurs ; durations : durées du poison, de la brûlure, du
## saignement et du ralentissement ; chain : rebonds en plus ; crit : chance de coup critique ;
## vs_big : dégâts en plus contre les boss et gros monstres ; air : vise aussi les volants ;
## veteran / veteran_cap : dégâts en plus par monstre tué depuis la construction, plafonnés ;
## kill_gold : or par monstre tué ; nojam : ne peut pas être brouillée. Hors statistiques :
## discount (réduction des constructions et améliorations sur la case, MatchActions), wears
## (vagues avec une tourelle dessus avant épuisement, BoardTiles), slow (Fossé, BoardTerrain).

## Familles de tourelles que l'on peut viser avec « only » (en plus des éléments).
const FAMILIES := ["physical", "support"]


## La tourelle de type `type` profite-t-elle de la case `s` ?
static func applies(data: GameData, type: String, s: Dictionary) -> bool:
	var only: String = s.get("only", "")
	if only == "":
		return true
	var def: Dictionary = data.towers[type]
	if only == "support":
		return def["support"]
	if only == "physical":
		return DataSchema.PHYSICAL.has(def["element"])
	return def["element"] == only


## Applique la case à `stats` ; boost : 1 + Terre fertile (bonus de la case multipliés).
static func apply(data: GameData, stats: Dictionary, type: String, s: Dictionary, boost: float) -> void:
	if not applies(data, type, s):
		return
	stats["range"] *= 1.0 + (float(s["range"]) - 1.0) * boost
	stats["rate"] *= 1.0 + (float(s["rate"]) - 1.0) * boost
	GameData.scale_damage(stats, 1.0 + (float(s["damage"]) - 1.0) * boost)
	var lasting := 1.0 + (float(s["durations"]) - 1.0) * boost
	for key in ["poison_duration", "burn_duration", "bleed_duration", "slow_duration"]:
		stats[key] *= lasting
	stats["chain"] = int(stats["chain"]) + roundi(int(s["chain"]) * boost)
	stats["crit_chance"] = minf(1.0, float(stats["crit_chance"]) + float(s["crit"]) * boost)
	stats["vs_big"] = float(stats["vs_big"]) + float(s["vs_big"]) * boost
	if s["air"]:
		stats["all_targets"] = 1
	stats["tile_veteran"] = float(s["veteran"]) * boost
	stats["tile_veteran_cap"] = float(s["veteran_cap"]) * boost
	stats["kill_gold"] = roundi(int(s["kill_gold"]) * boost)
	stats["nojam"] = 1 if s["nojam"] else 0


## Réduction de prix sur la case (Forge), 0 si aucune.
static func discount(data: GameData, map: MapDef, cell: int, type: String) -> float:
	var special := map.special_at(cell)
	if special < 0 or not applies(data, type, data.specials[special]):
		return 0.0
	return float(data.specials[special]["discount"])


## Valide le champ « only » d'une case spéciale.
static func valid_only(only: String) -> bool:
	return only == "" or DataSchema.ELEMENTS.has(only) or FAMILIES.has(only)

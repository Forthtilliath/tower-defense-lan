class_name PlayerKit
extends RefCounted
## Ce qu'un joueur apporte en partie : sa classe et ses talents (déjà validés).
## Tourelles constructibles (tronc commun + celles de la classe + débloquées par la spécialisation),
## bonus par tourelle (classe × talents), économie (primes, intérêts, or de départ, coûts, revente, dons).

const STATS := ["damage", "rate", "range", "cc", "aura"]
## Économie des talents (MatchEconomy), une valeur par rang qui s'additionne (voir TalentSchema.TALENT).
const MONEY := ["loot", "loan", "boss_bounty", "jackpot", "trophy", "contract", "rent", "compound", "ally_start",
	"invest", "team_discount", "share_interest", "hot_hand", "early_wave", "risk", "nerve",
	"floors", "moves", "scrap", "spare", "tinker", "team_aura", "vein_tiles", "mound_tiles", "ditch_tiles", "fertile",
	"saver", "jackpot_share"]
const ECONOMY := ["bounty", "interest", "interest_cap", "start_gold", "build_cost", "sell_bonus", "gift_bonus",
	"team_bounty", "early_bonus", "clean_gold", "raze_charges", "tile_charges"] + MONEY
## Auras des tourelles de soutien, toutes renforcées par la statistique « aura ».
const AURAS := ["aura_rate", "aura_damage", "aura_cc", "aura_range", "aura_frostbite", "aura_shock", "aura_bounty", "aura_discount",
	"aura_crit", "aura_late", "aura_veteran", "aura_charge", "aura_rally", "aura_stun", "aura_sanct", "aura_rush"]
## Plafonds : réduction des prix, part de revente, part d'un don reçue par l'allié.
const MAX_DISCOUNT := 0.5
const MAX_SELL := 0.9
const MAX_GIFT := 1.0

var builder := 0
var talents := {}  # id du talent -> rang
## Classes héritées (montées au niveau maximum, autres que celle jouée) dont le bonus s'applique.
var heritage: Array[int] = []
var towers := {}  # id de tourelle -> true
## Branche de spécialisation choisie (index dans les branches de la classe), -1 : aucune encore.
var spec := -1
var bounty := 1.0
var interest := 0.0
var interest_cap := 0
var start_gold := 0
var build_cost := 0.0
var sell_bonus := 0.0
var gift_bonus := 0.0
var team_bounty := 0.0
var early_bonus := 0.0
var clean_gold := 0
## Terrassier : décor à raser et cases spéciales à poser, par partie.
var raze_charges := 0
var tile_charges := 0
## Ses tourelles d'imprégnation renforcent toutes leurs voisines (pas seulement leur élément).
var imbue_all := false
## En partie : vagues franchies sans fuite par son plateau (Phénix : croissance, BoardFeats),
## d'affilée (Main chaude), boss tués (Trophées), dernière vague où le Contrat a payé.
var clean_waves := 0
var clean_streak := 0
var trophies := 0
var contract_wave := -99  # -1 est la vague « avant la première »
## Économie des talents (MONEY) : valeurs cumulées des rangs.
var money := {}
## Pièces détachées : bonus de dégâts promis à la prochaine tourelle construite.
var spare_pending := 0.0
## Chef-d'œuvre : case de sa tourelle chef-d'œuvre (-1 : aucune encore).
var masterpiece_cell := -1
## Alliés dans la partie (Esprit d'équipe), fixé au départ par MatchEconomy.setup.
var allies := 0
## Pouvoir actif (MatchPowers.POWERS) donné par son talent ultime, "" sinon.
var power := ""
var _base := {}  # multiplicateurs de la classe
var _bonus_towers := {}  # tourelles visées par le bonus de classe (vide : toutes)
var _all := {}  # bonus des talents sur toutes les tourelles
var _per := {}  # id de tourelle -> bonus des talents qui la visent
var _grants := {}  # id de tourelle ("" : toutes) -> effets ajoutés par les talents (TalentSchema.GRANT)


## heritage : classes déjà montées au niveau maximum (index), dont le bonus d'héritage s'ajoute
## (sauf celui de la classe jouée).
static func make(data: GameData, p_builder: int, p_talents := {}, p_heritage: Array = []) -> PlayerKit:
	var k := PlayerKit.new()
	k.builder = clampi(p_builder, 0, data.builders.size() - 1)
	k.talents = p_talents
	var b: Dictionary = data.builders[k.builder]
	for id in data.common_towers + b["towers"]:
		k.towers[id] = true
	for key in STATS:
		k._base[key] = float(b[key])
	for id in b["bonus_towers"]:
		k._bonus_towers[id] = true
	k.bounty = float(b["bounty"])
	k.interest = float(b["interest"])
	k.interest_cap = int(b["interest_cap"])
	k.start_gold = int(b["start_gold"])
	var branches: Array = b["branches"]
	for i in branches.size():
		for t in branches[i]["talents"]:
			var rank := int(p_talents.get(t["id"], 0))
			if rank > 0:
				k._apply(t, rank)
				if not branches[i]["trunk"]:
					k.spec = i
	for h in p_heritage:
		if h != k.builder and h >= 0 and h < data.builders.size() and data.builders[h].has("heritage"):
			k.heritage.append(h)
			k._apply(data.builders[h]["heritage"], 1)
	return k


func _apply(t: Dictionary, rank: int) -> void:
	if t["unlock"] != "":
		towers[t["unlock"]] = true
	if str(t.get("power", "")) != "":
		power = t["power"]
	bounty += float(t["bounty"]) * rank
	interest += float(t["interest"]) * rank
	interest_cap += int(t["interest_cap"]) * rank
	start_gold += int(t["start_gold"]) * rank
	build_cost += float(t["build_cost"]) * rank
	sell_bonus += float(t["sell_bonus"]) * rank
	gift_bonus += float(t["gift_bonus"]) * rank
	team_bounty += float(t["team_bounty"]) * rank
	early_bonus += float(t["early_bonus"]) * rank
	clean_gold += int(t["clean_gold"]) * rank
	raze_charges += int(t["raze_charges"]) * rank
	tile_charges += int(t["tile_charges"]) * rank
	imbue_all = imbue_all or t["imbue_all"]
	for key in MONEY:
		if float(t.get(key, 0.0)) > 0.0:
			money[key] = float(money.get(key, 0.0)) + float(t[key]) * rank
	for key in t["grant"]:
		if t["grant"][key] > 0:
			for id in (t["towers"] if not t["towers"].is_empty() else [""]):
				if not _grants.has(id):
					_grants[id] = {}
				_grants[id][key] = _grants[id].get(key, 0) + t["grant"][key] * rank
	for s in STATS:
		var v := float(t[s]) * rank
		if v <= 0.0:
			continue
		if t["towers"].is_empty():
			_all[s] = float(_all.get(s, 0.0)) + v
		else:
			for id in t["towers"]:
				if not _per.has(id):
					_per[id] = {}
				_per[id][s] = float(_per[id].get(s, 0.0)) + v


## Valeur d'un effet d'économie des talents (0 s'il n'en a pas).
func m(key: String) -> float:
	return float(money.get(key, 0.0))


func allows(type: String) -> bool:
	return towers.has(type)


## Nom de la spécialisation choisie ("" tant qu'aucun point n'est placé dans une spécialisation).
func spec_name(data: GameData) -> String:
	return data.builders[builder]["branches"][spec]["name"] if spec >= 0 else ""


## « Arcaniste », ou « Arcaniste · Mage de feu » une fois la spécialisation choisie.
func title(data: GameData) -> String:
	var name: String = data.builders[builder]["name"]
	return name if spec < 0 else "%s · %s" % [name, spec_name(data)]


## Multiplicateur d'une statistique pour une tourelle : classe × (1 + bonus des talents).
func mult(type: String, stat: String) -> float:
	var extra := float(_all.get(stat, 0.0)) + float(_per.get(type, {}).get(stat, 0.0))
	var base := float(_base.get(stat, 1.0)) if _bonus_towers.is_empty() or _bonus_towers.has(type) else 1.0
	return base * (1.0 + extra)


func boost(stats: Dictionary, type: String) -> void:
	stats["range"] *= mult(type, "range")
	stats["rate"] *= mult(type, "rate")
	GameData.scale_damage(stats, mult(type, "damage"))
	GameData.scale_control(stats, mult(type, "cc"))
	var aura := mult(type, "aura") * (1.0 + m("team_aura") * allies)
	for key in AURAS:
		stats[key] *= aura
	for id in ["", type]:  # effets ajoutés (talents ultimes), après les multiplicateurs
		for key in _grants.get(id, {}):
			stats[key] += _grants[id][key]
			if TalentSchema.GRANT_CAPS.has(key):
				stats[key] = minf(stats[key], TalentSchema.GRANT_CAPS[key])


## Intérêts : [taux, plafond], plafond de la difficulté, bonus de la classe et des talents compris.
func interest_rule(data: GameData, difficulty := {}) -> Array:
	var base := base_interest(data, difficulty)
	return [float(base[0]) + interest, int(base[1]) + interest_cap]


## Intérêts sans bonus : taux du joueur, plafond de la difficulté (celui du joueur à défaut).
static func base_interest(data: GameData, difficulty := {}) -> Array:
	var cap := int(difficulty.get("interest_cap", -1))
	return [float(data.player["interest"]), cap if cap >= 0 else int(data.player["interest_cap"])]


## Prix payé pour une construction ou une amélioration affichée à `base` or ; `zone` : réduction
## d'un Chantier voisin (le total reste plafonné).
func cost(base: int, zone := 0.0) -> int:
	return maxi(1, roundi(base * (1.0 - minf(build_cost + zone, MAX_DISCOUNT))))


## Total payé pour une tourelle arrivée au niveau `level`, réductions comprises.
func invested(data: GameData, type: String, level: int) -> int:
	var total := 0
	var levels := data.levels_for(type, self)
	for i in mini(level + 1, levels.size()):
		total += cost(int(levels[i]["cost"]))
	return total


## Part de l'or investi rendue à la revente.
func sell_ratio() -> float:
	return minf(MAX_SELL, SimMatch.SELL_RATIO + sell_bonus)


## Part d'un don reçue par l'allié.
func gift_ratio(data: GameData) -> float:
	return minf(MAX_GIFT, float(data.player["gift_ratio"]) + gift_bonus)

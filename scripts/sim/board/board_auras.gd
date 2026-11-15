class_name BoardAuras
extends RefCounted
## Auras des tourelles de soutien : chaque tourelle qui tire reçoit, pour chaque type d'aura
## (cadence, dégâts, contrôles, portée, gelure, électrifié), le bonus de la plus forte tourelle de
## soutien dont la portée l'atteint. Les bonus ne s'additionnent pas entre eux. Une tourelle de
## soutien brouillée n'en donne plus (MonsterAbilities refait les auras quand elle s'éteint ou se
## rallume). Le joueur qui pose l'aura est crédité d'une part des dégâts et contrôles qu'elle apporte.
##
## Imprégnation (Stèle de gelure, Paratonnerre) : les voisines de leur élément (glace, foudre) et
## celles de la classe de leur propriétaire en profitent, toutes avec son talent imbue_all.
## Zones (Comptoir, Chantier) : pas un bonus de tourelle, mais une valeur au point visé (best_at).

const KINDS := {"rate": "aura_rate", "damage": "aura_damage", "cc": "aura_cc", "range": "aura_range",
	"frostbite": "aura_frostbite", "shock": "aura_shock", "crit": "aura_crit", "late": "aura_late",
	"nojam": "aura_nojam", "veteran": "aura_veteran", "charge": "aura_charge", "rally": "aura_rally",
	"stun": "aura_stun", "light": "aura_light", "sanct": "aura_sanct", "rush": "aura_rush", "air": "aura_air"}
## Élément des voisines qu'une aura d'imprégnation renforce (sans le talent imbue_all).
const IMBUE := {"frostbite": "ice", "shock": "lightning"}
## Auras comptées dans le partage du crédit (les autres ne sont pas une part simple des coups :
## gelure en dégâts/s, auras des talents du Support).
const SHARES := ["rate", "damage", "cc", "range", "shock"]


## Recalcule les auras de tout le plateau (après une construction, amélioration ou vente).
static func refresh(b: SimBoard) -> void:
	for cell in b.towers:
		b.towers[cell].buffs = {}
	for cell in b.towers:
		var s: SimTower = b.towers[cell]
		if not s.support or s.is_jammed():
			continue
		var reach: float = s.stats["range"]
		for other_cell in b.towers:
			var t: SimTower = b.towers[other_cell]
			if t.support or t.center.distance_to(s.center) > reach:
				continue
			var element: String = b.data.towers[t.type]["element"]
			for kind in KINDS:
				var value: float = s.stats[KINDS[kind]]
				if value <= 0.0 or value <= t.buff(kind):
					continue
				if not imbues(kind, s.kit, t.type, element):
					continue
				t.buffs[kind] = [value, s.owner]


## Une aura d'imprégnation renforce-t-elle cette voisine ? Oui pour son élément (glace, foudre)
## et pour les tourelles de la classe de son propriétaire (bonus de classe : le Fléau pour la
## Stèle et le Paratonnerre) ; toutes avec le talent imbue_all. Les autres auras : toujours.
static func imbues(kind: String, owner_kit: PlayerKit, type: String, element: String) -> bool:
	if not IMBUE.has(kind) or element == IMBUE[kind]:
		return true
	return owner_kit != null and (owner_kit.imbue_all or owner_kit.class_tower(type))


## Statistiques de tir de la tourelle, auras comprises (dégâts, contrôles, imprégnation).
static func effective_stats(t: SimTower) -> Dictionary:
	var s := t.stats.duplicate()
	GameData.scale_damage(s, 1.0 + t.buff("damage"))
	GameData.scale_control(s, 1.0 + t.buff("cc"))
	s["frostbite_dps"] = t.buff("frostbite")
	s["shock"] = t.buff("shock")
	return s


## Portée de tir, aura de portée comprise.
static func reach(t: SimTower) -> float:
	return float(t.stats["range"]) * (1.0 + t.buff("range")) * BoardLayout.reach_mult(t)


## Délai entre deux tirs, aura de cadence comprise.
static func fire_delay(t: SimTower) -> float:
	return 1.0 / (float(t.stats["rate"]) * (1.0 + t.buff("rate")))


## Répartition du crédit d'un tir : le tireur, et chaque aura au prorata de son bonus.
static func credit(t: SimTower) -> Array:
	var total := 1.0
	for kind in t.buffs:
		if SHARES.has(kind):
			total += float(t.buffs[kind][0])
	var shares := {t.owner: 1.0 / total}
	for kind in t.buffs:
		if not SHARES.has(kind):
			continue
		var owner: int = t.buffs[kind][1]
		shares[owner] = float(shares.get(owner, 0.0)) + float(t.buffs[kind][0]) / total
	var out := []
	for owner in shares:
		out.append([owner, shares[owner]])
	return out


## Plus forte valeur de zone `key` (aura_bounty, aura_discount) au point `at` : [valeur, propriétaire]
## de la tourelle de soutien (non brouillée) qui la donne, [0.0, 0] si aucune ne l'atteint.
static func best_at(b: SimBoard, at: Vector2, key: String) -> Array:
	var entries := []
	for cell in b.towers:
		var s: SimTower = b.towers[cell]
		if s.support and not s.is_jammed():
			entries.append([s.center, s.stats, s.owner])
	return best_among(entries, at, key)


## Même règle sur une liste [[centre, statistiques, propriétaire], ...] (aussi utilisée par
## l'interface, qui n'a que l'instantané du plateau).
static func best_among(entries: Array, at: Vector2, key: String) -> Array:
	var best := [0.0, 0]
	for e in entries:
		var value := float(e[1].get(key, 0.0))
		if value > float(best[0]) and at.distance_to(e[0]) <= float(e[1]["range"]):
			best = [value, e[2]]
	return best

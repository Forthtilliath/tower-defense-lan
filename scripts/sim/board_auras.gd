class_name BoardAuras
extends RefCounted
## Auras des tourelles de soutien : chaque tourelle qui tire reçoit, pour chaque type d'aura
## (cadence, dégâts, contrôles), le bonus de la plus forte tourelle de soutien dont la portée
## l'atteint. Les bonus ne s'additionnent pas entre eux.
## Le joueur qui pose l'aura est crédité d'une part des dégâts et contrôles qu'elle apporte.

const KINDS := {"rate": "aura_rate", "damage": "aura_damage", "cc": "aura_cc"}


## Recalcule les auras de tout le plateau (après une construction, amélioration ou vente).
static func refresh(b: SimBoard) -> void:
	for cell in b.towers:
		b.towers[cell].buffs = {}
	for cell in b.towers:
		var s: SimTower = b.towers[cell]
		if not s.support:
			continue
		var reach: float = s.stats["range"]
		for other_cell in b.towers:
			var t: SimTower = b.towers[other_cell]
			if t.support or t.center.distance_to(s.center) > reach:
				continue
			for kind in KINDS:
				var value: float = s.stats[KINDS[kind]]
				if value > 0.0 and value > t.buff(kind):
					t.buffs[kind] = [value, s.owner]


## Statistiques de tir de la tourelle, auras de dégâts et de contrôles comprises.
static func effective_stats(t: SimTower) -> Dictionary:
	var s := t.stats.duplicate()
	GameData.scale_damage(s, 1.0 + t.buff("damage"))
	GameData.scale_control(s, 1.0 + t.buff("cc"))
	return s


## Délai entre deux tirs, aura de cadence comprise.
static func fire_delay(t: SimTower) -> float:
	return 1.0 / (float(t.stats["rate"]) * (1.0 + t.buff("rate")))


## Répartition du crédit d'un tir : le tireur, et chaque aura au prorata de son bonus.
static func credit(t: SimTower) -> Array:
	var total := 1.0
	for kind in t.buffs:
		total += float(t.buffs[kind][0])
	var shares := {t.owner: 1.0 / total}
	for kind in t.buffs:
		var owner: int = t.buffs[kind][1]
		shares[owner] = float(shares.get(owner, 0.0)) + float(t.buffs[kind][0]) / total
	var out := []
	for owner in shares:
		out.append([owner, shares[owner]])
	return out

class_name BoardLayout
extends RefCounted
## Talents liés à la disposition des tourelles d'un joueur : Harmonie (éléments voisins), Bâtisseur
## (mur porteur, pierre angulaire, symétrie, clé de voûte, plans, contreforts, chef-d'œuvre, pièces
## détachées) et déplacement d'une tourelle (Ferrailleur : Déménageur, Bricolage).

## Voisines : tourelles du même joueur à cette distance au plus (diagonales comprises).
const NEIGHBOUR := 1.5
const KEYSTONE := 3
## Niveaux (index) à partir desquels jouent les plans (niveau 5), les contreforts et le chef-d'œuvre.
const PLANS_LEVEL := 4
const BUTTRESS_LEVEL := 5
const MASTERPIECE_LEVEL := 6
const TINKER_TIME := 30.0


static func neighbours(b: SimBoard, t: SimTower) -> Array[SimTower]:
	var out: Array[SimTower] = []
	for cell in b.towers:
		var o: SimTower = b.towers[cell]
		if o != t and o.owner == t.owner and o.center.distance_to(t.center) <= NEIGHBOUR:
			out.append(o)
	return out


## Éléments différents parmi les tourelles voisines du même joueur (elle exceptée).
static func elements_around(b: SimBoard, t: SimTower) -> int:
	var seen := {}
	for o in neighbours(b, t):
		var e: String = b.data.towers[o.type]["element"]
		if DataSchema.ELEMENTS.has(e):
			seen[e] = true
	return seen.size()


## Multiplicateur de dégâts d'un tir selon la disposition (statistiques de la tourelle p.stats).
static func damage_mult(b: SimBoard, t: SimTower, p: SimProjectile) -> float:
	var mult := 1.0 + t.spare
	var keys := ["harmony", "wall", "keystone", "twin", "crown", "masterpiece"]
	if not keys.any(func(k: String) -> bool: return p.stat(k) > 0.0):
		return mult
	var around := neighbours(b, t)
	if p.stat("harmony") > 0.0:
		mult *= 1.0 + p.stat("harmony") * elements_around(b, t)
	mult *= 1.0 + p.stat("wall") * around.size()
	if around.size() >= KEYSTONE:
		mult *= 1.0 + p.stat("keystone")
	if around.any(func(o: SimTower) -> bool: return o.type == t.type):
		mult *= 1.0 + p.stat("twin")
	if p.stat("crown") > 0.0 and is_crown(b, t):
		mult *= 1.0 + p.stat("crown")
	if p.stat("masterpiece") > 0.0 and t.level >= MASTERPIECE_LEVEL and t.kit != null:
		if t.kit.masterpiece_cell < 0 or not b.towers.has(t.kit.masterpiece_cell):
			t.kit.masterpiece_cell = t.cell
		if t.kit.masterpiece_cell == t.cell:
			mult *= 1.0 + p.stat("masterpiece")
	return mult


## Sa tourelle la plus chère (Clé de voûte) : aucune autre des siennes n'a coûté plus.
static func is_crown(b: SimBoard, t: SimTower) -> bool:
	for cell in b.towers:
		var o: SimTower = b.towers[cell]
		if o.owner == t.owner and o.invested > t.invested:
			return false
	return true


## Portée en plus : plans soignés au niveau 5 et plus.
static func reach_mult(t: SimTower) -> float:
	return 1.0 + float(t.stats.get("plans", 0.0)) if t.level >= PLANS_LEVEL else 1.0


## Cadence en plus : contreforts au niveau 6 et plus, tourelle déplacée (Bricolage).
static func rate_mult(t: SimTower) -> float:
	var mult := 1.0
	if t.level >= BUTTRESS_LEVEL:
		mult += float(t.stats.get("buttress", 0.0))
	if t.tinker > 0.0 and t.kit != null:
		mult += t.kit.m("tinker")
	return mult


## Nouvelle tourelle : elle reçoit les pièces détachées promises par la dernière revente.
static func on_build(t: SimTower) -> void:
	if t.kit != null and t.kit.spare_pending > 0.0:
		t.spare = t.kit.spare_pending
		t.kit.spare_pending = 0.0


## Revente : la prochaine tourelle construite sera renforcée (Pièces détachées).
static func on_sell(kit: PlayerKit) -> void:
	if kit != null and kit.m("spare") > 0.0:
		kit.spare_pending = kit.m("spare")


## Déplace une tourelle sur une case libre (statistiques recalculées pour la nouvelle case).
static func move(b: SimBoard, t: SimTower, to: int) -> void:
	b.towers.erase(t.cell)
	t.cell = to
	t.center = b.map.cell_center(to)
	t.special = b.map.special_at(to)
	t.tinker = TINKER_TIME
	b.towers[to] = t
	b.refresh_stats(t)

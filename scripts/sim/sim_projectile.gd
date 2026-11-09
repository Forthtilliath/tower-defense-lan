class_name SimProjectile
extends RefCounted
## Projectile à tête chercheuse tiré par une tourelle.
## stats : statistiques effectives au moment du tir (niveau, case, bâtisseur, auras).
## credit : [[id joueur, part], ...] : qui est crédité des dégâts et contrôles (tireur et auras).

var id := 0
var pos := Vector2.ZERO
var target_id := 0
var target_pos := Vector2.ZERO
var speed := 1.0
var stats := {}
var credit: Array = []
var owner := 0
var hits_air := true
var hits_ground := true


func stat(key: String) -> float:
	return float(stats.get(key, 0.0))

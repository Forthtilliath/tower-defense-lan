class_name SimProjectile
extends RefCounted
## Projectile à tête chercheuse tiré par une tourelle. Sert aussi de « coup » pour les tirs
## instantanés (onde, trait, souffle, rayon) et les nappes au sol, sans être lancé.
## stats : statistiques effectives au moment du tir (niveau, case, bâtisseur, auras).
## credit : [[id joueur, part], ...] : qui est crédité des dégâts et contrôles (tireur et auras).
## kind : index de la tourelle dans GameData.tower_order (couleur des nappes au sol).
## element : élément de la tourelle ("" : physique), auquel certains monstres résistent.

var id := 0
var pos := Vector2.ZERO
var target_id := 0
var target_pos := Vector2.ZERO
var speed := 1.0
var stats := {}
var credit: Array = []
var owner := 0
## Joueur crédité de la gelure (celui qui pose la Stèle de gelure voisine, sinon le tireur).
var frost_owner := 0
var kind := 0
var element := ""
var hits_air := true
var hits_ground := true


func stat(key: String) -> float:
	return float(stats.get(key, 0.0))

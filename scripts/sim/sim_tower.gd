class_name SimTower
extends RefCounted
## Tourelle posée sur une case, appartenant à un joueur.

enum Target { FIRST, STRONGEST, CLOSEST }

const TARGET_NAMES := ["Le plus avancé", "Le plus résistant", "Le plus proche"]

var cell := 0
var type := ""
var owner := 0
var level := 0
var invested := 0
var cooldown := 0.0
var target_mode := 0
var center := Vector2.ZERO
## Case spéciale sous la tourelle (index dans GameData.specials), -1 si aucune.
var special := -1
## Bâtisseur du propriétaire (index dans GameData.builders), dont le bonus s'applique.
var builder := -1
## Statistiques effectives (niveau + bonus de case), recalculées à chaque amélioration.
var stats := {}
## Auras reçues des tourelles de soutien voisines : type -> [bonus, id du joueur qui la pose].
## Types : "rate", "damage", "cc". Seule la plus forte de chaque type compte.
var buffs := {}
var support := false


func buff(kind: String) -> float:
	return float(buffs[kind][0]) if buffs.has(kind) else 0.0


## Drapeaux d'aura pour l'affichage : 1 dégâts, 2 cadence, 4 contrôles.
func buff_flags() -> int:
	return (1 if buffs.has("damage") else 0) | (2 if buffs.has("rate") else 0) | (4 if buffs.has("cc") else 0)

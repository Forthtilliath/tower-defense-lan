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
## Kit du propriétaire (bâtisseur et talents), dont les bonus s'appliquent.
var kit: PlayerKit
## Statistiques effectives (niveau + bonus de case), recalculées à chaque amélioration.
var stats := {}
## Auras reçues des tourelles de soutien voisines : type -> [bonus, id du joueur qui la pose].
## Types : "rate", "damage", "cc". Seule la plus forte de chaque type compte.
var buffs := {}
var support := false
## Rayon continu : monstre accroché (0 : aucun) et coups d'affilée sur lui (chaleur).
var beam_target := 0
var heat := 0
## Tirs depuis la construction (coup critique tous les crit_every tirs).
var shots := 0
## Brouillée par un monstre : ne tire plus (ni ne donne son aura) pendant ces secondes.
var jammed := 0.0
## Protection contre un nouveau brouillage (secondes), voir MonsterAbilities.
var jam_guard := 0.0
## Talents (BoardFeats) : secondes de tir sans interruption (échauffement) et monstres tués
## depuis que la carte était vide (série).
var warm := 0.0
var kills := 0
## Orage : secondes depuis le dernier éclair gratuit.
var storm_clock := 0.0
## Bâtisseur (BoardLayout) : dégâts en plus des pièces détachées, secondes de cadence en plus
## après un déplacement (Bricolage).
var spare := 0.0
var tinker := 0.0
## Monstres tués depuis sa construction (Vétérans).
var kills_total := 0


func buff(kind: String) -> float:
	return float(buffs[kind][0]) if buffs.has(kind) else 0.0


func is_jammed() -> bool:
	return jammed > 0.0


## Drapeaux pour l'affichage : auras reçues (1 dégâts, 2 cadence, 4 contrôles, 16 portée,
## 32 gelure, 64 électrifié), 8 brouillée.
func buff_flags() -> int:
	return (1 if buffs.has("damage") else 0) | (2 if buffs.has("rate") else 0) | (4 if buffs.has("cc") else 0) \
			| (8 if is_jammed() else 0) | (16 if buffs.has("range") else 0) | (32 if buffs.has("frostbite") else 0) \
			| (64 if buffs.has("shock") else 0)

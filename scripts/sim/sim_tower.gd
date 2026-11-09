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

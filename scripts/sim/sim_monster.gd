class_name SimMonster
extends RefCounted
## Monstre simulé par l'hôte. Avance le long d'un chemin de la carte (unités : cases).

var id := 0
var type := ""
var type_index := 0
var hp := 1.0
var max_hp := 1.0
var hp_mult := 1.0
var speed := 1.0
var gold := 0
var damage := 1
var flying := false
var armor := 0.0
var regen := 0.0
var slow_immune := false
var heal_radius := 0.0
var heal_rate := 0.0
var split_into := ""
var split_count := 0
## Vague spéciale qui renforce ce monstre (vide si aucune), transmise à ses divisions.
var modifier := {}
var path := 0
var progress := 0.0
var length := 1.0
var pos := Vector2.ZERO
var slow_factor := 1.0
var slow_timer := 0.0
var poison_dps := 0.0
var poison_timer := 0.0
var poison_owner := 0


## Remplit les caractéristiques depuis la définition du monstre (données du jeu).
## p_hp_mult inclut déjà le multiplicateur de PV de la vague spéciale `mod`.
func setup(def: Dictionary, p_hp_mult: float, reward_mult: float, mod := {}) -> void:
	modifier = mod
	hp_mult = p_hp_mult
	max_hp = float(def["hp"]) * hp_mult
	hp = max_hp
	speed = float(def["speed"]) * float(mod.get("speed", 1.0))
	var base_gold: int = def["gold"]
	var gold_mult := reward_mult * float(mod.get("gold", 1.0))
	gold = maxi(1, roundi(base_gold * gold_mult)) if base_gold > 0 else 0
	damage = def["damage"]
	flying = def["flying"]
	armor = float(def["armor"]) + float(mod.get("armor", 0.0))
	regen = float(def["regen"]) + max_hp * float(mod.get("regen", 0.0))
	slow_immune = def["slow_immune"]
	heal_radius = def["heal_radius"]
	heal_rate = def["heal_rate"]
	split_into = def["split_into"]
	split_count = def["split_count"]


func is_alive() -> bool:
	return hp > 0.0


func reached_end() -> bool:
	return progress >= length


## Part du chemin déjà parcourue (0 à 1), sert à viser « le plus avancé ».
func ratio() -> float:
	return progress / length if length > 0.0 else 1.0


func is_slowed() -> bool:
	return slow_timer > 0.0


func is_poisoned() -> bool:
	return poison_timer > 0.0


func is_elite() -> bool:
	return not modifier.is_empty()


func move(dt: float) -> void:
	var mult := slow_factor if slow_timer > 0.0 else 1.0
	slow_timer = maxf(0.0, slow_timer - dt)
	progress += speed * mult * dt


## Applique un ralentissement : garde le plus fort, prolonge la durée.
func apply_slow(factor: float, duration: float) -> void:
	if slow_immune or factor >= 1.0 or duration <= 0.0:
		return
	if slow_timer <= 0.0 or factor < slow_factor:
		slow_factor = factor
	slow_timer = maxf(slow_timer, duration)


## Empoisonne : garde le poison le plus fort (et son auteur pour la prime), prolonge la durée.
func apply_poison(dps: float, duration: float, owner: int) -> void:
	if dps <= 0.0 or duration <= 0.0:
		return
	if poison_timer <= 0.0 or dps >= poison_dps:
		poison_dps = dps
		poison_owner = owner
	poison_timer = maxf(poison_timer, duration)

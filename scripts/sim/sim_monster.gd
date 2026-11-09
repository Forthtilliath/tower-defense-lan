class_name SimMonster
extends RefCounted
## Monstre simulé par l'hôte. Avance le long d'un chemin de la carte (unités : cases).

var id := 0
var type := ""
var type_index := 0
var hp := 1.0
var max_hp := 1.0
var speed := 1.0
var gold := 0
var damage := 1
var flying := false
var path := 0
var progress := 0.0
var length := 1.0
var pos := Vector2.ZERO
var slow_factor := 1.0
var slow_timer := 0.0


func is_alive() -> bool:
	return hp > 0.0


func reached_end() -> bool:
	return progress >= length


## Part du chemin déjà parcourue (0 à 1), sert à viser « le premier ».
func ratio() -> float:
	return progress / length if length > 0.0 else 1.0


func move(dt: float) -> void:
	var mult := slow_factor if slow_timer > 0.0 else 1.0
	slow_timer = maxf(0.0, slow_timer - dt)
	progress += speed * mult * dt


## Applique un ralentissement : garde le plus fort, prolonge la durée.
func apply_slow(factor: float, duration: float) -> void:
	if factor >= 1.0 or duration <= 0.0:
		return
	if slow_timer <= 0.0 or factor < slow_factor:
		slow_factor = factor
	slow_timer = maxf(slow_timer, duration)

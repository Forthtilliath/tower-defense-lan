class_name SimProjectile
extends RefCounted
## Projectile à tête chercheuse tiré par une tourelle.

var id := 0
var pos := Vector2.ZERO
var target_id := 0
var target_pos := Vector2.ZERO
var speed := 1.0
var damage := 0.0
var splash := 0.0
var slow_factor := 1.0
var slow_duration := 0.0
var owner := 0
var hits_air := true
var hits_ground := true

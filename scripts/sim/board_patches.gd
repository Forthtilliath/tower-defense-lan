class_name BoardPatches
extends RefCounted
## Nappes au sol laissées à l'impact par les tirs qui ont patch_radius (feu, nuage toxique).
## Toutes les TICK secondes, chaque monstre au sol dans la nappe subit patch_dps (qui ignore
## l'armure, mais pas la résistance à l'élément) et les effets du tir (ralentissement,
## poison…). Les volants et les monstres qui lévitent passent au-dessus.

const TICK := 0.5
const MAX_PATCHES := 40


## Pose une nappe là où le projectile p vient d'arriver (la plus ancienne disparaît s'il y en
## a trop).
static func add(b: SimBoard, p: SimProjectile) -> void:
	if b.patches.size() >= MAX_PATCHES:
		b.patches.pop_front()
	var duration := p.stat("patch_duration")
	b.patches.append({
		"pos": p.pos, "radius": p.stat("patch_radius"), "ttl": duration, "duration": duration,
		"tick": 0.0, "shot": p,
	})


static func update(b: SimBoard, dt: float, rewards: Array) -> void:
	var keep: Array[Dictionary] = []
	for z in b.patches:
		z["ttl"] -= dt
		z["tick"] += dt
		if z["tick"] >= TICK:
			z["tick"] -= TICK
			_burn(b, z, rewards)
		if z["ttl"] > 0.0:
			keep.append(z)
	b.patches = keep


static func _burn(b: SimBoard, z: Dictionary, rewards: Array) -> void:
	var p: SimProjectile = z["shot"]
	var r2: float = z["radius"] * z["radius"]
	var amount := p.stat("patch_dps") * TICK
	for m in b.monsters:
		if m.flying or m.hover or not BoardCombat.can_hit(p.hits_air, p.hits_ground, m) or m.pos.distance_squared_to(z["pos"]) > r2:
			continue
		BoardCombat.afflict(b, m, p)
		BoardCombat.damage(b, m, amount * m.taken(p.element), true, p.credit, rewards)


## Instantané : [[x, y, rayon, vie restante (0 à 1), index de la tourelle], ...]
static func snapshot(b: SimBoard) -> Array:
	var out := []
	for z in b.patches:
		var pos: Vector2 = z["pos"]
		var life: float = z["ttl"] / maxf(0.01, z["duration"])
		out.append([snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(z["radius"], 0.01), snappedf(clampf(life, 0.0, 1.0), 0.01), z["shot"].kind])
	return out

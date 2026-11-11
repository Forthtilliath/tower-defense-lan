class_name BoardAttacks
extends RefCounted
## Tirs instantanés, sans projectile :
## - pulse : onde qui frappe tous les monstres à portée de la tourelle ;
## - line : trait qui traverse tous les monstres alignés, jusqu'au bout de la portée ;
## - cone : souffle qui frappe tous les monstres à portée dans un cône tourné vers la cible ;
## - beam : rayon qui reste accroché à sa cible ; chaque coup d'affilée sur elle chauffe
##   davantage (dégâts × (1 + ramp × coups), plafonné à ramp_max).

## Demi-largeur du trait (cases) et demi-angle du cône (radians, cône de 100°).
const LINE_HALF_WIDTH := 0.4
const CONE_HALF_ANGLE := PI * 50.0 / 180.0


static func fire(b: SimBoard, t: SimTower, def: Dictionary, target: SimMonster, rewards: Array) -> void:
	match def["attack"]:
		"pulse":
			_pulse(b, t, def, rewards)
		"line":
			_line(b, t, def, target, rewards)
		"cone":
			_cone(b, t, def, target, rewards)
		"beam":
			_beam(b, t, def, target, rewards)


static func _pulse(b: SimBoard, t: SimTower, def: Dictionary, rewards: Array) -> void:
	var p := BoardCombat.shot(b, t, def)
	var reach := BoardAuras.reach(t)
	b.add_fx(SimBoard.Fx.WAVE, t.center, Vector2.ZERO, reach, p.kind)
	for m in BoardCombat.in_radius(b, p, t.center, reach):
		BoardCombat.hit(b, m, p, p.stat("damage"), rewards)


static func _line(b: SimBoard, t: SimTower, def: Dictionary, target: SimMonster, rewards: Array) -> void:
	var p := BoardCombat.shot(b, t, def)
	var dir := _direction(t, target)
	var end := t.center + dir * BoardAuras.reach(t)
	b.add_fx(SimBoard.Fx.BOLT, t.center, end)
	var hw2 := LINE_HALF_WIDTH * LINE_HALF_WIDTH
	for m in BoardCombat.in_radius(b, p, t.center, BoardAuras.reach(t) + LINE_HALF_WIDTH):
		var closest := Geometry2D.get_closest_point_to_segment(m.pos, t.center, end)
		if closest.distance_squared_to(m.pos) <= hw2:
			BoardCombat.hit(b, m, p, p.stat("damage"), rewards)


static func _cone(b: SimBoard, t: SimTower, def: Dictionary, target: SimMonster, rewards: Array) -> void:
	var p := BoardCombat.shot(b, t, def)
	var dir := _direction(t, target)
	var reach := BoardAuras.reach(t)
	b.add_fx(SimBoard.Fx.CONE, t.center, t.center + dir * reach)
	for m in BoardCombat.in_radius(b, p, t.center, reach):
		var to := m.pos - t.center
		if to.length_squared() < 0.0001 or absf(dir.angle_to(to)) <= CONE_HALF_ANGLE:
			BoardCombat.hit(b, m, p, p.stat("damage"), rewards)


static func _beam(b: SimBoard, t: SimTower, def: Dictionary, target: SimMonster, rewards: Array) -> void:
	var locked := b.monster_by_id(t.beam_target)
	var reach := BoardAuras.reach(t)
	if locked != null and BoardCombat.can_hit(def["air"], def["ground"], locked) \
			and t.center.distance_squared_to(locked.pos) <= reach * reach:
		target = locked
	else:
		t.beam_target = target.id
		t.heat = 0
	var p := BoardCombat.shot(b, t, def)
	var mult := minf(1.0 + p.stat("ramp") * t.heat, maxf(1.0, p.stat("ramp_max")))
	t.heat += 1
	b.add_fx(SimBoard.Fx.BEAM, t.center, target.pos)
	BoardCombat.hit(b, target, p, p.stat("damage") * mult, rewards)


static func _direction(t: SimTower, target: SimMonster) -> Vector2:
	var d := target.pos - t.center
	return d.normalized() if d.length_squared() > 0.0001 else Vector2.UP

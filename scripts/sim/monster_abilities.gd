class_name MonsterAbilities
extends RefCounted
## Capacités actives des monstres, jouées à chaque pas après les déplacements :
## - protection (ward) : chaque monstre reçoit la plus forte protection d'un protecteur voisin
##   (le protecteur lui-même n'en profite pas) : une part des dégâts qu'il subit est évitée ;
## - bond (blink) : toutes les blink_interval secondes, le monstre saute de blink_distance cases
##   le long de son chemin (l'horloge s'arrête pendant qu'il est étourdi ou apeuré) ;
## - brouillage (jam) : toutes les jam_interval secondes, les tourelles à jam_radius cases cessent
##   de tirer (et de donner leur aura) pendant jam_duration secondes, puis restent protégées
##   JAM_GUARD secondes, pour que plusieurs brouilleurs ne les éteignent pas pour de bon.
## Un monstre charmé n'use plus de ses capacités.

const JAM_GUARD := 2.0


static func update(b: SimBoard, dt: float) -> void:
	var auras_changed := _tick_towers(b, dt)
	_wards(b)
	for m in b.monsters:
		if not m.is_alive() or m.is_charmed():
			continue
		if m.blink_interval > 0.0:
			_blink(b, m, dt)
		if m.jam_interval > 0.0 and _jam(b, m, dt):
			auras_changed = true
	if auras_changed:
		BoardAuras.refresh(b)


## Le brouillage s'use. Vrai si une tourelle de soutien se remet en marche (auras à refaire).
static func _tick_towers(b: SimBoard, dt: float) -> bool:
	var changed := false
	for cell in b.towers:
		var t: SimTower = b.towers[cell]
		t.jam_guard = maxf(0.0, t.jam_guard - dt)
		if t.jammed > 0.0:
			t.jammed = maxf(0.0, t.jammed - dt)
			changed = changed or (t.support and t.jammed == 0.0)
	return changed


static func _wards(b: SimBoard) -> void:
	for m in b.monsters:
		m.warded = 0.0
	for w in b.monsters:
		if w.ward <= 0.0 or not w.is_alive() or w.is_charmed():
			continue
		var r2 := w.ward_radius * w.ward_radius
		for m in b.monsters:
			if m != w and m.pos.distance_squared_to(w.pos) <= r2:
				m.warded = maxf(m.warded, w.ward)


static func _blink(b: SimBoard, m: SimMonster, dt: float) -> void:
	if m.is_stunned() or m.is_feared():
		return
	m.blink_clock += dt * m.marks.ability_pace()
	if m.blink_clock < m.blink_interval:
		return
	m.blink_clock -= m.blink_interval
	var from := m.pos
	m.progress = minf(m.progress + m.blink_distance, m.length)
	m.pos = b.map.position_at(m.path, m.progress, m.flying)
	b.add_fx(SimBoard.Fx.BLINK, from, m.pos)


## Brouille les tourelles proches. Vrai si une tourelle de soutien s'éteint (auras à refaire).
static func _jam(b: SimBoard, m: SimMonster, dt: float) -> bool:
	if m.is_stunned():
		return false
	m.jam_clock += dt * m.marks.ability_pace()
	if m.jam_clock < m.jam_interval:
		return false
	m.jam_clock -= m.jam_interval
	var support_off := false
	var r2 := m.jam_radius * m.jam_radius
	for cell in b.towers:
		var t: SimTower = b.towers[cell]
		if t.jam_guard > 0.0 or t.buff("nojam") > 0.0 or t.center.distance_squared_to(m.pos) > r2:  # Fanfare
			continue
		support_off = support_off or t.support
		t.jammed = m.jam_duration
		t.jam_guard = m.jam_duration + JAM_GUARD
	b.add_fx(SimBoard.Fx.JAM, m.pos, Vector2.ZERO, m.jam_radius)
	return support_off

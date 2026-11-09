class_name UnitPainter
extends RefCounted
## Formes dessinées des unités : tourelles (8 silhouettes), monstres et leurs effets.


static func tower(ci: CanvasItem, data: GameData, t: Dictionary, center: Vector2, ts: float, owner_color: Color) -> void:
	var def: Dictionary = data.towers[t["type"]]
	var half := ts * 0.4
	var base := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
	ci.draw_rect(base, owner_color.darkened(0.45))
	ci.draw_rect(base, owner_color, false, maxf(2.0, ts * 0.05))
	if def["support"]:  # tourelle de soutien : socle rond
		ci.draw_arc(center, half * 0.95, 0.0, TAU, 24, Color(def["color"], 0.8), maxf(1.5, ts * 0.04))
	TowerGlyphs.draw(ci, t["type"], Color(def["color"]), center, ts * 0.24)
	var levels := int(t["level"]) + 1
	var step := ts * 0.15
	for l in levels:
		ci.draw_circle(base.position + Vector2(ts * 0.1 + l * step, ts * 0.7), maxf(1.8, ts * 0.045), UiTheme.GOLD)
	var buffs := int(t.get("buffs", 0))
	if buffs != 0:  # renforcée par une aura : petit chevron en haut à droite
		var p := base.position + Vector2(ts * 0.68, ts * 0.12)
		var k := ts * 0.08
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-k, k), p + Vector2(0, -k), p + Vector2(k, k)]), UiTheme.SUCCESS)


static func monster(ci: CanvasItem, def: Dictionary, m: Dictionary, pos: Vector2, ts: float) -> void:
	var r := ts * float(def["size"]) * 0.5
	var col := Color(def["color"])
	if m["slowed"]:
		col = col.lerp(Color("#9fdcff"), 0.55)
	if m["poisoned"]:
		col = col.lerp(Color("#8be04e"), 0.35)
	if m.get("burning", false):
		col = col.lerp(Color("#ff7a2f"), 0.4)
	if m.get("charmed", false):
		col = col.lerp(Color("#e070c0"), 0.55)
	if m.get("elite", false):  # vague spéciale : halo doré
		ci.draw_circle(pos, r * 1.45, Color(UiTheme.ACCENT, 0.18))
		ci.draw_arc(pos, r * 1.45, 0.0, TAU, 24, Color(UiTheme.ACCENT, 0.75), maxf(1.5, ts * 0.035))
	if def["heal_radius"] > 0.0:  # aura du soigneur
		ci.draw_circle(pos, def["heal_radius"] * ts, Color(0.85, 0.5, 0.9, 0.08))
		ci.draw_arc(pos, def["heal_radius"] * ts, 0.0, TAU, 32, Color(0.85, 0.5, 0.9, 0.3), 1.5)
	if m["flying"]:
		ci.draw_circle(pos + Vector2(0, r * 1.1), r * 0.55, Color(0, 0, 0, 0.25))
		var wing := col.darkened(0.25)
		ci.draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(-r * 1.7, -r * 0.6), pos + Vector2(-r * 0.9, r * 0.3)]), wing)
		ci.draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(r * 1.7, -r * 0.6), pos + Vector2(r * 0.9, r * 0.3)]), wing)
	ci.draw_circle(pos, r, col)
	var outline := maxf(1.5, ts * 0.03)
	if def["armor"] > 0.0:  # armure : contour épais métallique
		ci.draw_arc(pos, r, 0.0, TAU, 24, Color("#c9ced6"), outline * 2.2)
	else:
		ci.draw_arc(pos, r, 0.0, TAU, 20, col.darkened(0.45), outline)
	var eye := Vector2(r * 0.35, -r * 0.2)
	ci.draw_circle(pos - Vector2(eye.x, -eye.y), maxf(1.5, r * 0.17), Color.WHITE)
	ci.draw_circle(pos + eye, maxf(1.5, r * 0.17), Color.WHITE)
	if def["regen"] > 0.0:  # régénération : petite croix verte
		var k := maxf(2.0, r * 0.3)
		var p := pos + Vector2(r * 0.75, r * 0.6)
		ci.draw_line(p - Vector2(k, 0), p + Vector2(k, 0), UiTheme.SUCCESS, 2.0)
		ci.draw_line(p - Vector2(0, k), p + Vector2(0, k), UiTheme.SUCCESS, 2.0)
	if def["slow_immune"]:  # immunité (boss, golem) : couronne
		ci.draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-r * 0.6, -r * 0.9), pos + Vector2(-r * 0.6, -r * 1.35), pos + Vector2(-r * 0.25, -r * 1.1),
			pos + Vector2(0, -r * 1.45), pos + Vector2(r * 0.25, -r * 1.1), pos + Vector2(r * 0.6, -r * 1.35),
			pos + Vector2(r * 0.6, -r * 0.9)]), UiTheme.GOLD)
	_status(ci, m, pos, r, ts)
	var hp: int = m["hp"]
	if hp < 255:
		var w := maxf(ts * 0.6, r * 2.0)
		var bar := Rect2(pos + Vector2(-w / 2.0, -r - ts * 0.2), Vector2(w, maxf(3.0, ts * 0.07)))
		ci.draw_rect(bar, Color(0, 0, 0, 0.6))
		var k := hp / 255.0
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), UiTheme.DANGER.lerp(UiTheme.SUCCESS, k))


## Signes d'état au-dessus du monstre : étourdi (étoiles), peur (point d'exclamation),
## charmé (cœur), saignement (gouttes rouges).
static func _status(ci: CanvasItem, m: Dictionary, pos: Vector2, r: float, ts: float) -> void:
	var top := pos - Vector2(0, r + ts * 0.32)
	var k := maxf(2.0, ts * 0.07)
	if m.get("stunned", false):
		for i in 3:
			ci.draw_colored_polygon(TowerGlyphs.star(top + Vector2((i - 1) * k * 2.2, 0), k, k * 0.45, 4), UiTheme.GOLD)
	elif m.get("feared", false):
		ci.draw_line(top - Vector2(0, k * 1.6), top + Vector2(0, k * 0.4), Color("#c38bff"), maxf(2.0, k * 0.6))
		ci.draw_circle(top + Vector2(0, k * 1.1), k * 0.35, Color("#c38bff"))
	elif m.get("charmed", false):
		ci.draw_circle(top + Vector2(-k * 0.5, 0), k * 0.6, Color("#ff7ad0"))
		ci.draw_circle(top + Vector2(k * 0.5, 0), k * 0.6, Color("#ff7ad0"))
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-k * 1.05, k * 0.2), top + Vector2(0, k * 1.4), top + Vector2(k * 1.05, k * 0.2)]), Color("#ff7ad0"))
	if m.get("bleeding", false):
		ci.draw_circle(pos + Vector2(-r * 0.7, r * 0.6), maxf(1.5, k * 0.5), Color("#d0202a"))
		ci.draw_circle(pos + Vector2(-r * 0.4, r * 0.9), maxf(1.2, k * 0.4), Color("#d0202a"))


## Effets : onde d'explosion (zone) ou arc électrique (chaîne).
static func fx(ci: CanvasItem, f: Dictionary, origin: Vector2, ts: float) -> void:
	var life: float = f["life"]
	var pos: Vector2 = origin + f["pos"] * ts
	if f["kind"] == SimBoard.Fx.BOLT:
		var to: Vector2 = origin + f["to"] * ts
		var mid := (pos + to) / 2.0 + (to - pos).orthogonal().normalized() * ts * 0.15
		ci.draw_polyline(PackedVector2Array([pos, mid, to]), Color(0.7, 0.85, 1.0, life), maxf(2.0, ts * 0.06))
	else:
		var radius: float = f["radius"] * ts * (1.2 - 0.4 * life)
		ci.draw_arc(pos, radius, 0.0, TAU, 32, Color(1, 0.8, 0.4, life), 3.0)

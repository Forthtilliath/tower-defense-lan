class_name MonsterPainter
extends RefCounted
## Monstres au style manga : corps cerné d'encre en deux tons, ombre au sol, regard noir qui
## suit la marche, sourire à dents pour les gros, et leurs effets (états, barre de vie).
## Bonus : auras (soigneur, protecteur), image rémanente (bonds), lévitation, roues (véhicule),
## antenne (brouilleur), pastilles de résistance, bouclier doré quand un voisin le protège.

const STEEL := Color("#c9ced6")
const GRIN_SIZE := 0.6  # taille à partir de laquelle un monstre au sol montre les dents
const WARD := Color("#f2c94c")
const JAM := Color(1.0, 0.45, 0.25)
## Pastille de chaque résistance (feu, glace, foudre, tous les éléments, coups physiques).
const RESIST_COLORS := {
	"resist_fire": Color("#ff7a2f"), "resist_ice": Color("#9fdcff"),
	"resist_lightning": Color("#ffe14a"), "resist_elements": Color("#f4f0ff"),
	"resist_physical": Color("#b8c4d6"), "resist_pierce": Color("#c9b37a"), "resist_blunt": Color("#7d8590"),
	"resist_poison": Color("#8be04e"),
}


static func draw(ci: CanvasItem, def: Dictionary, m: Dictionary, pos: Vector2, facing: Vector2, ts: float) -> void:
	var r := ts * float(def["size"]) * 0.5
	var w := Ink.width(ts, 0.04)
	var col := _tint(Color(def["color"]), m)
	var t := Time.get_ticks_msec() / 1000.0
	if m.get("burrowed", false):  # enfoui : seulement un monticule de terre qui avance
		Ink.ellipse(ci, pos + Vector2(0, r * 0.4), r * 1.1, r * 0.45, Color("#6a4a2a"))
		Ink.ellipse(ci, pos + Vector2(-r * 0.2, r * 0.25), r * 0.4, r * 0.15, Color("#8a6a40"))
		return
	if def["resist_physical"] >= 1.0:  # intangible : corps translucide et traîne qui ondule
		col.a = 0.6
		var sway := sin(t * 4.0 + pos.x * 0.05) * r * 0.25
		ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-r * 0.8, r * 0.2), pos + Vector2(r * 0.8, r * 0.2),
			pos + Vector2(sway, r * 1.6)]), Color(col, 0.35))
	if m.get("elite", false):  # vague spéciale : aura crépitante
		Ink.poly(ci, Ink.burst(pos, r * 1.75, r * 1.3, 10, int(t * 8.0)), Color(UiTheme.ACCENT, 0.45), w)
	if def["heal_radius"] > 0.0:  # aura du soigneur
		_aura(ci, pos, def["heal_radius"] * ts, Color(0.85, 0.5, 0.9), w)
	if def["ward"] > 0.0:  # aura du protecteur
		_aura(ci, pos, def["ward_radius"] * ts, WARD, w)
	if def["blink_interval"] > 0.0:  # bondisseur : image rémanente derrière lui
		ci.draw_arc(pos - facing * r * 0.9, r * 0.85, 0.0, TAU, 16, Color(col, 0.35), w)
	if m["flying"]:
		Ink.ellipse(ci, pos + Vector2(0, r * 1.5), r * 0.7, r * 0.2, Color(Ink.INK, 0.25))
		pos.y += sin(t * 5.0 + pos.x * 0.05) * r * 0.12
		_wings(ci, pos, r, col.darkened(0.3), w, sin(t * 12.0 + pos.x * 0.05))
	elif def["hover"]:  # lévite : ombre détachée, flotte doucement
		Ink.ellipse(ci, pos + Vector2(0, r * 1.35), r * 0.6, r * 0.16, Color(Ink.INK, 0.2))
		pos.y += sin(t * 3.0 + pos.x * 0.05) * r * 0.15 - r * 0.25
	else:
		Ink.ellipse(ci, pos + Vector2(0, r * 0.85), r * 0.95, r * 0.28, Color(Ink.INK, 0.3))
	if def["mechanical"]:  # véhicule : deux roues sous la caisse
		for side in [-1.0, 1.0]:
			Ink.disc(ci, pos + Vector2(side * r * 0.62, r * 0.72), r * 0.34, Color("#3a3530"), w * 0.8)
			ci.draw_circle(pos + Vector2(side * r * 0.62, r * 0.72), r * 0.12, STEEL)
	if m.get("warded", false):  # protégé par un voisin : bouclier doré
		ci.draw_arc(pos, r * 1.25, -PI * 0.8, -PI * 0.2, 12, WARD, w * 1.6)
	Ink.disc(ci, pos, r, col, w)
	Ink.ellipse(ci, pos + Vector2(-r * 0.4, -r * 0.45), r * 0.2, r * 0.11, Color(1, 1, 1, 0.45))
	if def["armor"] > 0.0:  # casque d'acier
		ci.draw_arc(pos, r * 0.8, PI + 0.2, TAU - 0.2, 12, STEEL, r * 0.34)
		ci.draw_arc(pos, r * 0.62, PI + 0.2, TAU - 0.2, 12, Ink.INK, w * 0.8)
	_face(ci, def, m, pos, facing, r, w)
	if def["regen"] > 0.0:  # régénération : la chair fume (bouffées de vapeur qui montent)
		for k in 3:
			var phase := fposmod(t * 0.7 + k / 3.0 + pos.x * 0.013, 1.0)
			var p := pos + Vector2(r * (0.55 * (k - 1) + 0.25 * sin(t * 2.0 + k)), -r * (0.5 + 1.3 * phase))
			ci.draw_circle(p, maxf(2.0, r * (0.18 + 0.2 * phase)), Color(Ink.STEAM, 0.75 * (1.0 - phase)))
	if def["slow_immune"]:  # immunité (boss, golem) : couronne
		Ink.poly(ci, PackedVector2Array([
			pos + Vector2(-r * 0.6, -r * 0.9), pos + Vector2(-r * 0.6, -r * 1.35), pos + Vector2(-r * 0.25, -r * 1.1),
			pos + Vector2(0, -r * 1.45), pos + Vector2(r * 0.25, -r * 1.1), pos + Vector2(r * 0.6, -r * 1.35),
			pos + Vector2(r * 0.6, -r * 0.9)]), UiTheme.GOLD, w * 0.8)
	if def["jam_interval"] > 0.0:  # brouilleur : antenne qui grésille
		var tip := pos + Vector2(r * 0.45, -r * 1.5)
		ci.draw_line(pos + Vector2(r * 0.25, -r * 0.85), tip, Ink.INK, w)
		Ink.disc(ci, tip, maxf(1.5, r * 0.16), JAM if fmod(t, 0.6) < 0.3 else Ink.PAPER, w * 0.6)
	_resists(ci, def, pos, r, w)
	_status(ci, m, pos, r, ts, w)
	_hp_bar(ci, m["hp"], pos, r, ts)


static func _aura(ci: CanvasItem, pos: Vector2, radius: float, col: Color, w: float) -> void:
	ci.draw_circle(pos, radius, Color(col, 0.08))
	ci.draw_arc(pos, radius, 0.0, TAU, 32, Color(col, 0.35), w)


## Résistances : losanges colorés cernés d'encre, alignés en bas à droite du corps.
static func _resists(ci: CanvasItem, def: Dictionary, pos: Vector2, r: float, w: float) -> void:
	var k := maxf(3.5, r * 0.36)
	var at := pos + Vector2(r * 0.8 + k * 0.3, r * 0.5)
	for key in RESIST_COLORS:
		if def[key] <= 0.0:
			continue
		Ink.poly(ci, PackedVector2Array([at + Vector2(0, -k), at + Vector2(k, 0), at + Vector2(0, k), at + Vector2(-k, 0)]), RESIST_COLORS[key], w * 0.6)
		at.y -= k * 1.7


static func _tint(col: Color, m: Dictionary) -> Color:
	if m["slowed"]:
		col = col.lerp(Color("#9fdcff"), 0.55)
	if m["poisoned"]:
		col = col.lerp(Color("#8be04e"), 0.35)
	if m.get("burning", false):
		col = col.lerp(Color("#ff7a2f"), 0.4)
	if m.get("frostbitten", false):
		col = col.lerp(Color("#e8f6ff"), 0.45)
	if m.get("charmed", false):
		col = col.lerp(Color("#e070c0"), 0.55)
	return col


## Ailes de chauve-souris découpées, qui battent (flap entre -1 et 1).
static func _wings(ci: CanvasItem, pos: Vector2, r: float, col: Color, w: float, flap: float) -> void:
	var lift := r * (0.5 + 0.4 * flap)
	for side in [-1.0, 1.0]:
		Ink.poly(ci, PackedVector2Array([
			pos + Vector2(side * r * 0.4, -r * 0.2), pos + Vector2(side * r * 1.9, -lift - r * 0.3),
			pos + Vector2(side * r * 1.7, r * 0.15), pos + Vector2(side * r * 1.3, -r * 0.05),
			pos + Vector2(side * r * 1.0, r * 0.35), pos + Vector2(side * r * 0.4, r * 0.25)]), col, w)


## Yeux à pupille tournée vers la marche, sourcils froncés ; grand sourire à dents pour les gros.
static func _face(ci: CanvasItem, def: Dictionary, m: Dictionary, pos: Vector2, facing: Vector2, r: float, w: float) -> void:
	var grin: bool = float(def["size"]) >= GRIN_SIZE and not m["flying"]
	var er := maxf(1.5, r * (0.19 if grin else 0.24))
	var ey := -r * (0.28 if grin else 0.12)
	var detailed := r >= 6.0
	for side in [-1.0, 1.0]:
		var e := pos + Vector2(side * r * 0.36, ey)
		ci.draw_circle(e, er + w * 0.5, Ink.INK)
		ci.draw_circle(e, er, Ink.PAPER)
		ci.draw_circle(e + facing * er * 0.4, er * 0.5, Ink.INK)
		if detailed:
			ci.draw_line(e + Vector2(side * er * 1.4, -er * 1.7), e + Vector2(-side * er * 0.9, -er * 0.9), Ink.INK, w * 1.2)
	if not detailed:
		return
	if not grin:
		ci.draw_arc(pos + Vector2(0, r * 0.62), r * 0.24, PI * 1.25, PI * 1.75, 6, Ink.INK, w)
		return
	var mc := pos + Vector2(0, r * 0.12)
	var rx := r * 0.56
	var ry := r * 0.4
	var mouth := PackedVector2Array()
	for k in 9:
		var a := PI * k / 8.0
		mouth.append(mc + Vector2(cos(a) * rx, sin(a) * ry))
	Ink.poly(ci, mouth, Ink.PAPER, w)
	var jaw := ry * 0.45
	var jw := rx * sqrt(1.0 - 0.45 * 0.45)
	ci.draw_line(mc + Vector2(-jw, jaw), mc + Vector2(jw, jaw), Ink.INK, maxf(1.0, w * 0.7))
	for k in range(1, 6):
		var x := -rx + 2.0 * rx * k / 6.0
		ci.draw_line(mc + Vector2(x, 0), mc + Vector2(x, ry * sqrt(maxf(0.0, 1.0 - pow(x / rx, 2)))), Ink.INK, maxf(1.0, w * 0.6))


## Signes d'état au-dessus du monstre : étourdi (étoiles), peur (point d'exclamation),
## charmé (cœur), saignement (gouttes rouges), électrifié (éclair jaune), cloué au sol
## (flèches vers le bas).
static func _status(ci: CanvasItem, m: Dictionary, pos: Vector2, r: float, ts: float, w: float) -> void:
	var top := pos - Vector2(0, r + ts * 0.32)
	var k := maxf(2.0, ts * 0.07)
	if m.get("stunned", false):
		for i in 3:
			Ink.poly(ci, TowerGlyphs.star(top + Vector2((i - 1) * k * 2.2, 0), k, k * 0.45, 4), UiTheme.GOLD, w * 0.6)
	elif m.get("feared", false):
		ci.draw_line(top - Vector2(0, k * 1.6), top + Vector2(0, k * 0.4), Ink.INK, maxf(4.0, k))
		ci.draw_line(top - Vector2(0, k * 1.6), top + Vector2(0, k * 0.4), Color("#c38bff"), maxf(2.0, k * 0.6))
		Ink.disc(ci, top + Vector2(0, k * 1.1), k * 0.35, Color("#c38bff"), w * 0.6)
	elif m.get("charmed", false):
		ci.draw_circle(top + Vector2(-k * 0.5, 0), k * 0.6, Color("#ff7ad0"))
		ci.draw_circle(top + Vector2(k * 0.5, 0), k * 0.6, Color("#ff7ad0"))
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-k * 1.05, k * 0.2), top + Vector2(0, k * 1.4), top + Vector2(k * 1.05, k * 0.2)]), Color("#ff7ad0"))
	if m.get("bleeding", false):
		ci.draw_circle(pos + Vector2(-r * 0.7, r * 0.6), maxf(1.5, k * 0.5), Color("#d0202a"))
		ci.draw_circle(pos + Vector2(-r * 0.4, r * 0.9), maxf(1.2, k * 0.4), Color("#d0202a"))
	if m.get("shocked", false):
		var z := pos + Vector2(r * 0.85, -r * 0.4)
		var bolt := PackedVector2Array([z + Vector2(0, -k * 1.2), z + Vector2(-k * 0.6, 0), z + Vector2(k * 0.3, 0), z + Vector2(-k * 0.2, k * 1.2)])
		ci.draw_polyline(bolt, Ink.INK, maxf(3.0, k * 0.7))
		ci.draw_polyline(bolt, Color("#ffe84a"), maxf(1.5, k * 0.4))
	if m.get("grounded", false):
		for side in [-1.0, 1.0]:
			var a := pos + Vector2(side * r * 1.1, -r * 0.3)
			Ink.poly(ci, PackedVector2Array([a + Vector2(-k * 0.5, 0), a + Vector2(k * 0.5, 0), a + Vector2(0, k * 0.9)]), Color("#9fe0d0"), w * 0.5)


static func _hp_bar(ci: CanvasItem, hp: int, pos: Vector2, r: float, ts: float) -> void:
	if hp >= 255:
		return
	var w := maxf(ts * 0.6, r * 2.0)
	var bar := Rect2(pos + Vector2(-w / 2.0, -r - ts * 0.22), Vector2(w, maxf(3.0, ts * 0.07)))
	ci.draw_rect(bar.grow(1.5), Ink.INK)
	ci.draw_rect(bar, Color("#3a1414"))
	var k := hp / 255.0
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), UiTheme.DANGER.lerp(UiTheme.SUCCESS, k))

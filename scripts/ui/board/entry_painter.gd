class_name EntryPainter
extends RefCounted
## Entrées des monstres : par où arrivera la prochaine vague (cercle pulsant et chevrons qui
## filent le long du chemin), numéro de chaque départ numéroté, grisé quand rien n'en sortira.
## Le survol d'une entrée en détaille le contenu (WaveInfo).

const CHEVRONS := 3
const RUN := 2.6  # cases parcourues par les chevrons depuis l'entrée


## next_wave : n° de la prochaine vague (0 = première) ; lanes : chemins défendus (vide : tous).
static func draw(ci: CanvasItem, map: MapDef, next_wave: int, origin: Vector2, ts: float, font: Font, lanes: Array[int] = []) -> void:
	var coming := MapSpawns.wave_paths(map, next_wave)  # vide : tous les départs
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	var fs := maxi(8, int(ts * 0.42))
	for p in map.start_count():
		if not lanes.is_empty() and not lanes.has(p):
			continue  # couloir fermé
		var label: int = map.path_labels[p]
		var open := coming.is_empty() or coming.has(p)
		var center := origin + map.cell_center(MapSpawns.path_start(map, p)) * ts
		if open:
			_chevrons(ci, map, p, origin, ts, t)
			var radius := ts * (0.58 + 0.1 * pulse)
			ci.draw_arc(center, radius, 0.0, TAU, 32, Color(Ink.INK, 0.8), 6.0)
			ci.draw_arc(center, radius, 0.0, TAU, 32, Color(UiTheme.ACCENT, 0.65 + 0.35 * pulse), 3.5)
		if label == 0:
			continue
		var text := str(label)
		var at := center + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2.0, -ts * 0.55)
		ci.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(ts * 0.12)), Ink.INK)
		ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ink.PAPER if open else UiTheme.MUTED)


## Chevrons qui avancent depuis l'entrée le long du chemin au sol et s'estompent.
static func _chevrons(ci: CanvasItem, map: MapDef, path: int, origin: Vector2, ts: float, t: float) -> void:
	var length := minf(RUN, map.path_length(path, false))
	for k in CHEVRONS:
		var prog := fposmod(t * 1.3 + k * RUN / CHEVRONS, RUN)
		if prog > length:
			continue
		var pos := origin + map.position_at(path, prog, false) * ts
		var ahead := origin + map.position_at(path, prog + 0.1, false) * ts
		var dir := (ahead - pos).normalized()
		if dir == Vector2.ZERO:
			continue
		var side := Vector2(-dir.y, dir.x)
		var k2 := ts * 0.2
		var pts := PackedVector2Array([pos - dir * k2 + side * k2 * 1.2, pos + dir * k2, pos - dir * k2 - side * k2 * 1.2])
		var fade := 1.0 - prog / RUN
		ci.draw_polyline(pts, Color(Ink.INK, 0.8 * fade), maxf(4.0, ts * 0.13))
		ci.draw_polyline(pts, Color(UiTheme.ACCENT, fade), maxf(2.0, ts * 0.07))


## Texte des entrées d'une vague, ex. « Entrée : 2 » ou « Entrées : 1 et 3 » ("" sans entrées).
static func text(map: MapDef, wave: int) -> String:
	var open := MapSpawns.wave_entries(map, wave)
	if open == "":
		return ""
	if open.length() == 1:
		return "Entrée : " + open
	var parts := Array(open.split(""))
	return "Entrées : %s et %s" % [", ".join(parts.slice(0, -1)), parts[-1]]

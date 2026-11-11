class_name EntryPainter
extends RefCounted
## Entrées par vague : numéro de chaque départ numéroté, et cercle pulsant sur ceux par où
## arrivera la prochaine vague (pour placer ses tourelles à l'avance).


## next_wave : n° de la prochaine vague (0 = première).
static func draw(ci: CanvasItem, map: MapDef, next_wave: int, origin: Vector2, ts: float, font: Font) -> void:
	if map.entries.is_empty():
		return
	var open := MapSpawns.wave_entries(map, next_wave)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	var fs := maxi(8, int(ts * 0.42))
	for p in map.start_count():
		var label: int = map.path_labels[p]
		if label == 0:
			continue
		var center := origin + map.cell_center(MapSpawns.path_start(map, p)) * ts
		if open.contains(str(label)):
			ci.draw_arc(center, ts * (0.55 + 0.08 * pulse), 0.0, TAU, 32, Color(Ink.INK, 0.7), 5.0)
			ci.draw_arc(center, ts * (0.55 + 0.08 * pulse), 0.0, TAU, 32, Color(UiTheme.ACCENT, 0.6 + 0.4 * pulse), 3.0)
		var text := str(label)
		var at := center + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2.0, -ts * 0.5)
		ci.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(ts * 0.12)), Ink.INK)
		ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ink.PAPER if open.contains(text) else UiTheme.MUTED)


## Texte des entrées d'une vague, ex. « Entrée : 2 » ou « Entrées : 1 et 3 » ("" sans entrées).
static func text(map: MapDef, wave: int) -> String:
	var open := MapSpawns.wave_entries(map, wave)
	if open == "":
		return ""
	if open.length() == 1:
		return "Entrée : " + open
	var parts := Array(open.split(""))
	return "Entrées : %s et %s" % [", ".join(parts.slice(0, -1)), parts[-1]]

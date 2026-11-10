class_name MangaBackdrop
extends Control
## Fond des menus : lignes de vitesse rayonnantes façon planche de manga.
## Dessiné une seule fois (redessiné seulement si la fenêtre change de taille).

const RAYS := 72


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	var r0 := minf(size.x, size.y) * 0.34
	var r1 := size.length()
	for k in RAYS:
		var a := TAU * (k + 0.6 * Ink.noise(3, k)) / RAYS
		var spread := 0.006 + 0.012 * Ink.noise(5, k)
		var start := r0 * (1.0 + 0.5 * Ink.noise(9, k))
		var tri := PackedVector2Array([c + Vector2.from_angle(a) * start,
			c + Vector2.from_angle(a - spread) * r1, c + Vector2.from_angle(a + spread) * r1])
		draw_colored_polygon(tri, Color(UiTheme.PANEL_LIGHT, 0.55))

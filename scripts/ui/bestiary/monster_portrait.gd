class_name MonsterPortrait
extends Control
## Portrait d'un monstre (même dessin que sur le plateau), à l'échelle : les gros restent gros.

var _def: Dictionary


func _init(def: Dictionary, side := 76.0) -> void:
	_def = def
	custom_minimum_size = Vector2(side, side)
	clip_contents = true
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var side := minf(size.x, size.y)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Ink.INK, 0.25))
	var m := {"flying": _def["flying"], "hp": 255, "slowed": false, "poisoned": false}
	MonsterPainter.draw(self, _def, m, size / 2.0 + Vector2(0, side * 0.08), Vector2.RIGHT, side * 1.05)

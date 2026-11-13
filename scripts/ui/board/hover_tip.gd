class_name HoverTip
extends PanelContainer
## Bulle d'information du plateau (monstre ou entrée survolés) : suit la souris, se met à jour en
## continu et disparaît dès qu'il n'y a plus rien dessous (jamais de bulle vide).
## N'intercepte aucun clic.

const OFFSET := Vector2(18, 18)

var _label: Label


func _init() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL.darkened(0.2), 6, UiTheme.ACCENT))
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	_label = UiTheme.label("", 16)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_label)


## Affiche text près de at (coordonnées du parent), sans sortir de bounds ; texte vide : cache.
func show_at(text: String, at: Vector2, bounds: Vector2) -> void:
	if text == "":
		visible = false
		return
	if _label.text != text:
		_label.text = text
		reset_size()
	var pos := at + OFFSET
	if pos.x + size.x > bounds.x:
		pos.x = at.x - OFFSET.x - size.x
	if pos.y + size.y > bounds.y:
		pos.y = at.y - OFFSET.y - size.y
	position = pos.clamp(Vector2.ZERO, (bounds - size).max(Vector2.ZERO))
	visible = true

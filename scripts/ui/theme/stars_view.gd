class_name StarsView
extends RefCounted
## Étoiles d'une carte gagnée (0 à 3) : dorées si gagnées, éteintes sinon.

const STAR := "★"
const DIM := Color(0.45, 0.45, 0.5, 0.55)


## Rangée de trois étoiles (les étoiles gagnées en or).
static func row(count: int, size := 20) -> HBoxContainer:
	var h := UiTheme.hbox(1)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var l := UiTheme.label(STAR, size, UiTheme.GOLD if i < count else DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(l)
	return h


## « ★★ » : autant d'étoiles que gagnées (texte seul, pour une liste déroulante), "" si aucune.
static func text(count: int) -> String:
	return STAR.repeat(clampi(count, 0, 3))

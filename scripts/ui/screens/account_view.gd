class_name AccountView
extends RefCounted
## Affichage d'un compte : pseudo et niveau de chaque classe (liste « Continuer », compte reçu).


## Grille « Artilleur niv. 3 » des classes (en or au niveau maximum, estompée si jamais jouée).
static func levels(classes: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 2)
	var top_level := int(Data.db.progression["max_level"])
	for b in Data.db.builders:
		var xp := int(classes.get(b["id"], {}).get("xp", 0))
		var level := TalentRules.level_for(Data.db, xp)
		var color := UiTheme.GOLD if level >= top_level else (UiTheme.TEXT if xp > 0 else UiTheme.MUTED)
		var l := UiTheme.label("%s  niv. %d%s" % [b["name"], level, " ★" if level >= top_level else ""], 15, color)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
	return grid


## Pseudo (et une note à droite) au-dessus de la grille des niveaux.
static func summary(name: String, classes: Dictionary, note := "") -> VBoxContainer:
	var col := UiTheme.vbox(6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UiTheme.hbox(10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var title := UiTheme.label(name, 24, UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if note != "":
		var n := UiTheme.label(note, 14, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		top.add_child(n)
	col.add_child(levels(classes))
	return col

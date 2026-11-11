class_name HistoryRows
extends RefCounted
## Affichage d'une partie de l'historique (date, carte, résultat et étoiles, classe, coéquipiers)
## et noms lisibles des identifiants enregistrés (carte, classe ou difficulté retirée : l'identifiant).


static func game_row(g: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.slanted(UiTheme.PANEL_LIGHT))
	var row := UiTheme.hbox(18)
	card.add_child(row)
	var where := UiTheme.vbox(2)
	where.custom_minimum_size.x = 190
	row.add_child(where)
	where.add_child(UiTheme.label(date_text(g["t"]), 13, UiTheme.MUTED))
	where.add_child(UiTheme.label(map_name(g["map"]), 18, UiTheme.TEXT))
	where.add_child(UiTheme.label("%s · %s" % [difficulty_name(g["diff"]), "versus" if g["mode"] == "versus" else "coop"], 13, UiTheme.MUTED))
	var result := UiTheme.vbox(2)
	result.custom_minimum_size.x = 210
	row.add_child(result)
	var top := UiTheme.hbox(8)
	result.add_child(top)
	top.add_child(line("Victoire" if g["won"] else "Défaite", 18, UiTheme.SUCCESS if g["won"] else UiTheme.DANGER))
	if int(g["stars"]) > 0:
		top.add_child(StarsView.row(g["stars"], 18))
	var detail := "%d vies sur %d" % [g["lives"], g["start"]] if g["won"] and g["mode"] == "coop" \
		else "vague %d sur %d" % [g["wave"], g["waves"]]
	result.add_child(UiTheme.label(detail, 13, UiTheme.MUTED))
	var who := UiTheme.vbox(2)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(who)
	who.add_child(UiTheme.label("%s niv. %d · +%d XP" % [builder_name(g["class"]), g["lvl"], g["xp"]], 16, UiTheme.TEXT))
	who.add_child(UiTheme.label(team_text(g["team"]), 13, UiTheme.MUTED))
	return card


## Texte court sur une seule ligne (un libellé à retour automatique, dans une rangée, se
## réduirait à une lettre de large).
static func line(text: String, size: int, color: Color) -> Label:
	var l := UiTheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## « Avec Atthis (Support), Bob (Artilleur) » ou « Seul ».
static func team_text(team: Array) -> String:
	if team.is_empty():
		return "Seul"
	var parts := []
	for e in team:
		parts.append("%s (%s)" % [e[0], builder_name(e[1])])
	return "Avec " + ", ".join(parts)


## « 11/11/2026 14:32 » à l'heure locale de l'appareil.
static func date_text(t: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(t + bias * 60)
	return "%02d/%02d/%d %02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"]]


static func map_name(id: String) -> String:
	for m in Data.db.maps:
		if m.id == id:
			return m.name
	return id


static func difficulty_name(id: String) -> String:
	for d in Data.db.difficulties:
		if d["id"] == id:
			return d["name"]
	return id


## Nom de la classe (anciens identifiants de classe renommée compris, voir ProgressFile.LEGACY).
static func builder_name(id: String) -> String:
	var wanted: String = ProgressFile.LEGACY.get(id, id)
	for b in Data.db.builders:
		if b["id"] == wanted:
			return b["name"]
	return id

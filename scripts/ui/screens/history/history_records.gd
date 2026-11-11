class_name HistoryRecords
extends RefCounted
## Tableau des étoiles du compte : une ligne par carte (de la plus facile à la plus difficile),
## une colonne par difficulté.


static func grid(history: Dictionary) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 1 + Data.db.difficulties.size()
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6)
	g.add_child(HistoryRows.line("Carte", 13, UiTheme.MUTED))
	for d in Data.db.difficulties:
		g.add_child(_cell(HistoryRows.line(d["name"], 13, UiTheme.MUTED)))
	for i in MapDef.by_tier(Data.db.maps):
		g.add_child(HistoryRows.line(Data.db.maps[i].name, 15, UiTheme.TEXT))
		for d in Data.db.difficulties:
			g.add_child(_cell(StarsView.row(MatchHistory.best(history, Data.db.maps[i].id, d["id"]), 15)))
	return g


static func _cell(content: Control) -> Control:
	var c := CenterContainer.new()
	c.add_child(content)
	return c

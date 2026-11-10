class_name EndOverlay
extends ColorRect
## Fin de partie : résultat, retour au salon (hôte) ou au menu.

var _game: GameScreen
var _title: Label
var _detail: Label


func _init(game: GameScreen) -> void:
	_game = game
	color = Color(0, 0, 0, 0.6)
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 440
	center.add_child(panel)
	var box := UiTheme.vbox(16)
	panel.add_child(box)
	_title = UiTheme.label("", 40, UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)
	_detail = UiTheme.label("", 18, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_detail)
	if Net.is_host():
		box.add_child(UiTheme.button("Retour au salon", Net.return_to_lobby))
	else:
		box.add_child(UiTheme.label("L'hôte peut relancer une partie depuis le salon.", 16, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.button("Menu principal", _game.quit_game))


func show_result() -> void:
	if visible:
		return
	var s := _game.state
	match s.result:
		"victory":
			_title.text = "Victoire !"
			_title.add_theme_color_override("font_color", UiTheme.SUCCESS)
			_detail.text = "Toutes les vagues ont été repoussées, avec %d vies restantes." % int(s.boards[0]["lives"])
		"winner":
			var name: String = _game.names.get(s.winner, "?")
			_title.text = "Tu as gagné !" if s.winner == _game.my_id else "%s gagne !" % name
			_title.add_theme_color_override("font_color", UiTheme.SUCCESS if s.winner == _game.my_id else UiTheme.ACCENT)
			_detail.text = "Dernier survivant après %d vagues." % s.wave
		_:
			_title.text = "Défaite…"
			_title.add_theme_color_override("font_color", UiTheme.DANGER)
			_detail.text = "Les monstres sont passés à la vague %d." % s.wave
	if _game.xp_summary != "":
		_detail.text += "\n" + _game.xp_summary
	visible = true

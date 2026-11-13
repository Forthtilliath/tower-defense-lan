class_name GameMenu
extends ColorRect
## Menu de partie (bouton « Menu », Échap, retour d'Android) : reprendre, bestiaire, talents,
## recommencer (hôte), quitter. L'hôte qui l'ouvre met la partie en pause le temps de le
## consulter (sauf s'il l'avait déjà mise en pause lui-même).
## Gère aussi ce qui s'ouvre par-dessus la partie : talents, bestiaire, confirmations.

var _game: GameScreen
var _status: Label
var _paused_here := false
var _talents: TalentPanel
var _bestiary: BestiaryPanel
var _confirm_quit: ConfirmationDialog
var _confirm_restart: ConfirmationDialog


func _init(game: GameScreen) -> void:
	_game = game
	color = Color(0, 0, 0, 0.6)
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	center.add_child(panel)
	var box := UiTheme.vbox(12)
	panel.add_child(box)
	box.add_child(UiTheme.title("Menu", 40))
	_status = UiTheme.label("", 16, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_status)
	box.add_child(UiTheme.button("Reprendre", close))
	box.add_child(UiTheme.button("Bestiaire", open_bestiary))
	box.add_child(UiTheme.button("Talents", open_talents))
	if Net.is_host():
		box.add_child(UiTheme.button("Recommencer la partie", func() -> void: _confirm_restart.popup_centered()))
	box.add_child(UiTheme.button("Quitter la partie", ask_quit))
	_confirm_quit = _dialog("Quitter la partie", "Quitter la partie ?" +
		("\nTu es l'hôte : la partie s'arrêtera pour tout le monde." if Net.is_host() else ""), "Quitter", _game.quit_game)
	_confirm_restart = _dialog("Recommencer la partie", "Recommencer depuis la 1re vague, avec la même carte et les mêmes réglages ?" +
		"\nLa partie en cours est abandonnée (sans expérience).", "Recommencer", Net.restart_match)


## Fenêtre de confirmation, posée sur l'écran de partie (toujours visible, contrairement au menu).
func _dialog(title: String, text: String, ok: String, on_ok: Callable) -> ConfirmationDialog:
	var d := ConfirmationDialog.new()
	d.title = title
	d.dialog_text = text
	d.ok_button_text = ok
	d.cancel_button_text = "Annuler"
	d.confirmed.connect(on_ok)
	_game.add_child.call_deferred(d)
	return d


func open() -> void:
	if visible:
		return
	visible = true
	_paused_here = Net.is_host() and not _game.state.paused and not _game.state.ended
	if _paused_here:
		_game.send({"a": "pause", "on": true})
	if Net.is_host():
		_status.text = "Partie en pause."
	else:
		_status.text = "Seul l'hôte peut mettre en pause : la partie continue."


func close() -> void:
	if not visible:
		return
	visible = false
	if _paused_here:
		_game.send({"a": "pause", "on": false})
	_paused_here = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func ask_quit() -> void:
	_confirm_quit.popup_centered()


func open_bestiary() -> void:
	if _bestiary == null:
		_bestiary = BestiaryPanel.new(close_bestiary, _game.map.id)
		_game.add_child(_bestiary)


func close_bestiary() -> void:
	if _bestiary != null:
		_bestiary.queue_free()
		_bestiary = null


## Talents de la partie (ceux envoyés à l'hôte), sans pouvoir les changer ; la partie continue.
func open_talents() -> void:
	if _talents == null:
		_talents = TalentPanel.viewer(_game.my_kit(), NetPayloads.heritage_on(_game.config), close_talents)
		_game.add_child(_talents)


func close_talents() -> void:
	if _talents != null:
		_talents.queue_free()
		_talents = null


## Fin de partie : tout ce qui couvrirait le résultat se ferme.
func close_all() -> void:
	close_talents()
	close_bestiary()
	close()


## Retour (Android, Échap) : ferme la fenêtre du dessus. Renvoie false s'il n'y avait rien d'ouvert.
func back() -> bool:
	if _bestiary != null:
		close_bestiary()
	elif _talents != null:
		close_talents()
	elif visible:
		close()
	else:
		return false
	return true

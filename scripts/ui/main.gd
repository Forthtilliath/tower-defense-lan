extends Control
## Racine de l'application : affiche un écran à la fois (menu, rejoindre, salon, partie).

var _screen: Control
var _backdrop: MangaBackdrop


func _ready() -> void:
	theme = UiTheme.build()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	_backdrop = MangaBackdrop.new()
	add_child(_backdrop)
	Net.match_started.connect(show_game)
	Net.session_ended.connect(show_menu)
	Net.back_to_lobby.connect(show_lobby)
	if not Data.db.is_valid():
		show_menu("Données du jeu invalides : " + Data.db.error)
		return
	if _start_autotest():
		return
	show_menu()


func show_menu(message := "") -> void:
	_switch(MenuScreen.new(self, message))


func show_join() -> void:
	_switch(JoinScreen.new(self))


func show_lobby() -> void:
	_switch(LobbyScreen.new(self))


func show_game(config: Dictionary) -> void:
	_switch(GameScreen.new(self, config))


func _switch(screen: Control) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	_backdrop.visible = not (screen is GameScreen)  # pas de lignes de vitesse derrière le plateau
	add_child(screen)


## Bouton « retour » d'Android : délégué à l'écran courant.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _screen != null and _screen.has_method("go_back"):
		_screen.go_back()


## Tests automatisés (dossier tests/, absent des exports), uniquement avec
## « -- --autotest=host|client » ou « -- --screenshot=<dossier> ».
func _start_autotest() -> bool:
	for arg in OS.get_cmdline_user_args():
		var path := ""
		if arg.begins_with("--autotest="):
			path = "res://tests/net_smoke.gd"
		elif arg.begins_with("--screenshot="):
			path = "res://tests/screenshot.gd"
		if path == "" or not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		var node: Node = script.new()
		node.set("role", arg.trim_prefix("--autotest="))
		node.set("main", self)
		add_child(node)
		return true
	return false

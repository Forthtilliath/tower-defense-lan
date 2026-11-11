class_name LobbyScreen
extends MarginContainer
## Salon d'attente, en trois blocs : les joueurs (et la difficulté votée) à gauche ; à droite la
## partie (options de l'hôte, aperçu de la carte) puis tes propres choix (classe, talents, vote).
## En haut : comment rejoindre ; en bas : le lancement (hôte) ou l'attente (autres joueurs).

var _nav: Node
var _players: LobbyPlayers
var _game: LobbyGamePanel
var _me: LobbyMePanel
var _tree: TalentPanel
var _start: Button
var _hint: Label


func _init(nav: Node) -> void:
	_nav = nav
	set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 20)


func _ready() -> void:
	var root := UiTheme.vbox(12)
	add_child(root)
	root.add_child(_header())
	var body := UiTheme.hbox(14)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(body)
	_players = LobbyPlayers.new()
	_players.custom_minimum_size.x = 300
	body.add_child(_players)
	var right := UiTheme.vbox(12)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(right)
	_game = LobbyGamePanel.new()
	_game.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(_game)
	_me = LobbyMePanel.new(_open_talents)
	right.add_child(_me)
	root.add_child(_footer())
	Net.lobby_changed.connect(_refresh)
	Net.choose_kit(Progress.last_builder)
	_refresh()


func _header() -> Control:
	var top := UiTheme.hbox(16)
	var title := UiTheme.title("Salon", 34)
	top.add_child(title)
	var info := UiTheme.label(_address_text() if Net.is_host() else "Connecté au salon de l'hôte.", 15, UiTheme.MUTED)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(info)
	var quit := UiTheme.button("Quitter le salon", go_back, 46, false)
	quit.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(quit)
	return top


func _footer() -> Control:
	var bottom := UiTheme.hbox(16)
	_hint = UiTheme.label("", 16, UiTheme.MUTED)
	_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	_hint.size_flags_vertical = SIZE_SHRINK_CENTER
	bottom.add_child(_hint)
	_start = UiTheme.button("Lancer la partie", Net.start_match, 56, false)
	_start.custom_minimum_size.x = 340
	_start.visible = Net.is_host()
	bottom.add_child(_start)
	return bottom


func go_back() -> void:
	if _tree != null:
		_close_talents()
		return
	Net.leave()
	_nav.show_menu()


func _open_talents() -> void:
	_tree = TalentPanel.new(_my_builder(), func() -> void: Net.choose_kit(_my_builder()), _close_talents)
	add_child(_tree)


func _close_talents() -> void:
	if _tree != null:
		_tree.queue_free()
		_tree = null
	_refresh()


func _my_builder() -> int:
	return int(Net.players.get(Net.my_id(), {}).get("builder", Progress.last_builder))


func _refresh() -> void:
	var me := Net.my_id()
	_players.refresh(me)
	_game.refresh(_ordered_colors())
	_me.refresh(Net.players.get(me, {}))
	var map: MapDef = Data.db.maps[Net.settings["map"]]
	var hint := _hint_text(map, Net.settings["mode"] == SimMatch.Mode.COOP)
	_hint.text = hint[0]
	_hint.add_theme_color_override("font_color", UiTheme.GOLD if hint[1] else UiTheme.MUTED)


func _ordered_colors() -> Array[Color]:
	var out: Array[Color] = []
	for id in Net.ordered_ids():
		out.append(UiTheme.player_color(Net.players[id]["color"]))
	return out


## [texte, avertissement ?] affiché à côté du bouton de lancement.
func _hint_text(map: MapDef, coop: bool) -> Array:
	var n := Net.players.size()
	if not Net.is_host():
		return ["En attente du lancement par l'hôte…", false]
	if not coop and n < 2:
		return ["Le versus se joue à 2 ou plus (seul, c'est un entraînement).", true]
	if coop and n > map.max_players:
		return ["Carte un peu petite pour %d joueurs : essaie une carte conseillée jusqu'à 4." % n, true]
	if n == 1:
		return ["Tu peux jouer seul, ou attendre que d'autres te rejoignent.", false]
	return ["Tout le monde est là ? Lance quand vous êtes prêts.", false]


func _address_text() -> String:
	var ips := LanDiscovery.local_addresses()
	if ips.is_empty():
		return "Aucun réseau local détecté : connecte-toi au Wi-Fi pour qu'on te rejoigne."
	return "Pour te rejoindre : même Wi-Fi, puis « Rejoindre », ou l'IP %s" % " / ".join(ips)

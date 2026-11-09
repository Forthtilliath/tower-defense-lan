class_name LobbyScreen
extends MarginContainer
## Salon d'attente : joueurs connectés, choix du mode et de la carte (hôte), lancement.

const MODE_HELP := [
	"Une seule carte, vies communes. Chacun construit avec son or ; la prime d'un monstre va au propriétaire de la tourelle.",
	"Chacun son plateau. Envoie des monstres chez ton voisin pour augmenter ton revenu. Le dernier en vie gagne.",
]

var _nav: Node
var _players: VBoxContainer
var _count: Label
var _mode: OptionButton
var _map: OptionButton
var _difficulty: OptionButton
var _help: Label
var _preview: BoardView
var _start: Button
var _hint: Label


func _init(nav: Node) -> void:
	_nav = nav
	set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 24)


func _ready() -> void:
	var root := UiTheme.hbox(24)
	add_child(root)
	var left := UiTheme.vbox(12)
	left.custom_minimum_size.x = 340
	root.add_child(left)
	left.add_child(UiTheme.label("Salon", 36, UiTheme.ACCENT))
	_count = UiTheme.label("", 18, UiTheme.MUTED)
	left.add_child(_count)
	_players = UiTheme.vbox(8)
	_players.size_flags_horizontal = SIZE_EXPAND_FILL
	left.add_child(_players)
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_child(spacer)
	if Net.is_host():
		left.add_child(UiTheme.label(_address_text(), 18, UiTheme.TEXT))
	left.add_child(UiTheme.button("Quitter le salon", go_back))

	var right := UiTheme.vbox(12)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	root.add_child(right)
	var options := UiTheme.hbox(16)
	right.add_child(options)
	_mode = _option(options, "Mode", Net.MODE_NAMES)
	_mode.item_selected.connect(func(i: int) -> void: Net.set_option("mode", i))
	var map_names := []
	for m in Data.db.maps:
		map_names.append(m.name)
	_map = _option(options, "Carte", map_names)
	_map.item_selected.connect(func(i: int) -> void: Net.set_option("map", i))
	var difficulty_names := []
	for d in Data.db.difficulties:
		difficulty_names.append(d["name"])
	_difficulty = _option(options, "Difficulté", difficulty_names)
	_difficulty.item_selected.connect(func(i: int) -> void: Net.set_option("difficulty", i))
	_help = UiTheme.label("", 17, UiTheme.MUTED)
	right.add_child(_help)
	_preview = BoardView.new()
	_preview.data = Data.db
	_preview.mouse_filter = MOUSE_FILTER_IGNORE
	_preview.size_flags_vertical = SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(320, 180)
	right.add_child(_preview)
	_hint = UiTheme.label("", 17, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	right.add_child(_hint)
	_start = UiTheme.button("Lancer la partie", Net.start_match, 60)
	_start.visible = Net.is_host()
	right.add_child(_start)
	Net.lobby_changed.connect(_refresh)
	_refresh()


func go_back() -> void:
	Net.leave()
	_nav.show_menu()


func _option(parent: Control, title: String, items: Array) -> OptionButton:
	var col := UiTheme.vbox(4)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(col)
	col.add_child(UiTheme.label(title, 16, UiTheme.MUTED))
	var ob := OptionButton.new()
	ob.custom_minimum_size.y = 52
	for item in items:
		ob.add_item(item)
	ob.disabled = not Net.is_host()
	col.add_child(ob)
	return ob


func _refresh() -> void:
	UiTheme.clear(_players)
	var me := Net.my_id()
	for id in Net.ordered_ids():
		var p: Dictionary = Net.players[id]
		var row := UiTheme.hbox(10)
		var swatch := ColorRect.new()
		swatch.color = UiTheme.player_color(p["color"])
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var text: String = p["name"]
		if id == 1:
			text += "  (hôte)"
		if id == me:
			text += "  (toi)"
		var l := UiTheme.label(text, 20)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(l)
		_players.add_child(row)
	_count.text = "Joueurs : %d / %d" % [Net.players.size(), Net.MAX_PLAYERS]
	var mode: int = Net.settings["mode"]
	_mode.select(mode)
	_map.select(Net.settings["map"])
	_difficulty.select(Net.settings["difficulty"])
	var map: MapDef = Data.db.maps[Net.settings["map"]]
	_help.text = "%s\n%s · %d vagues · %s" % [MODE_HELP[mode], map.name, map.waves.size(), _difficulty_text(Net.settings["difficulty"])]
	_preview.set_map(Data.db.maps[Net.settings["map"]])
	if not Net.is_host():
		_hint.text = "En attente du lancement par l'hôte…"
	elif mode == SimMatch.Mode.VERSUS and Net.players.size() < 2:
		_hint.text = "Le versus se joue à 2 ou plus (seul, c'est un entraînement)."
	else:
		_hint.text = ""


## Résumé d'une difficulté : « Normal : 20 vies, monstres x1, or x1 ».
static func _difficulty_text(index: int) -> String:
	var d: Dictionary = Data.db.difficulties[index]
	return "%s : %d vies, PV des monstres x%s, or de départ x%s" % [
		d["name"], d["lives"], str(d["hp"]).replace(".", ","), str(d["gold"]).replace(".", ",")]


func _address_text() -> String:
	var ips := LanDiscovery.local_addresses()
	if ips.is_empty():
		return "Aucun réseau local détecté : connecte-toi au Wi-Fi."
	return "Pour rejoindre : même Wi-Fi, puis\n« Rejoindre » ou l'IP %s" % " / ".join(ips)

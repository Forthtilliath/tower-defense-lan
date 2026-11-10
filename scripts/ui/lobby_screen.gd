class_name LobbyScreen
extends MarginContainer
## Salon d'attente : joueurs connectés, options de la partie (hôte), bâtisseur et vote de
## difficulté de chacun, aperçu de la carte (zones comprises), lancement.

var _nav: Node
var _players: VBoxContainer
var _count: Label
var _mode: OptionButton
var _map: OptionButton
var _rhythm: OptionButton
var _launch: OptionButton
var _builder: OptionButton
var _talents: Button
var _tree: TalentPanel
var _vote: OptionButton
var _help: Label
var _mine: Label
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
	var left := UiTheme.vbox(10)
	left.custom_minimum_size.x = 320
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
		left.add_child(UiTheme.label(_address_text(), 17, UiTheme.TEXT))
	left.add_child(UiTheme.button("Quitter le salon", go_back))

	var right := UiTheme.vbox(10)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	root.add_child(right)
	var options := UiTheme.hbox(12)
	right.add_child(options)
	_mode = _option(options, "Mode", Net.MODE_NAMES, "mode", true)
	_map = _option(options, "Carte", Data.db.maps.map(func(m: MapDef) -> String: return m.name), "map", true)
	_rhythm = _option(options, "Rythme", SimMatch.RHYTHM_NAMES, "rhythm", true)
	_launch = _option(options, "Lancement", SimMatch.LAUNCH_NAMES, "launch", true)
	var mine := UiTheme.hbox(12)
	right.add_child(mine)
	_builder = _option(mine, "Ta classe", Data.db.builders.map(func(b: Dictionary) -> String: return b["name"]), "builder", false)
	var talents_col := UiTheme.vbox(4)
	talents_col.size_flags_horizontal = SIZE_EXPAND_FILL
	talents_col.add_child(UiTheme.label("Progression", 15, UiTheme.MUTED))
	_talents = UiTheme.button("Talents", _open_talents, 50, false)
	_talents.clip_text = true
	talents_col.add_child(_talents)
	mine.add_child(talents_col)
	_vote = _option(mine, "Ton vote : difficulté", Data.db.difficulties.map(func(d: Dictionary) -> String: return d["name"]), "vote", false)
	_help = UiTheme.label("", 15, UiTheme.MUTED)
	right.add_child(_help)
	_mine = UiTheme.label("", 15, UiTheme.TEXT)
	right.add_child(_mine)
	_preview = BoardView.new()
	_preview.data = Data.db
	_preview.mouse_filter = MOUSE_FILTER_IGNORE
	_preview.size_flags_vertical = SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(320, 140)
	right.add_child(_preview)
	_hint = UiTheme.label("", 16, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	right.add_child(_hint)
	_start = UiTheme.button("Lancer la partie", Net.start_match, 56)
	_start.visible = Net.is_host()
	right.add_child(_start)
	Net.lobby_changed.connect(_refresh)
	Net.choose_kit(Progress.last_builder)
	_refresh()


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


## Liste déroulante. host_option : option de partie (réservée à l'hôte), sinon choix personnel.
func _option(parent: Control, title: String, items: Array, key: String, host_option: bool) -> OptionButton:
	var col := UiTheme.vbox(4)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(col)
	col.add_child(UiTheme.label(title, 15, UiTheme.MUTED))
	var ob := OptionButton.new()
	ob.custom_minimum_size.y = 50
	ob.clip_text = true
	ob.fit_to_longest_item = false  # sinon la largeur suit le plus long nom de carte et déborde
	for item in items:
		ob.add_item(item)
	ob.disabled = host_option and not Net.is_host()
	if host_option:
		ob.item_selected.connect(func(i: int) -> void: Net.set_option(key, i))
	elif key == "builder":
		ob.item_selected.connect(func(i: int) -> void:
			Progress.set_last_builder(i)
			Net.choose_kit(i))
	else:
		ob.item_selected.connect(func(i: int) -> void: Net.choose(key, i))
	col.add_child(ob)
	return ob


func _refresh() -> void:
	var me := Net.my_id()
	_refresh_players(me)
	var s := Net.settings
	var coop: bool = s["mode"] == SimMatch.Mode.COOP
	_mode.select(s["mode"])
	_map.select(s["map"])
	_rhythm.select(s["rhythm"])
	_launch.select(s["launch"])
	_rhythm.get_parent().visible = coop
	_launch.get_parent().visible = coop
	var my: Dictionary = Net.players.get(me, {})
	var builder := int(my.get("builder", Progress.last_builder))
	_builder.select(builder)
	_vote.select(int(my.get("vote", 1)))
	var free := Progress.points_left(builder)
	_talents.text = "Niv. %d · talents%s" % [Progress.level(builder), (" (%d libre%s)" % [free, "s" if free > 1 else ""]) if free > 0 else ""]
	_help.text = LobbyTexts.help(s, Net.players.size())
	_mine.text = "%s\n%s" % [LobbyTexts.vote_text(Net.players), LobbyTexts.builder_text(int(my.get("builder", 0)))]
	var map: MapDef = Data.db.maps[s["map"]]
	_preview.set_map(map)
	_preview.zone_colors = BoardPainter.zone_colors(map, _ordered_colors()) if coop else []
	_hint.text = _hint_text(map, coop)


func _refresh_players(me: int) -> void:
	UiTheme.clear(_players)
	for id in Net.ordered_ids():
		var p: Dictionary = Net.players[id]
		var row := UiTheme.hbox(10)
		var swatch := ColorRect.new()
		swatch.color = UiTheme.player_color(p["color"])
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var col := UiTheme.vbox(0)
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		var text: String = p["name"]
		if id == 1:
			text += "  (hôte)"
		if id == me:
			text += "  (toi)"
		col.add_child(UiTheme.label(text, 19))
		var builder: Dictionary = Data.db.builders[int(p.get("builder", 0))]
		var vote: Dictionary = Data.db.difficulties[int(p.get("vote", 1))]
		col.add_child(UiTheme.label("%s niv. %d · vote %s" % [builder["name"], int(p.get("level", 1)), vote["name"]], 14, UiTheme.MUTED))
		row.add_child(col)
		_players.add_child(row)
	_count.text = "Joueurs : %d / %d" % [Net.players.size(), Net.MAX_PLAYERS]


func _ordered_colors() -> Array[Color]:
	var out: Array[Color] = []
	for id in Net.ordered_ids():
		out.append(UiTheme.player_color(Net.players[id]["color"]))
	return out


func _hint_text(map: MapDef, coop: bool) -> String:
	var n := Net.players.size()
	if not Net.is_host():
		return "En attente du lancement par l'hôte…"
	if not coop and n < 2:
		return "Le versus se joue à 2 ou plus (seul, c'est un entraînement)."
	if coop and n > map.max_players:
		return "Carte un peu petite pour %d joueurs : essaie une carte conseillée jusqu'à 4." % n
	return ""


func _address_text() -> String:
	var ips := LanDiscovery.local_addresses()
	if ips.is_empty():
		return "Aucun réseau local détecté : connecte-toi au Wi-Fi."
	return "Pour rejoindre : même Wi-Fi, puis\n« Rejoindre » ou l'IP %s" % " / ".join(ips)

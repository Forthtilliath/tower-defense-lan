class_name LobbyGamePanel
extends VBoxContainer
## Bloc « Partie » du salon : options réglées par l'hôte (mode, carte, rythme, lancement),
## résumé de ces choix et aperçu de la carte (zones des joueurs comprises).

var _mode: OptionButton
var _map: OptionButton
var _rhythm: OptionButton
var _launch: OptionButton
var _help: Label
var _preview: BoardView
var _map_text: Label


func _ready() -> void:
	var host := Net.is_host()
	var body := UiTheme.section(self, "Partie", "tu règles la partie" if host else "réglée par l'hôte")
	body.get_parent().size_flags_vertical = SIZE_EXPAND_FILL
	var row := UiTheme.hbox(16)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(row)
	var left := UiTheme.vbox(8)
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(left)
	var line1 := UiTheme.hbox(10)
	left.add_child(line1)
	_mode = _host_option(line1, "Mode", Net.MODE_NAMES, "mode")
	_map = _host_option(line1, "Carte", Data.db.maps.map(func(m: MapDef) -> String:
		return "%s (%s)" % [m.name, DataSchema.MAP_TIERS[m.tier]]), "map")
	var line2 := UiTheme.hbox(10)
	left.add_child(line2)
	_rhythm = _host_option(line2, "Rythme", SimMatch.RHYTHM_NAMES, "rhythm")
	_launch = _host_option(line2, "Lancement", SimMatch.LAUNCH_NAMES, "launch")
	_help = UiTheme.label("", 15, UiTheme.MUTED)
	left.add_child(_help)
	var right := UiTheme.vbox(6)
	right.custom_minimum_size.x = 380
	row.add_child(right)
	_preview = BoardView.new()
	_preview.data = Data.db
	_preview.mouse_filter = MOUSE_FILTER_IGNORE
	_preview.size_flags_vertical = SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(380, 170)
	right.add_child(_preview)
	_map_text = UiTheme.label("", 14, UiTheme.MUTED)
	right.add_child(_map_text)


func _host_option(parent: Control, heading: String, items: Array, key: String) -> OptionButton:
	var ob := UiTheme.option(parent, heading, items)
	ob.disabled = not Net.is_host()
	ob.item_selected.connect(func(i: int) -> void: Net.set_option(key, i))
	return ob


func refresh(colors: Array[Color]) -> void:
	var s := Net.settings
	var coop: bool = s["mode"] == SimMatch.Mode.COOP
	_mode.select(s["mode"])
	_map.select(s["map"])
	_rhythm.select(s["rhythm"])
	_launch.select(s["launch"])
	# En versus, rythme et lancement ne s'appliquent pas : désactivés plutôt que cachés (rien ne bouge).
	_rhythm.disabled = not coop or not Net.is_host()
	_launch.disabled = not coop or not Net.is_host()
	_mode.tooltip_text = LobbyTexts.MODE_HELP[s["mode"]]
	_rhythm.tooltip_text = LobbyTexts.RHYTHM_HELP[s["rhythm"]]
	_launch.tooltip_text = LobbyTexts.LAUNCH_HELP[s["launch"]]
	_help.text = LobbyTexts.short_help(s)
	var map: MapDef = Data.db.maps[s["map"]]
	_preview.set_map(map)
	var zones: Array[Color] = []  # liste typée : un [] nu ferait planter l'affectation (versus)
	if coop:
		zones = BoardPainter.zone_colors(map, colors)
	_preview.zone_colors = zones
	_map_text.text = LobbyTexts.map_text(map, s["mode"], Net.players.size())

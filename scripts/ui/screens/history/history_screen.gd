class_name HistoryScreen
extends MarginContainer
## Historique du compte ouvert : ses parties, de la plus récente à la plus ancienne, filtrées
## par classe jouée, coéquipier (ou seul), classe d'un coéquipier et carte, avec le bilan ;
## à droite, les étoiles gagnées sur chaque carte à chaque difficulté.

const ANYONE := 0
const SOLO := 1

var _nav: Node
var _games: Array = []
var _mates: Array[String] = []
var _class: OptionButton
var _mate: OptionButton
var _mate_class: OptionButton
var _map: OptionButton
var _summary: Label
var _list: VBoxContainer


func _init(nav: Node) -> void:
	_nav = nav
	set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 20)


func _ready() -> void:
	_games = Progress.history["games"]
	_mates = MatchHistory.mates(_games)
	var root := UiTheme.vbox(12)
	add_child(root)
	var top := UiTheme.hbox(16)
	root.add_child(top)
	var title := UiTheme.title("Historique", 34)
	top.add_child(title)
	var who := UiTheme.label(Progress.account_name, 18, UiTheme.MUTED)
	who.size_flags_horizontal = SIZE_EXPAND_FILL
	who.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(who)
	var back := UiTheme.button("Retour", go_back, 46, false)
	back.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(back)
	var body := UiTheme.hbox(14)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_games_block())
	var records := UiTheme.section(body, "Étoiles", "par carte")
	records.get_parent().size_flags_vertical = SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	records.add_child(scroll)
	scroll.add_child(HistoryRecords.grid(Progress.history))
	records.add_child(UiTheme.label("3 étoiles : 90 % des vies gardées ; 2 : la moitié ; 1 : victoire.", 13, UiTheme.MUTED))
	_rebuild()
	back.grab_focus.call_deferred()


func go_back() -> void:
	_nav.show_menu()


func _games_block() -> Control:
	var col := UiTheme.vbox(10)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	var body := UiTheme.section(col, "Parties", "les %d dernières" % MatchHistory.MAX_GAMES)
	body.get_parent().size_flags_vertical = SIZE_EXPAND_FILL
	var filters := UiTheme.hbox(10)
	body.add_child(filters)
	var classes := ["Toutes"] + Data.db.builders.map(func(b: Dictionary) -> String: return b["name"])
	_class = _filter(filters, "Ta classe", classes)
	_mate = _filter(filters, "Avec", ["Tout le monde", "Seul"] + _mates)
	_mate_class = _filter(filters, "Classe d'un coéquipier", classes)
	var maps := ["Toutes"]
	for i in MapDef.by_tier(Data.db.maps):
		maps.append(Data.db.maps[i].name)
	_map = _filter(filters, "Carte", maps)
	_summary = UiTheme.label("", 16, UiTheme.GOLD)
	body.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = UiTheme.vbox(8)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)
	return col


func _filter(parent: Control, heading: String, items: Array) -> OptionButton:
	var ob := UiTheme.option(parent, heading, items)
	ob.item_selected.connect(func(_i: int) -> void: _rebuild())
	return ob


## Filtres choisis, au format de MatchHistory.filter.
func _filters() -> Dictionary:
	var f := {}
	if _class.selected > 0:
		f["class"] = Data.db.builders[_class.selected - 1]["id"]
	if _mate.selected == SOLO:
		f["solo"] = true
	elif _mate.selected > SOLO:
		f["mate"] = _mates[_mate.selected - 2]
	if _mate_class.selected > 0:
		f["mate_class"] = Data.db.builders[_mate_class.selected - 1]["id"]
	if _map.selected > 0:
		f["map"] = Data.db.maps[MapDef.by_tier(Data.db.maps)[_map.selected - 1]].id
	return f


func _rebuild() -> void:
	UiTheme.clear(_list)
	var shown := MatchHistory.filter(_games, _filters())
	var s := MatchHistory.summary(shown)
	if _games.is_empty():
		_summary.text = "Aucune partie jouée avec ce compte pour l'instant."
	elif shown.is_empty():
		_summary.text = "Aucune partie ne correspond à ces filtres."
	else:
		_summary.text = "%d partie%s · %d victoire%s (%d %%)" % [s["count"], "s" if s["count"] > 1 else "",
			s["wins"], "s" if s["wins"] > 1 else "", roundi(100.0 * s["wins"] / s["count"])]
	for g in shown:
		_list.add_child(HistoryRows.game_row(g))

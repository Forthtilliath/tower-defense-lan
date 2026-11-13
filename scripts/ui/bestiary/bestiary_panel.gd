class_name BestiaryPanel
extends ColorRect
## Bestiaire : chaque monstre avec son portrait, ses caractéristiques de base, ses bonus et les
## cartes où on le croise. Filtre par carte (en partie : la carte jouée d'abord).
## Ouvert depuis le menu principal (écran entier) ou le menu de partie (par-dessus le plateau).

var _on_close: Callable
var _map_id := ""
var _filter: OptionButton
var _list: VBoxContainer
var _count: Label
var _filter_ids: Array[String] = []  # "" : tous les monstres


func _init(on_close: Callable, map_id := "") -> void:
	_on_close = on_close
	_map_id = map_id
	color = Color(UiTheme.BG, 0.97)
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP


func _ready() -> void:
	var data := Data.db
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var box := UiTheme.vbox(10)
	margin.add_child(box)
	var top := UiTheme.hbox(14)
	box.add_child(top)
	var title := UiTheme.title("Bestiaire", 34)
	top.add_child(title)
	_filter_ids.append("")
	var items := ["Tous les monstres"]
	for m in data.maps:
		_filter_ids.append(m.id)
		items.append("Carte : " + m.name)
	var col := UiTheme.vbox(0)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(col)
	_filter = UiTheme.option(col, "Monstres affichés", items)
	_filter.select(maxi(0, _filter_ids.find(_map_id)))
	_filter.item_selected.connect(func(_i: int) -> void: _fill())
	var close := UiTheme.button("Fermer", close_panel, 48, false)
	close.size_flags_vertical = SIZE_SHRINK_END
	top.add_child(close)
	_count = UiTheme.label("", 15, UiTheme.MUTED)
	box.add_child(_count)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = UiTheme.vbox(8)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_fill()


func _fill() -> void:
	var data := Data.db
	UiTheme.clear(_list)
	var map_id: String = _filter_ids[maxi(0, _filter.selected)]
	var where := BestiaryData.maps_by_monster(data)
	var parents := BestiaryData.parents(data)
	var shown := 0
	for id in data.monster_order:
		if map_id != "" and not where[id].has(map_id):
			continue
		_list.add_child(_card(data, id, where[id], parents.get(id, [])))
		shown += 1
	_count.text = "%d monstres. PV de base en Normal, avant le renfort des vagues (les dernières vagues sont bien plus solides)." % shown


func _card(data: GameData, id: String, maps: Array, born_from: Array) -> Control:
	var def: Dictionary = data.monsters[id]
	var panel := PanelContainer.new()
	var row := UiTheme.hbox(14)
	panel.add_child(row)
	var pic := MonsterPortrait.new(def)
	pic.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(pic)
	var col := UiTheme.vbox(3)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiTheme.label(def["name"], 21, UiTheme.ACCENT))
	col.add_child(UiTheme.label(MonsterText.stats_text(data, def), 16, UiTheme.TEXT))
	var traits := MonsterText.traits_text(def)
	traits = traits.left(1).to_upper() + traits.substr(1) if traits != "" else "Sans particularité."
	col.add_child(UiTheme.label(traits, 15, UiTheme.MUTED))
	var origin := []
	if not born_from.is_empty():
		origin.append("Naît de : " + ", ".join(born_from))
	if not maps.is_empty():
		origin.append("Cartes : " + BestiaryData.map_names(data, maps))
	if not origin.is_empty():
		col.add_child(UiTheme.label(" · ".join(origin), 14, UiTheme.MUTED.darkened(0.15)))
	return panel


func close_panel() -> void:
	if _on_close.is_valid():
		_on_close.call()


## Retour d'Android (en écran entier depuis le menu principal).
func go_back() -> void:
	close_panel()

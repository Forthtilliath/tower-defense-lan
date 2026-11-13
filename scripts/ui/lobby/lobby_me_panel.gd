class_name LobbyMePanel
extends VBoxContainer
## Bloc « Toi » du salon : classe, talents (niveau, points libres) et vote de difficulté,
## avec un résumé de la classe jouée (bonus, spécialisation, tourelles en plus, héritage).

var _on_talents: Callable
var _builder: OptionButton
var _talents: Button
var _vote: OptionButton
var _summary: Label
var _summary_width := 0.0  # largeur de la dernière mesure de la hauteur réservée


func _init(on_talents: Callable) -> void:
	_on_talents = on_talents


func _ready() -> void:
	var body := UiTheme.section(self, "Toi", Progress.account_name)
	var row := UiTheme.hbox(10)
	body.add_child(row)
	_builder = UiTheme.option(row, "Ta classe", Data.db.builders.map(func(b: Dictionary) -> String: return b["name"]))
	_builder.item_selected.connect(func(i: int) -> void:
		Progress.set_last_builder(i)
		Net.choose_kit(i))
	var col := UiTheme.vbox(4)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.add_child(UiTheme.label("Progression", 14, UiTheme.MUTED))
	_talents = UiTheme.button("Talents", _on_talents, 48, false)
	_talents.clip_text = true
	col.add_child(_talents)
	row.add_child(col)
	_vote = UiTheme.option(row, "Ton vote : difficulté", Data.db.difficulties.map(func(d: Dictionary) -> String: return d["name"]))
	_vote.item_selected.connect(func(i: int) -> void: Net.choose("vote", i))
	_summary = UiTheme.label("", 15, UiTheme.TEXT)
	body.add_child(_summary)
	# La largeur change les retours à la ligne : nouvelle mesure (pas pour un simple changement de hauteur).
	_summary.resized.connect(func() -> void:
		if not is_equal_approx(_summary.size.x, _summary_width):
			_reserve_lines())


func refresh(my: Dictionary) -> void:
	var builder := int(my.get("builder", Progress.last_builder))
	_builder.select(builder)
	_vote.select(int(my.get("vote", 1)))
	var free := Progress.points_left(builder)
	_talents.text = "Niv. %d · talents" % Progress.level(builder)
	if free > 0:
		_talents.text += " (%d libre%s)" % [free, "s" if free > 1 else ""]
	_talents.add_theme_color_override("font_color", UiTheme.GOLD if free > 0 else UiTheme.TEXT)
	_summary.text = LobbyTexts.builder_text(builder, NetPayloads.heritage_on(Net.settings))
	_reserve_lines()


## Même hauteur pour toutes les classes, spécialisation choisie ou non : le salon ne bouge pas
## d'une classe à l'autre. Lignes réellement affichées (retours à la ligne compris) du plus long
## résumé ; une classe sans spécialisation compte déjà la ligne « En plus du tronc commun ».
func _reserve_lines() -> void:
	if _summary.size.x <= 0.0:
		return
	_summary_width = _summary.size.x
	var shown := _summary.text
	var heritage := NetPayloads.heritage_on(Net.settings)
	var lines := 0
	for b in Data.db.builders.size():
		var text := LobbyTexts.builder_text(b, heritage)
		if PlayerKit.make(Data.db, b, Progress.talents(b)).spec < 0:
			text += "\nEn plus du tronc commun : deux tourelles de la spécialisation."
		_summary.text = text
		lines = maxi(lines, _summary.get_line_count())
	_summary.text = shown
	var spacing := _summary.get_theme_constant("line_spacing")
	_summary.custom_minimum_size.y = lines * _summary.get_line_height() + (lines - 1) * spacing

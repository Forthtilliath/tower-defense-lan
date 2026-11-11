class_name LobbyMePanel
extends VBoxContainer
## Bloc « Toi » du salon : classe, talents (niveau, points libres) et vote de difficulté,
## avec un résumé de la classe jouée (bonus, spécialisation, tourelles en plus, héritage).

var _on_talents: Callable
var _builder: OptionButton
var _talents: Button
var _vote: OptionButton
var _summary: Label


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


func refresh(my: Dictionary) -> void:
	var builder := int(my.get("builder", Progress.last_builder))
	_builder.select(builder)
	_vote.select(int(my.get("vote", 1)))
	var free := Progress.points_left(builder)
	_talents.text = "Niv. %d · talents" % Progress.level(builder)
	if free > 0:
		_talents.text += " (%d libre%s)" % [free, "s" if free > 1 else ""]
	_talents.add_theme_color_override("font_color", UiTheme.GOLD if free > 0 else UiTheme.TEXT)
	_summary.text = LobbyTexts.builder_text(builder)

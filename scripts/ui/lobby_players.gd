class_name LobbyPlayers
extends VBoxContainer
## Colonne « Joueurs » du salon : une carte par joueur (couleur, pseudo, classe, niveau, vote),
## les places libres, et la difficulté qui sera jouée d'après les votes.

var _count: Label
var _list: VBoxContainer
var _difficulty: Label
var _difficulty_detail: Label


func _init() -> void:
	add_theme_constant_override("separation", 12)


func _ready() -> void:
	var players := UiTheme.section(self, "Joueurs")
	players.get_parent().size_flags_vertical = SIZE_EXPAND_FILL
	_count = players.get_child(0).get_child(0)
	_list = UiTheme.vbox(8)
	players.add_child(_list)
	var vote := UiTheme.section(self, "Difficulté retenue")
	_difficulty = UiTheme.label("", 20, UiTheme.TEXT)
	vote.add_child(_difficulty)
	_difficulty_detail = UiTheme.label("", 14, UiTheme.MUTED)
	vote.add_child(_difficulty_detail)


func refresh(me: int) -> void:
	_count.text = "JOUEURS  %d / %d" % [Net.players.size(), Net.MAX_PLAYERS]
	UiTheme.clear(_list)
	for id in Net.ordered_ids():
		_list.add_child(_card(id, Net.players[id], me))
	for i in Net.MAX_PLAYERS - Net.players.size():
		var free := UiTheme.label("Place libre", 15, UiTheme.MUTED.darkened(0.3))
		free.custom_minimum_size.y = 30
		_list.add_child(free)
	var lines := LobbyTexts.vote_lines(Net.players)
	_difficulty.text = lines[0]
	_difficulty_detail.text = lines[1]


func _card(id: int, p: Dictionary, me: int) -> Control:
	var row := UiTheme.hbox(10)
	var bar := ColorRect.new()
	bar.color = UiTheme.player_color(p["color"])
	bar.custom_minimum_size = Vector2(6, 0)
	row.add_child(bar)
	var col := UiTheme.vbox(0)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(col)
	var top := UiTheme.hbox(8)
	col.add_child(top)
	var name := UiTheme.label(p["name"], 19, UiTheme.TEXT)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.clip_text = true
	name.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(name)
	var tags := []
	if id == 1:
		tags.append("hôte")
	if id == me:
		tags.append("toi")
	if not tags.is_empty():
		var tag := UiTheme.label(" · ".join(tags), 14, UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		top.add_child(tag)
	var kit := PlayerKit.make(Data.db, int(p.get("builder", 0)), p.get("talents", {}), p.get("heritage", []))
	col.add_child(UiTheme.label("%s · niv. %d" % [kit.title(Data.db), int(p.get("level", 1))], 14, UiTheme.MUTED))
	var vote: Dictionary = Data.db.difficulties[int(p.get("vote", 1))]
	col.add_child(UiTheme.label("Vote : %s" % vote["name"], 14, UiTheme.MUTED))
	return row

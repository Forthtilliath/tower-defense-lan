class_name CoopPanel
extends VBoxContainer
## Coopération : prochaine vague (spéciale ou non), intérêts à venir, alliés et dons d'or.
## Un don coûte cher : l'allié ne reçoit qu'une part du montant (gift_ratio).

const GIFTS := [20, 50]

var _game: GameScreen
var _next: Label
var _interest: Label
var _allies: Array = []  # [[id, label]]
var _gift_buttons: Array = []  # [[bouton, montant]]


func _init(game: GameScreen) -> void:
	_game = game
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = SIZE_EXPAND_FILL


func _ready() -> void:
	add_child(HSeparator.new())
	_next = UiTheme.label("", 16, UiTheme.MUTED)
	add_child(_next)
	_interest = UiTheme.label("", 16, UiTheme.GOLD)
	add_child(_interest)
	var data := _game.state.data
	var others := _game.order.filter(func(id: int) -> bool: return id != _game.my_id)
	if others.is_empty():
		return
	add_child(HSeparator.new())
	add_child(UiTheme.label("Alliés", 22, UiTheme.ACCENT))
	var kit := _game.my_kit()
	add_child(UiTheme.label("Un don coûte cher : ton allié reçoit %d %% du montant." % roundi(kit.gift_ratio(data) * 100.0), 15, UiTheme.MUTED))
	for id in others:
		var l := UiTheme.label("", 17, _game.colors[id])
		add_child(l)
		_allies.append([id, l])
		var row := UiTheme.hbox(8)
		add_child(row)
		var index: int = _game.order.find(id)
		for amount in GIFTS:
			var b := UiTheme.button("Donner %d → +%d" % [amount, MatchActions.gift_received(data, amount, kit)], func() -> void:
				_game.send({"a": "give", "to": index, "amount": amount}), 44, false)
			b.size_flags_horizontal = SIZE_EXPAND_FILL
			row.add_child(b)
			_gift_buttons.append([b, amount])


func refresh() -> void:
	var s := _game.state
	if not s.received:
		return
	var data := s.data
	if s.wave >= s.total:
		_next.text = "Dernière vague : tenez bon !"
	else:
		var mod := _game.wave_modifier(s.wave)
		_next.text = "Prochaine vague : %d / %d" % [s.wave + 1, s.total]
		var entries := EntryPainter.text(_game.map, s.wave)
		if entries != "":
			_next.text += " · " + entries
		if not mod.is_empty():
			_next.text += "\nVague spéciale « %s » : %s" % [mod["name"], mod["description"]]
		var ids: Array = _game.map.waves
		_next.text += "\n" + MonsterText.wave_text(data, data.waves[ids[mini(s.wave, ids.size() - 1)]])
		_next.add_theme_color_override("font_color", Color(mod["color"]) if not mod.is_empty() else UiTheme.MUTED)
	var gold := int(_game.me().get("gold", 0))
	var rule := _game.my_kit().interest_rule(data, _game.difficulty())
	if float(rule[0]) > 0.0:
		_interest.text = "Intérêts : +%d or à la prochaine vague (%s)" % [
			MatchFlow.interest(data, gold, _game.my_kit(), _game.difficulty()), MatchFlow.interest_text(rule)]
	for entry in _allies:
		var id: int = entry[0]
		var builder := int(_game.builders.get(id, 0))
		var l: Label = entry[1]
		l.text = "%s (%s) : %d or" % [_game.names[id], data.builders[builder]["name"], int(s.players.get(id, {}).get("gold", 0))]
	for entry in _gift_buttons:
		var b: Button = entry[0]
		b.disabled = gold < int(entry[1]) or int(entry[1]) < int(data.player["gift_min"])

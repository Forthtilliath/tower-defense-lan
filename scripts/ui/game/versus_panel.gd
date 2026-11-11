class_name VersusPanel
extends VBoxContainer
## Mode versus : envoi de monstres chez l'adversaire suivant, et liste des plateaux à observer.

var _game: GameScreen
var _target: Label
var _send_buttons: Array = []  # [[bouton, coût]]
var _boards: VBoxContainer


func _init(game: GameScreen) -> void:
	_game = game
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = SIZE_EXPAND_FILL


func _ready() -> void:
	add_child(HSeparator.new())
	add_child(UiTheme.label("Envoyer des monstres", 22, UiTheme.ACCENT))
	_target = UiTheme.label("", 16, UiTheme.MUTED)
	add_child(_target)
	var data := _game.state.data
	for id in data.sendable_monsters():
		var def: Dictionary = data.monsters[id]
		var index := data.monster_order.find(id)
		var b := UiTheme.button("%s — %d or (+%d revenu)" % [def["name"], def["send_cost"], def["income"]], func() -> void:
			_game.send({"a": "send", "monster": index}), 46)
		add_child(b)
		_send_buttons.append([b, def["send_cost"]])
	add_child(HSeparator.new())
	add_child(UiTheme.label("Plateaux", 22, UiTheme.ACCENT))
	_boards = UiTheme.vbox(6)
	add_child(_boards)


func refresh() -> void:
	var s := _game.state
	if not s.received:
		return
	var me := _game.me()
	var gold := int(me.get("gold", 0))
	var target := _next_opponent()
	_target.text = "Cible : %s" % _game.names.get(target, "aucune") if target != 0 else "Aucun adversaire en jeu"
	for entry in _send_buttons:
		var b: Button = entry[0]
		b.disabled = target == 0 or not me.get("alive", false) or gold < int(entry[1])
	UiTheme.clear(_boards)
	for i in _game.order.size():
		var id: int = _game.order[i]
		var board: Dictionary = s.boards[i]
		var row := UiTheme.hbox(8)
		var text := "%s : %d vies" % [_game.names[id], board["lives"]]
		if not board["alive"]:
			text = "%s : éliminé" % _game.names[id]
		var l := UiTheme.label(text, 17, _game.colors[id])
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(l)
		var index := i
		var b := UiTheme.button("Vu" if i == _game.viewed_board else ("Mon plateau" if id == _game.my_id else "Voir"), func() -> void:
			_game.view_board(index), 40, false)
		b.disabled = i == _game.viewed_board
		row.add_child(b)
		_boards.add_child(row)


## Même règle que l'hôte : prochain joueur encore en vie dans l'ordre de la partie.
func _next_opponent() -> int:
	var order := _game.order
	var start := order.find(_game.my_id)
	for k in range(1, order.size()):
		var other: int = order[(start + k) % order.size()]
		if _game.state.players.get(other, {}).get("alive", false):
			return other
	return 0

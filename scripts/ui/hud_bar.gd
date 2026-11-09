class_name HudBar
extends PanelContainer
## Barre du haut : or, vies, vague, compte à rebours, « lancer maintenant », vitesse, quitter.

var _game: GameScreen
var _gold: Label
var _lives: Label
var _wave: Label
var _timer: Label
var _ready_btn: Button
var _speed: Button


func _init(game: GameScreen) -> void:
	_game = game
	add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL.darkened(0.2), 0))


func _ready() -> void:
	var row := UiTheme.hbox(22)
	add_child(row)
	_gold = UiTheme.label("Or : -", 22, UiTheme.GOLD)
	_lives = UiTheme.label("Vies : -", 22, UiTheme.LIFE)
	_wave = UiTheme.label("Vague -", 22)
	_timer = UiTheme.label("", 18, UiTheme.MUTED)
	for l in [_gold, _lives, _wave, _timer]:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(spacer)
	_ready_btn = UiTheme.button("Lancer maintenant", func() -> void: _game.send({"a": "ready"}), 48, false)
	_ready_btn.visible = false
	row.add_child(_ready_btn)
	if Net.is_host():
		_speed = UiTheme.button("Vitesse x1", func() -> void: _game.send({"a": "speed"}), 48, false)
		row.add_child(_speed)
	row.add_child(UiTheme.button("Quitter", _game.ask_quit, 48, false))


func refresh() -> void:
	var s := _game.state
	var me := _game.me()
	_gold.text = "Or : %d" % int(me.get("gold", 0))
	if _game.is_versus:
		_gold.text += "  (+%d/vague)" % (SimMatch.VERSUS_BASE_INCOME + int(me.get("income", 0)))
	var own: Dictionary = s.boards[_game.my_board]
	_lives.text = "Vies : %d" % int(own["lives"])
	if s.wave > s.total:
		_wave.text = "Vague %d (mort subite)" % s.wave
	else:
		_wave.text = "Vague %d / %d" % [s.wave, s.total]
	var waiting := s.countdown >= 0.0 and not s.ended
	_timer.text = ("Prochaine vague : %d s" % ceili(s.countdown)) if waiting else ""
	_ready_btn.visible = waiting and bool(me.get("alive", false))
	if waiting:
		var ready_count := 0
		var total := 0
		for id in s.players:
			if s.players[id]["alive"]:
				total += 1
				if s.players[id]["ready"]:
					ready_count += 1
		var bonus := int(s.countdown)
		if me.get("ready", false):
			_ready_btn.text = "Prêt (%d/%d)" % [ready_count, total]
		elif total > 1:
			_ready_btn.text = "Prêt ! +%d or (%d/%d)" % [bonus, ready_count, total]
		else:
			_ready_btn.text = "Lancer maintenant (+%d or)" % bonus
		_ready_btn.disabled = me.get("ready", false)
	if _speed != null:
		_speed.text = "Vitesse x%d" % s.speed

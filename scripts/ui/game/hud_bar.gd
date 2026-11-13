class_name HudBar
extends PanelContainer
## Barre du haut : or, vies, vague, compte à rebours, « lancer maintenant », vitesse et pause
## (hôte), menu (bestiaire, talents, recommencer, quitter).

var _game: GameScreen
var _gold: Label
var _lives: Label
var _wave: Label
var _timer: Label
var _ready_btn: Button
var _speed: Button
var _pause: Button


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
	# Le message prend la place libre et se coupe (« … ») plutôt que d'élargir tout l'écran
	_timer.clip_text = true
	_timer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_timer.size_flags_horizontal = SIZE_EXPAND_FILL
	_ready_btn = UiTheme.button("Lancer maintenant", func() -> void: _game.send({"a": "ready"}), 48, false)
	_ready_btn.visible = false
	row.add_child(_ready_btn)
	if Net.is_host():
		_speed = UiTheme.button("Vitesse x1", func() -> void: _game.send({"a": "speed"}), 48, false)
		row.add_child(_speed)
		_pause = UiTheme.button("Pause", _game.toggle_pause, 48, false)
		_pause.tooltip_text = "Pause (touche P ou Espace)"
		row.add_child(_pause)
	var menu := UiTheme.button("Menu", _game.open_menu, 48, false)
	menu.tooltip_text = "Bestiaire, talents, recommencer, quitter (touche Échap)"
	row.add_child(menu)


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
	_wave.text += "  ·  " + _game.difficulty_name()
	_timer.text = _timer_text(s)
	var can_launch := not _game.host_launches() or _game.my_id == _game.order[0]
	_ready_btn.visible = s.can_call and bool(me.get("alive", false)) and can_launch
	if _ready_btn.visible:
		_ready_btn.text = _ready_text(s, me)
		_ready_btn.disabled = me.get("ready", false)
	if _speed != null:
		_speed.text = "Vitesse x%d" % s.speed
	if _pause != null:
		_pause.text = "Reprendre" if s.paused else "Pause"
		_pause.disabled = s.ended


func _timer_text(s: ViewState) -> String:
	if s.ended:
		return ""
	if s.paused:
		return "En pause" + ("" if Net.is_host() else " (par l'hôte)")
	if s.wave == 0:
		if _game.host_launches() and _game.my_id != _game.order[0]:
			return "L'hôte lancera la 1re vague"
		return "Construisez, puis lancez"
	var text := ""
	if s.countdown >= 0.0:
		var label := "Construction" if _game.rhythm() == SimMatch.Rhythm.BETWEEN else "Prochaine vague"
		text = "%s : %d s" % [label, ceili(s.countdown)]
		var mod := _game.wave_modifier(s.wave)
		if not mod.is_empty():
			text += " (%s)" % mod["name"]
	elif _game.rhythm() == SimMatch.Rhythm.BETWEEN:
		text = "Vague en cours : construction bloquée"
	return text


## Bonus : secondes restantes, ou tout le compte à rebours si la vague est appelée en pleine vague.
func _ready_text(s: ViewState, me: Dictionary) -> String:
	var bonus := int(s.countdown) if s.countdown >= 0.0 else int(SimMatch.BETWEEN_WAVES)
	var first := s.wave == 0
	if _game.host_launches():
		return "Lancer la 1re vague" if first else "Vague suivante (+%d or)" % bonus
	var ready_count := 0
	var total := 0
	for id in s.players:
		if s.players[id]["alive"]:
			total += 1
			if s.players[id]["ready"]:
				ready_count += 1
	if me.get("ready", false):
		return "Prêt (%d/%d)" % [ready_count, total]
	if first:
		return "Prêt ! (%d/%d)" % [ready_count, total] if total > 1 else "Lancer la 1re vague"
	if total > 1:
		return "Prêt ! +%d or (%d/%d)" % [bonus, ready_count, total]
	return "Vague suivante (+%d or)" % bonus

class_name SidePanel
extends VBoxContainer
## Panneau contextuel : construire sur une case libre, ou gérer la tourelle sélectionnée.
## Reconstruit seulement quand le contexte change ; l'or ne fait que (dés)activer les boutons.

## Affichage des descriptions détaillées des tourelles (gardé pour toute la session).
static var show_details := false

var _game: GameScreen
var _selected := -1
var _signature := ""
var _priced: Array = []  # [[bouton, coût, toujours désactivé]]


func _init(game: GameScreen) -> void:
	_game = game
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = SIZE_EXPAND_FILL


func set_selected(cell: int) -> void:
	_selected = cell
	refresh(true)


func refresh(force := false) -> void:
	if not _game.state.received:
		return
	var sig := _context()
	if force or sig != _signature:
		_signature = sig
		_rebuild()
	var gold := int(_game.me().get("gold", 0))
	for entry in _priced:
		var b: Button = entry[0]
		b.disabled = entry[2] or gold < int(entry[1])


func _context() -> String:
	var b := _game.viewed()
	var t: Variant = b.get("towers", {}).get(_selected)
	var tower_sig := "" if t == null else "%s/%d/%d" % [t["type"], t["level"], t["mode"]]
	return "%d|%d|%s|%s|%s" % [_game.viewed_board, _selected, tower_sig, str(_game.me().get("alive", false)), str(show_details)]


func _rebuild() -> void:
	UiTheme.clear(self)
	_priced.clear()
	var b := _game.viewed()
	var t: Variant = b.get("towers", {}).get(_selected)
	if _game.viewed_board != _game.my_board:
		var owner: int = _game.player_on_board(_game.viewed_board)
		add_child(UiTheme.label("Plateau de %s" % _game.names.get(owner, "?"), 24, UiTheme.ACCENT))
		add_child(UiTheme.label("Tu observes ce plateau. Reviens au tien pour construire.", 17, UiTheme.MUTED))
	elif not _game.me().get("alive", false) and _game.is_versus:
		add_child(UiTheme.label("Tu as été éliminé.", 22, UiTheme.DANGER))
	elif t != null:
		_tower_panel(t)
	elif _game.map.is_buildable(_selected):
		_build_panel()
	elif _selected >= 0:
		add_child(UiTheme.label("On ne peut pas construire ici.", 18, UiTheme.MUTED))
	else:
		add_child(UiTheme.label("Construire", 24, UiTheme.ACCENT))
		add_child(UiTheme.label("Touche une case d'herbe libre pour y poser une tourelle, ou une tourelle pour l'améliorer.", 17, UiTheme.MUTED))
		add_child(UiTheme.label("Les cases encadrées donnent un bonus. Les pointillés montrent la route des volants.", 16, UiTheme.MUTED))


func _build_panel() -> void:
	add_child(UiTheme.label("Construire", 24, UiTheme.ACCENT))
	_special_info()
	var data := _game.state.data
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for i in data.tower_order.size():
		var def: Dictionary = data.towers[data.tower_order[i]]
		var cost: int = def["levels"][0]["cost"]
		var index := i
		var b := UiTheme.button("%s\n%d or" % [def["name"], cost], func() -> void:
			_game.send({"a": "build", "cell": _selected, "tower": index}), 62, false)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.add_theme_color_override("font_color", Color(def["color"]).lightened(0.35))
		grid.add_child(b)
		_priced.append([b, cost, false])
	var toggle := CheckButton.new()
	toggle.text = "Détails des tourelles"
	toggle.button_pressed = show_details
	toggle.toggled.connect(func(on: bool) -> void:
		show_details = on
		refresh(true))
	add_child(toggle)
	if show_details:
		var special := _game.map.special_at(_selected)
		for id in data.tower_order:
			var def: Dictionary = data.towers[id]
			add_child(UiTheme.label(def["name"], 17, Color(def["color"]).lightened(0.35)))
			add_child(UiTheme.label("%s\n%s" % [def["description"], stats_text(def, data.tower_stats(id, 0, special))], 15, UiTheme.MUTED))


func _tower_panel(t: Dictionary) -> void:
	var data := _game.state.data
	var def: Dictionary = data.towers[t["type"]]
	var levels: Array = def["levels"]
	var level: int = t["level"]
	var special := _game.map.special_at(_selected)
	add_child(UiTheme.label("%s — niveau %d / %d" % [def["name"], level + 1, levels.size()], 24, UiTheme.ACCENT))
	var owner: int = t["owner"]
	add_child(UiTheme.label("Propriétaire : %s" % _game.names.get(owner, "?"), 17, _game.colors.get(owner, UiTheme.TEXT)))
	_special_info()
	add_child(UiTheme.label(stats_text(def, data.tower_stats(t["type"], level, special)), 16, UiTheme.MUTED))
	if owner != _game.my_id:
		add_child(UiTheme.label("Seul son propriétaire peut l'améliorer ou la vendre.", 16, UiTheme.MUTED))
		return
	if level + 1 < levels.size():
		var next_cost: int = levels[level + 1]["cost"]
		var up := UiTheme.button("Améliorer — %d or" % next_cost, func() -> void:
			_game.send({"a": "upgrade", "cell": _selected}))
		add_child(up)
		_priced.append([up, next_cost, false])
		add_child(UiTheme.label("Niveau suivant : " + stats_text(def, data.tower_stats(t["type"], level + 1, special)), 15, UiTheme.MUTED))
	else:
		add_child(UiTheme.label("Niveau maximum atteint.", 16, UiTheme.SUCCESS))
	add_child(UiTheme.button("Cible : %s" % SimTower.TARGET_NAMES[t["mode"]], func() -> void:
		_game.send({"a": "mode", "cell": _selected})))
	var refund := int(data.tower_invested(t["type"], level) * SimMatch.SELL_RATIO)
	add_child(UiTheme.button("Vendre (+%d or)" % refund, func() -> void:
		_game.send({"a": "sell", "cell": _selected})))


## Bonus de la case sélectionnée, s'il y en a un.
func _special_info() -> void:
	var special := _game.map.special_at(_selected)
	if special < 0:
		return
	var s: Dictionary = _game.state.data.specials[special]
	add_child(UiTheme.label("%s : %s" % [s["name"], s["description"]], 16, Color(s["color"])))


static func stats_text(def: Dictionary, s: Dictionary) -> String:
	var parts := ["Dégâts %s" % _num(s["damage"]), "portée %s" % _num(s["range"]), "%s tir/s" % _num(s["rate"])]
	if s["splash"] > 0.0:
		parts.append("zone %s" % _num(s["splash"]))
	if s["slow_factor"] < 1.0:
		parts.append("ralentit de %d %% (%s s)" % [roundi((1.0 - s["slow_factor"]) * 100.0), _num(s["slow_duration"])])
	if s["chain"] > 0:
		parts.append("%d rebonds" % s["chain"])
	if s["poison_dps"] > 0.0:
		parts.append("poison %s/s pendant %s s" % [_num(s["poison_dps"]), _num(s["poison_duration"])])
	parts.append("air et sol" if def["air"] and def["ground"] else ("sol" if def["ground"] else "air"))
	return " · ".join(parts)


static func _num(v: float) -> String:
	return str(snappedf(v, 0.01)).replace(".", ",")

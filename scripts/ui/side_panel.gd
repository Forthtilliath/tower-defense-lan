class_name SidePanel
extends VBoxContainer
## Panneau contextuel : construire sur une case libre, ou gérer la tourelle sélectionnée.
## Reconstruit seulement quand le contexte change ; l'or ne fait que (dés)activer les boutons.

var _game: GameScreen
## Tourelle dont la fiche est affichée avant construction (gardée d'une case à l'autre).
var _previewed := ""
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
	var tower_sig := "" if t == null else "%s/%d/%d/%d" % [t["type"], t["level"], t["mode"], t.get("buffs", 0)]
	return "%d|%d|%s|%s|%s|%s" % [_game.viewed_board, _selected, tower_sig, str(_game.me().get("alive", false)), _previewed, str(_game.state.can_trade)]


func _rebuild() -> void:
	UiTheme.clear(self)
	_priced.clear()
	_game.preview_range(0.0)
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
		var owners := _zone_owners(_game.map.zone_at(_selected))
		if owners.is_empty() or owners.has(_game.my_id):
			_build_panel()
		else:
			var who := " / ".join(owners.map(func(id: int) -> String: return _game.names.get(id, "?")))
			add_child(UiTheme.label("Zone de %s" % who, 22, _game.colors.get(owners[0], UiTheme.TEXT)))
			add_child(UiTheme.label("Seul le propriétaire de la zone peut y construire. Ta zone a ta couleur.", 17, UiTheme.MUTED))
	elif _selected >= 0:
		add_child(UiTheme.label("On ne peut pas construire ici.", 18, UiTheme.MUTED))
	else:
		add_child(UiTheme.label("Construire", 24, UiTheme.ACCENT))
		add_child(UiTheme.label("Touche une case d'herbe libre pour y poser une tourelle, ou une tourelle pour l'améliorer.", 17, UiTheme.MUTED))
		add_child(UiTheme.label("Les cases encadrées donnent un bonus. Les pointillés montrent la route des volants.", 16, UiTheme.MUTED))
		if _game.map.zone_count > 0 and not _game.is_versus:
			add_child(UiTheme.label("Les cases teintées sont des zones de joueur : chacun construit dans la sienne.", 16, UiTheme.MUTED))


## Joueurs autorisés à construire dans une zone (vide : case commune).
func _zone_owners(zone: int) -> Array[int]:
	var out: Array[int] = []
	if zone < 0 or _game.is_versus:
		return out
	var n := _game.order.size()
	for i in n:
		if _game.map.zone_allows(zone, i, n):
			out.append(_game.order[i])
	return out


func _build_panel() -> void:
	add_child(UiTheme.label("Construire", 24, UiTheme.ACCENT))
	_special_info()
	var locked := not _game.state.can_trade
	if locked:
		add_child(UiTheme.label(MatchActions.LOCKED + ".", 17, UiTheme.DANGER))
	var data := _game.state.data
	var builder := _game.my_builder()
	if not data.builder_allows(builder, _previewed):
		_previewed = ""
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for id in data.tower_order:
		if not data.builder_allows(builder, id):
			continue
		var def: Dictionary = data.towers[id]
		var tower_id: String = id
		var b := UiTheme.button("%s\n%d or" % [def["name"], def["levels"][0]["cost"]], func() -> void:
			_previewed = tower_id
			refresh(true), 62, false)
		b.toggle_mode = true
		b.button_pressed = id == _previewed
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.add_theme_color_override("font_color", Color(def["color"]).lightened(0.35))
		grid.add_child(b)
	if _previewed == "":
		add_child(UiTheme.label("Touche une tourelle pour voir ce qu'elle fait et sa portée sur la case, puis construis-la.", 16, UiTheme.MUTED))
		return
	var special := _game.map.special_at(_selected)
	_tower_info(_previewed, special, builder)
	var cost: int = data.tower_levels(_previewed)[0]["cost"]
	var index := data.tower_order.find(_previewed)
	var build := UiTheme.button("Construire — %d or" % cost, func() -> void:
		_game.send({"a": "build", "cell": _selected, "tower": index}))
	add_child(build)
	_priced.append([build, cost, locked])
	_game.preview_range(float(data.tower_stats(_previewed, 0, special, builder)["range"]))


## Fiche d'une tourelle avant construction : rôle, niveau 1, niveau max, coût total.
func _tower_info(id: String, special: int, builder: int) -> void:
	var data := _game.state.data
	var def: Dictionary = data.towers[id]
	var levels: Array = def["levels"]
	var last := levels.size() - 1
	add_child(UiTheme.label(def["name"], 22, Color(def["color"]).lightened(0.35)))
	add_child(UiTheme.label(def["description"], 16, UiTheme.TEXT))
	var first := data.tower_stats(id, 0, special, builder)
	var top := data.tower_stats(id, last, special, builder)
	add_child(UiTheme.label("Niveau 1 : %s%s" % [stats_text(def, first), _dps(def, first)], 15, UiTheme.MUTED))
	add_child(UiTheme.label("Niveau %d : %s%s" % [last + 1, stats_text(def, top), _dps(def, top)], 15, UiTheme.MUTED))
	add_child(UiTheme.label("Coût jusqu'au niveau %d : %d or (revente à %d %%)" % [last + 1, data.tower_invested(id, last), roundi(SimMatch.SELL_RATIO * 100.0)], 15, UiTheme.GOLD))


func _tower_panel(t: Dictionary) -> void:
	var data := _game.state.data
	var def: Dictionary = data.towers[t["type"]]
	var levels: Array = def["levels"]
	var level: int = t["level"]
	var special := _game.map.special_at(_selected)
	add_child(UiTheme.label("%s — niveau %d / %d" % [def["name"], level + 1, levels.size()], 24, UiTheme.ACCENT))
	var owner: int = t["owner"]
	var builder := int(_game.builders.get(owner, -1))
	var builder_name: String = data.builders[builder]["name"] if builder >= 0 else "?"
	add_child(UiTheme.label("Propriétaire : %s (%s)" % [_game.names.get(owner, "?"), builder_name], 17, _game.colors.get(owner, UiTheme.TEXT)))
	_special_info()
	add_child(UiTheme.label(stats_text(def, data.tower_stats(t["type"], level, special, builder)), 16, UiTheme.MUTED))
	var boosted := buffs_text(int(t.get("buffs", 0)))
	if boosted != "":
		add_child(UiTheme.label(boosted, 15, UiTheme.SUCCESS))
	if owner != _game.my_id:
		add_child(UiTheme.label("Seul son propriétaire peut l'améliorer ou la vendre.", 16, UiTheme.MUTED))
		return
	var locked := not _game.state.can_trade
	if locked:
		add_child(UiTheme.label(MatchActions.LOCKED + ".", 16, UiTheme.DANGER))
	if level + 1 < levels.size():
		var next_cost: int = levels[level + 1]["cost"]
		var up := UiTheme.button("Améliorer — %d or" % next_cost, func() -> void:
			_game.send({"a": "upgrade", "cell": _selected}))
		add_child(up)
		_priced.append([up, next_cost, locked])
		add_child(UiTheme.label("Niveau suivant : " + stats_text(def, data.tower_stats(t["type"], level + 1, special, builder)), 15, UiTheme.MUTED))
	else:
		add_child(UiTheme.label("Niveau maximum atteint.", 16, UiTheme.SUCCESS))
	add_child(UiTheme.button("Cible : %s" % SimTower.TARGET_NAMES[t["mode"]], func() -> void:
		_game.send({"a": "mode", "cell": _selected})))
	var refund := int(data.tower_invested(t["type"], level) * SimMatch.SELL_RATIO)
	var sell := UiTheme.button("Vendre (+%d or)" % refund, func() -> void:
		_game.send({"a": "sell", "cell": _selected}))
	sell.disabled = locked
	add_child(sell)


## Bonus de la case sélectionnée, s'il y en a un.
func _special_info() -> void:
	var special := _game.map.special_at(_selected)
	if special < 0:
		return
	var s: Dictionary = _game.state.data.specials[special]
	add_child(UiTheme.label("%s : %s" % [s["name"], s["description"]], 16, Color(s["color"])))


static func stats_text(def: Dictionary, s: Dictionary) -> String:
	if def.get("support", false):
		return _aura_text(s)
	var parts := ["Dégâts %s" % _num(s["damage"]), "portée %s" % _num(s["range"]), "%s tir/s" % _num(s["rate"])]
	if s["splash"] > 0.0:
		parts.append("zone %s" % _num(s["splash"]))
	if s["slow_factor"] < 1.0:
		parts.append("ralentit de %d %% (%s s)" % [roundi((1.0 - s["slow_factor"]) * 100.0), _num(s["slow_duration"])])
	if s["chain"] > 0:
		parts.append("%d rebonds" % s["chain"])
	if s["poison_dps"] > 0.0:
		parts.append("poison %s/s pendant %s s" % [_num(s["poison_dps"]), _num(s["poison_duration"])])
	if s["burn_dps"] > 0.0:
		parts.append("brûlure %s/s par charge, %d charges, %s s" % [_num(s["burn_dps"]), s["burn_stacks"], _num(s["burn_duration"])])
	if s["bleed"] > 0.0:
		parts.append("saignement %s %% des PV max/s pendant %s s" % [_num(s["bleed"] * 100.0), _num(s["bleed_duration"])])
	for kind in [["stun", "étourdit"], ["fear", "effraie"], ["charm", "charme"]]:
		if s[kind[0] + "_chance"] > 0.0:
			parts.append("%s %d %% du temps (%s s)" % [kind[1], roundi(s[kind[0] + "_chance"] * 100.0), _num(s[kind[0] + "_duration"])])
	parts.append("air et sol" if def["air"] and def["ground"] else ("sol" if def["ground"] else "air"))
	return " · ".join(parts)


static func _aura_text(s: Dictionary) -> String:
	var parts := ["Aura de portée %s" % _num(s["range"])]
	if s["aura_rate"] > 0.0:
		parts.append("+%d %% de cadence" % roundi(s["aura_rate"] * 100.0))
	if s["aura_damage"] > 0.0:
		parts.append("+%d %% de dégâts" % roundi(s["aura_damage"] * 100.0))
	if s["aura_cc"] > 0.0:
		parts.append("+%d %% de chances et durées de contrôle" % roundi(s["aura_cc"] * 100.0))
	parts.append("la plus forte aura de chaque type s'applique")
	return " · ".join(parts)


## Auras reçues par une tourelle (drapeaux de l'instantané).
static func buffs_text(flags: int) -> String:
	var names := []
	if flags & 1:
		names.append("dégâts")
	if flags & 2:
		names.append("cadence")
	if flags & 4:
		names.append("contrôles")
	return "" if names.is_empty() else "Renforcée par une aura : " + ", ".join(names) + "."


## « · 9,6 dégâts/s » (coups directs seulement), vide pour une tourelle de soutien.
static func _dps(def: Dictionary, s: Dictionary) -> String:
	return "" if def.get("support", false) else " · %s dégâts/s" % _num(s["damage"] * s["rate"])


static func _num(v: float) -> String:
	return str(snappedf(v, 0.01)).replace(".", ",")

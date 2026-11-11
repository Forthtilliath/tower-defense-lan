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
	var me := _game.me()
	return "%d|%d|%s|%s|%s|%s|%d|%d|%d|%d" % [_game.viewed_board, _selected, tower_sig, str(me.get("alive", false)), _previewed,
		str(_game.state.can_trade), _game.state.map_version, int(me.get("raze", 0)), int(me.get("tile", 0)), int(me.get("power", -1))]


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
		return
	if not _game.me().get("alive", false) and _game.is_versus:
		add_child(UiTheme.label("Tu as été éliminé.", 22, UiTheme.DANGER))
		return
	_power_button()  # pouvoir du talent ultime, toujours à portée de main sur son plateau
	if t != null:
		_tower_panel(t)
	elif _game.map.is_buildable(_selected):
		var zone := _game.map.zone_at(_selected)
		var owners := _zone_owners(zone)
		if zone >= 0 and not _game.is_versus and _game.map.zone_closed(zone, _game.order.size()):
			add_child(UiTheme.label("Zone fermée", 22, UiTheme.MUTED))
			add_child(UiTheme.label("Aucun joueur ne défend ce couloir : aucun monstre n'y passe, on n'y construit pas.", 17, UiTheme.MUTED))
		elif owners.is_empty() or _zone_open(zone):
			_build_panel()
		else:
			var who := " / ".join(owners.map(func(id: int) -> String: return _game.names.get(id, "?")))
			add_child(UiTheme.label("Zone de %s" % who, 22, _game.colors.get(owners[0], UiTheme.TEXT)))
			add_child(UiTheme.label("Seul le propriétaire de la zone peut y construire. Ta zone a ta couleur.", 17, UiTheme.MUTED))
	elif _selected >= 0:
		add_child(UiTheme.label("On ne peut pas construire ici.", 18, UiTheme.MUTED))
		_terrain_actions()
	else:
		add_child(UiTheme.label("Construire", 24, UiTheme.ACCENT))
		add_child(UiTheme.label("Touche une case d'herbe libre pour y poser une tourelle, ou une tourelle pour l'améliorer.", 17, UiTheme.MUTED))
		add_child(UiTheme.label("Les cases encadrées donnent un bonus.", 16, UiTheme.MUTED))
		if _game.map.zone_count > 0 and not _game.is_versus:
			add_child(UiTheme.label("Les cases teintées sont des zones de joueur : chacun construit dans la sienne.", 16, UiTheme.MUTED))


## Pouvoir actif du joueur (talent ultime) : prêt, ou dans combien de vagues ; à viser ou immédiat.
func _power_button() -> void:
	var left := int(_game.me().get("power", -1))
	var kit := _game.my_kit()
	if left < 0 or kit == null or not MatchPowers.POWERS.has(kit.power):
		return
	var def: Array = MatchPowers.POWERS[kit.power]
	var text := "Pouvoir : %s" % def[0] + (" (prêt)" if left == 0 else " (dans %d vague(s))" % left)
	var b := UiTheme.button(text, func() -> void:
		if def[1]:
			_game.aim({"a": "power"}, "%s : touche la case visée" % def[0])
		else:
			_game.send({"a": "power", "cell": 0}))
	b.disabled = left > 0 or not _game.state.received or _game.state.wave < 1
	b.add_theme_color_override("font_color", UiTheme.GOLD)
	add_child(b)


## Même règle que l'hôte (MatchActions.zone_open_to) : sa zone, ou toutes avec le Support, ou celle d'un Support.
func _zone_open(zone: int) -> bool:
	var builders: Array[int] = []
	var connected: Array[bool] = []
	for id in _game.order:
		var kit: PlayerKit = _game.kits.get(id)
		builders.append(kit.builder if kit != null else -1)
		connected.append(true)
	return MatchActions.zone_open_to(_game.state.data, _game.map, zone, _game.order.find(_game.my_id), builders, connected)


## Joueurs propriétaires d'une zone (vide : case commune).
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
	_terrain_actions()
	var data := _game.state.data
	var builder := _game.my_kit()
	if not builder.allows(_previewed):
		_previewed = ""
	# La fiche et « Construire » passent avant la grille : avec beaucoup de tourelles,
	# la grille dépasse l'écran et la fiche serait invisible sans défiler.
	if _previewed == "":
		add_child(UiTheme.label("Touche une tourelle pour voir ce qu'elle fait et sa portée sur la case, puis construis-la.", 16, UiTheme.MUTED))
	else:
		var special := _game.map.special_at(_selected)
		var cost: int = builder.cost(data.tower_levels(_previewed)[0]["cost"], _zone_discount(_selected))
		var index := data.tower_order.find(_previewed)
		_tower_info(_previewed, special, builder)
		var build := UiTheme.button("Construire — %d or" % cost, func() -> void:
			_game.send({"a": "build", "cell": _selected, "tower": index}))
		add_child(build)
		_priced.append([build, cost, locked])
		_game.preview_range(float(data.tower_stats(_previewed, 0, special, builder)["range"]))
		add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	var discount := _zone_discount(_selected)
	for id in data.tower_order:
		if not builder.allows(id):
			continue
		var def: Dictionary = data.towers[id]
		var tower_id: String = id
		var b := UiTheme.button("%s\n%d or" % [def["name"], builder.cost(def["levels"][0]["cost"], discount)], func() -> void:
			_previewed = tower_id
			refresh(true), 62)  # retour à la ligne : un nom long n'élargit pas le panneau
		b.toggle_mode = true
		b.button_pressed = id == _previewed
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.add_theme_color_override("font_color", Color(def["color"]).lightened(0.35))
		grid.add_child(b)


## Fiche d'une tourelle avant construction : rôle, niveau 1, niveau max, coût total.
func _tower_info(id: String, special: int, builder: PlayerKit) -> void:
	var data := _game.state.data
	var def: Dictionary = data.towers[id]
	var levels: Array = data.levels_for(id, builder)
	var last := levels.size() - 1
	add_child(UiTheme.label(def["name"], 22, Color(def["color"]).lightened(0.35)))
	add_child(UiTheme.label(def["description"], 16, UiTheme.TEXT))
	var first := data.tower_stats(id, 0, special, builder)
	var top := data.tower_stats(id, last, special, builder)
	add_child(UiTheme.label("Niveau 1 : %s%s" % [TowerText.stats_text(def, first), TowerText.dps(def, first)], 15, UiTheme.MUTED))
	add_child(UiTheme.label("Niveau %d : %s%s" % [last + 1, TowerText.stats_text(def, top), TowerText.dps(def, top)], 15, UiTheme.MUTED))
	add_child(UiTheme.label("Coût jusqu'au niveau %d : %d or (revente à %d %%)" % [last + 1, builder.invested(data, id, last), roundi(builder.sell_ratio() * 100.0)], 15, UiTheme.GOLD))


func _tower_panel(t: Dictionary) -> void:
	var data := _game.state.data
	var def: Dictionary = data.towers[t["type"]]
	var level: int = t["level"]
	var special := _game.map.special_at(_selected)
	var owner: int = t["owner"]
	var builder: PlayerKit = _game.kits.get(owner)
	var levels: Array = data.levels_for(t["type"], builder)  # étages de l'Architecte compris
	add_child(UiTheme.label("%s — niveau %d / %d" % [def["name"], level + 1, levels.size()], 24, UiTheme.ACCENT))
	var builder_name: String = builder.title(data) if builder != null else "?"
	add_child(UiTheme.label("Propriétaire : %s (%s)" % [_game.names.get(owner, "?"), builder_name], 17, _game.colors.get(owner, UiTheme.TEXT)))
	_special_info()
	add_child(UiTheme.label(TowerText.stats_text(def, data.tower_stats(t["type"], level, special, builder)), 16, UiTheme.MUTED))
	var boosted := TowerText.buffs_text(int(t.get("buffs", 0)))
	if boosted != "":
		add_child(UiTheme.label(boosted, 15, UiTheme.SUCCESS))
	if owner != _game.my_id:
		add_child(UiTheme.label("Seul son propriétaire peut l'améliorer ou la vendre.", 16, UiTheme.MUTED))
		return
	_terrain_actions()
	var locked := not _game.state.can_trade
	if locked:
		add_child(UiTheme.label(MatchActions.LOCKED + ".", 16, UiTheme.DANGER))
	if level + 1 < levels.size():
		var cut := _zone_discount(_selected) + TileBonus.discount(data, _game.map, _selected, t["type"])  # Forge
		var next_cost: int = _game.my_kit().cost(levels[level + 1]["cost"], cut)
		var up := UiTheme.button("Améliorer — %d or" % next_cost, func() -> void:
			_game.send({"a": "upgrade", "cell": _selected}))
		add_child(up)
		_priced.append([up, next_cost, locked])
		add_child(UiTheme.label("Niveau suivant : " + TowerText.stats_text(def, data.tower_stats(t["type"], level + 1, special, builder)), 15, UiTheme.MUTED))
	else:
		add_child(UiTheme.label("Niveau maximum atteint.", 16, UiTheme.SUCCESS))
	add_child(UiTheme.button("Cible : %s" % SimTower.TARGET_NAMES[t["mode"]], func() -> void:
		_game.send({"a": "mode", "cell": _selected})))
	var refund := int(int(t["invested"]) * _game.my_kit().sell_ratio())
	var sell := UiTheme.button("Vendre (+%d or)" % refund, func() -> void:
		_game.send({"a": "sell", "cell": _selected}))
	sell.disabled = locked
	add_child(sell)
	if _game.my_kit().m("moves") > 0.0 or _game.my_kit().power == "remount":  # Ferrailleur
		var from := _selected
		var move := UiTheme.button("Déplacer", func() -> void:
			_game.aim({"a": "move", "cell": from, "target": "to"}, "Touche la case où déplacer la tourelle"))
		move.disabled = locked
		add_child(move)


## Terrassier : raser l'arbre ou le rocher sélectionné, ou poser une case spéciale sur une case
## constructible sans bonus (même sous sa tourelle), tant qu'il lui reste des charges.
func _terrain_actions() -> void:
	var me := _game.me()
	var locked := not _game.state.can_trade
	var map := _game.map
	if map.is_decor(_selected) and int(me.get("raze", 0)) > 0:
		var raze := UiTheme.button("Raser (encore %d)" % int(me["raze"]), func() -> void:
			_game.send({"a": "raze", "cell": _selected}))
		raze.disabled = locked
		add_child(raze)
	elif map.is_buildable(_selected) and map.special_at(_selected) < 0:
		var data := _game.state.data
		var choices := []  # [case spéciale, charges restantes]
		for i in data.specials.size():
			var left := int(me.get(BoardTerrain.charge_kind(data, i), 0))
			if left > 0 and (BoardTerrain.placeable(data).has(i) or BoardTerrain.charge_kind(data, i) != "tile"):
				choices.append([i, left])
		if choices.is_empty():
			return
		add_child(UiTheme.label("Poser une case bonus :", 16, UiTheme.ACCENT))
		var row := UiTheme.hbox(6)
		add_child(row)
		for c in choices:
			var s: Dictionary = data.specials[c[0]]
			var special: int = c[0]
			var b := UiTheme.button("%s (%d)" % [s["name"], c[1]], func() -> void:
				_game.send({"a": "tile", "cell": _selected, "special": special}), 48, false)
			b.tooltip_text = s["description"]
			b.size_flags_horizontal = SIZE_EXPAND_FILL
			b.add_theme_color_override("font_color", Color(s["color"]))
			b.disabled = locked
			row.add_child(b)


## Réduction du Chantier le plus fort qui atteint la case (même règle que MatchActions.zone_discount,
## calculée sur l'instantané du plateau affiché).
func _zone_discount(cell: int) -> float:
	if cell < 0:
		return 0.0
	var data := _game.state.data
	var entries := []
	var towers: Dictionary = _game.viewed().get("towers", {})
	for c in towers:
		var t: Dictionary = towers[c]
		if data.towers[t["type"]]["support"] and int(t.get("buffs", 0)) & 8 == 0:
			var stats := data.tower_stats(t["type"], t["level"], _game.map.special_at(c), _game.kits.get(t["owner"]))
			entries.append([_game.map.cell_center(c), stats, t["owner"]])
	return float(BoardAuras.best_among(entries, _game.map.cell_center(cell), "aura_discount")[0])


## Bonus de la case sélectionnée, s'il y en a un.
func _special_info() -> void:
	var special := _game.map.special_at(_selected)
	if special < 0:
		return
	var s: Dictionary = _game.state.data.specials[special]
	add_child(UiTheme.label("%s : %s" % [s["name"], s["description"]], 16, Color(s["color"])))

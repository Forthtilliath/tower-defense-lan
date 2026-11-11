class_name TalentPanel
extends ColorRect
## Arbre de talents d'une classe, par-dessus le salon : niveau, expérience, points, et une
## colonne par branche. Toucher un talent ajoute un rang ; « − » en retire un, si les paliers
## supérieurs restent valables. Chaque changement est enregistré puis annoncé à l'hôte.

var _builder := 0
var _on_change: Callable
var _on_close: Callable
var _header: Label
var _message: Label
var _body: HBoxContainer
var _tab := -1  # branche de spécialisation affichée (index dans les branches de la classe)


func _init(builder: int, on_change: Callable, on_close: Callable) -> void:
	_builder = builder
	_on_change = on_change
	_on_close = on_close
	color = Color(0, 0, 0, 0.75)
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var box := UiTheme.vbox(10)
	panel.add_child(box)
	var top := UiTheme.hbox(12)
	box.add_child(top)
	var titles := UiTheme.vbox(2)
	titles.size_flags_horizontal = SIZE_EXPAND_FILL
	titles.add_child(UiTheme.label("Talents : %s" % Data.db.builders[_builder]["name"], 28, UiTheme.ACCENT))
	_header = UiTheme.label("", 16, UiTheme.MUTED)
	titles.add_child(_header)
	top.add_child(titles)
	top.add_child(UiTheme.button("Tout retirer", _reset, 48, false))
	top.add_child(UiTheme.button("Fermer", func() -> void: _on_close.call(), 48, false))
	_message = UiTheme.label("", 16, UiTheme.DANGER)
	box.add_child(_message)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_body = UiTheme.hbox(14)
	_body.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_rebuild()


func _rebuild() -> void:
	UiTheme.clear(_body)
	var data := Data.db
	var talents := Progress.talents(_builder)
	var level := Progress.level(_builder)
	var progress := TalentRules.level_progress(data, Progress.xp(_builder))
	var xp_text := "niveau maximum" if progress[1] == 0 else "%d / %d XP vers le niveau %d" % [progress[0], progress[1], level + 1]
	var kit := PlayerKit.make(data, _builder, talents)
	var chosen := "spécialisation : %s (retire ses points pour en changer)" % kit.spec_name(data) if kit.spec >= 0 \
			else "choisis UNE spécialisation : les trois autres se ferment"
	_header.text = "Niveau %d (%s) · %d point(s) libre(s) sur %d · %s.\nPaliers : %s points dans la branche." % [
		level, xp_text, Progress.points_left(_builder), TalentRules.points(level), chosen,
		" / ".join(data.talent_tiers.slice(1).map(func(n: int) -> String: return str(n)))]
	var box := UiTheme.vbox(14)
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	_body.add_child(box)
	var branches: Array = data.builders[_builder]["branches"]
	if _tab < 0 or branches[_tab]["trunk"]:
		_tab = kit.spec if kit.spec >= 0 else _first_spec(branches)
	var tabs := UiTheme.hbox(8)
	for i in branches.size():
		var branch: Dictionary = branches[i]
		if branch["trunk"]:
			box.add_child(_branch_block(branch, talents, false))
		else:
			tabs.add_child(_tab_button(i, branch, talents, kit.spec >= 0 and kit.spec != i))
	box.add_child(tabs)
	box.add_child(_branch_block(branches[_tab], talents, kit.spec >= 0 and kit.spec != _tab))


static func _first_spec(branches: Array) -> int:
	for i in branches.size():
		if not branches[i]["trunk"]:
			return i
	return 0


## Onglet d'une spécialisation : son nom, ses points, fermée si une autre est choisie.
func _tab_button(i: int, branch: Dictionary, talents: Dictionary, closed: bool) -> Button:
	var b := UiTheme.button("%s (%d)%s" % [branch["name"], _spent(branch, talents), " · fermée" if closed else ""],
		func() -> void:
			_tab = i
			_rebuild(), 52, false)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	if i == _tab:
		b.add_theme_color_override("font_color", UiTheme.ACCENT)
		b.add_theme_color_override("font_hover_color", UiTheme.ACCENT)
	elif closed:
		b.add_theme_color_override("font_color", UiTheme.MUTED.darkened(0.3))
	return b


## Une branche (tronc ou spécialisation) : titre, description, talents deux par ligne.
func _branch_block(branch: Dictionary, talents: Dictionary, closed: bool) -> VBoxContainer:
	var col := UiTheme.vbox(8)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	var title := "%s (%d)%s" % [branch["name"], _spent(branch, talents), " · fermée" if closed else ""]
	col.add_child(UiTheme.label(title, 22, UiTheme.MUTED if closed else UiTheme.ACCENT))
	col.add_child(UiTheme.label(branch["description"], 15, UiTheme.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	for t in _sorted(branch):
		var r := _talent_row(t, talents)
		r.size_flags_horizontal = SIZE_EXPAND_FILL
		grid.add_child(r)
	col.add_child(grid)
	return col


static func _spent(branch: Dictionary, talents: Dictionary) -> int:
	var spent := 0
	for t in branch["talents"]:
		spent += int(talents.get(t["id"], 0))
	return spent


static func _sorted(branch: Dictionary) -> Array:
	var sorted: Array = branch["talents"].duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _rank_key(a) < _rank_key(b))
	return sorted


## Ordre d'affichage : par palier, le talent ultime toujours en dernier.
static func _rank_key(t: Dictionary) -> int:
	return int(t["tier"]) + (100 if t["ultimate"] else 0)


func _talent_row(t: Dictionary, talents: Dictionary) -> HBoxContainer:
	var row := UiTheme.hbox(6)
	var rank := int(talents.get(t["id"], 0))
	var id: String = t["id"]
	var open := TalentRules.add_refusal(Data.db, _builder, talents, id, 999) == "" or rank > 0
	var step := "Ultime · niveau %d" % int(Data.db.progression["max_level"]) if t["ultimate"] else "Palier %d" % t["tier"]
	var b := UiTheme.button("%s · %s  %d/%d\n%s" % [step, t["name"], rank, t["max_rank"], t["description"]],
		func() -> void: _change(id, true), 70)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if rank > 0:
		b.add_theme_color_override("font_color", UiTheme.SUCCESS)
	elif t["ultimate"]:
		b.add_theme_color_override("font_color", UiTheme.GOLD)
	elif not open:
		b.add_theme_color_override("font_color", UiTheme.MUTED.darkened(0.3))
	row.add_child(b)
	var minus := UiTheme.button("−", func() -> void: _change(id, false), 70, false)
	minus.custom_minimum_size.x = 44
	minus.disabled = rank == 0
	row.add_child(minus)
	return row


func _change(id: String, add: bool) -> void:
	var data := Data.db
	var talents := Progress.talents(_builder)
	var points := TalentRules.points(Progress.level(_builder))
	var refusal := TalentRules.add_refusal(data, _builder, talents, id, points) if add else TalentRules.remove_refusal(data, _builder, talents, id)
	_message.text = refusal
	if refusal != "":
		return
	talents[id] = int(talents.get(id, 0)) + (1 if add else -1)
	if talents[id] <= 0:
		talents.erase(id)
	Progress.set_talents(_builder, talents)
	_on_change.call()
	_rebuild()


func _reset() -> void:
	Progress.set_talents(_builder, {})
	_message.text = ""
	_on_change.call()
	_rebuild()

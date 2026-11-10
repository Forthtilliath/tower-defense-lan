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
	_header.text = "Niveau %d (%s) · %d point(s) libre(s) sur %d. Paliers : %s points dans la branche." % [
		level, xp_text, Progress.points_left(_builder), TalentRules.points(level),
		" / ".join(data.talent_tiers.slice(1).map(func(n: int) -> String: return str(n)))]
	for branch in data.builders[_builder]["branches"]:
		_body.add_child(_branch_column(branch, talents))


func _branch_column(branch: Dictionary, talents: Dictionary) -> VBoxContainer:
	var col := UiTheme.vbox(8)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	var spent := 0
	for t in branch["talents"]:
		spent += int(talents.get(t["id"], 0))
	col.add_child(UiTheme.label("%s (%d)" % [branch["name"], spent], 22, UiTheme.ACCENT))
	col.add_child(UiTheme.label(branch["description"], 15, UiTheme.MUTED))
	var sorted: Array = branch["talents"].duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["tier"] < b["tier"])
	for t in sorted:
		col.add_child(_talent_row(t, talents))
	return col


func _talent_row(t: Dictionary, talents: Dictionary) -> HBoxContainer:
	var row := UiTheme.hbox(6)
	var rank := int(talents.get(t["id"], 0))
	var id: String = t["id"]
	var open := TalentRules.add_refusal(Data.db, _builder, talents, id, 999) == "" or rank > 0
	var b := UiTheme.button("Palier %d · %s  %d/%d\n%s" % [t["tier"], t["name"], rank, t["max_rank"], t["description"]],
		func() -> void: _change(id, true), 70)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if rank > 0:
		b.add_theme_color_override("font_color", UiTheme.SUCCESS)
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

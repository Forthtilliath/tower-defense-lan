class_name AccountsScreen
extends CenterContainer
## « Continuer » : les comptes de l'appareil (pseudo et niveau de chaque classe). Toucher un
## compte l'ouvre ; « Envoyer » le copie sur un autre appareil du Wi-Fi ; « Supprimer »
## demande confirmation (la suppression est définitive).

var _nav: Node
var _list: VBoxContainer
var _status: Label


func _init(nav: Node) -> void:
	_nav = nav
	set_anchors_preset(PRESET_FULL_RECT)


func _ready() -> void:
	var box := UiTheme.vbox(12)
	box.custom_minimum_size = Vector2(820, 0)
	add_child(box)
	box.add_child(UiTheme.title("Continuer", 40))
	_status = UiTheme.label("Choisis ton compte. « Envoyer » le copie sur un autre appareil du même Wi-Fi.", 17, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 420
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = UiTheme.vbox(10)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var bottom := UiTheme.hbox(12)
	box.add_child(bottom)
	var back := UiTheme.button("Retour", go_back)
	back.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom.add_child(back)
	var receive := UiTheme.button("Recevoir un compte", _nav.show_receive)
	receive.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom.add_child(receive)
	_rebuild()


func go_back() -> void:
	_nav.show_start()


func _rebuild() -> void:
	UiTheme.clear(_list)
	var found := AccountStore.list(Data.db)
	var accounts: Array = found["accounts"]
	if accounts.is_empty():
		_nav.show_start("Aucun compte sur cet appareil : crée-en un.")
		return
	# Le dernier compte ouvert d'abord, puis du plus récemment joué au plus ancien.
	for i in accounts.size():
		if accounts[i]["id"] == Settings.last_account:
			accounts.push_front(accounts.pop_at(i))
			break
	for a in accounts:
		_list.add_child(_card(a))
	if found["rejected"] > 0:
		_status.text = "%d sauvegarde(s) illisible(s) mise(s) de côté (fichiers .invalid.json)." % found["rejected"]
		_status.add_theme_color_override("font_color", UiTheme.DANGER)


func _card(account: Dictionary) -> Control:
	var row := UiTheme.hbox(10)
	var id: String = account["id"]
	# Cadre à la taille du contenu, et bouton transparent par-dessus (dernier enfant) pour l'ouvrir.
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiTheme.slanted(UiTheme.PANEL_LIGHT))
	row.add_child(card)
	card.add_child(AccountView.summary(account["name"], account["classes"], "dernier joué" if id == Settings.last_account else ""))
	# Le bouton est invisible : c'est la carte (penchée) qui change d'aspect au survol et à l'appui.
	var pick := Button.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		pick.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var normal := UiTheme.slanted(UiTheme.PANEL_LIGHT)
	var hover := UiTheme.slanted(UiTheme.PANEL_LIGHT.lightened(0.12))
	hover.border_color = UiTheme.ACCENT
	var pressed := UiTheme.slanted(UiTheme.CRIMSON)
	pick.mouse_entered.connect(func() -> void: card.add_theme_stylebox_override("panel", hover))
	pick.mouse_exited.connect(func() -> void: card.add_theme_stylebox_override("panel", normal))
	pick.button_down.connect(func() -> void: card.add_theme_stylebox_override("panel", pressed))
	pick.button_up.connect(func() -> void: card.add_theme_stylebox_override("panel", hover if pick.is_hovered() else normal))
	pick.pressed.connect(func() -> void: _open(id))
	card.add_child(pick)
	var actions := UiTheme.vbox(8)
	actions.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(actions)
	actions.add_child(UiTheme.button("Envoyer", func() -> void: _nav.show_send(id), 46, false))
	actions.add_child(UiTheme.button("Supprimer", func() -> void: _confirm_remove(account), 46, false))
	return row

func _open(id: String) -> void:
	var err := Progress.open_account(id)
	if err != "":
		_status.text = err
		_status.add_theme_color_override("font_color", UiTheme.DANGER)
		_rebuild()
		return
	_nav.show_menu()


func _confirm_remove(account: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Supprimer le compte"
	dialog.dialog_text = "Supprimer « %s » et toute sa progression ?\nC'est définitif." % account["name"]
	dialog.ok_button_text = "Supprimer"
	dialog.cancel_button_text = "Annuler"
	dialog.confirmed.connect(func() -> void:
		AccountStore.remove(account["id"])
		if Settings.last_account == account["id"]:
			Settings.set_last_account("")
		_rebuild())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

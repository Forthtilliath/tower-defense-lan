class_name SendScreen
extends CenterContainer
## « Envoyer » un compte vers un autre appareil du même Wi-Fi, qui attend dans « Recevoir un
## compte » : on choisit l'appareil (ou on saisit son IP) et on tape le code qu'il affiche.
## Le compte reste aussi sur cet appareil.

var _nav: Node
var _id := ""
var _text := ""
var _sender: AccountSender
var _list: VBoxContainer
var _ip_edit: LineEdit
var _code_edit: LineEdit
var _send: Button
var _status: Label


func _init(nav: Node, account_id: String) -> void:
	_nav = nav
	_id = account_id
	set_anchors_preset(PRESET_FULL_RECT)


func _ready() -> void:
	var account = AccountStore.read(Data.db, _id)
	var box := UiTheme.vbox(12)
	box.custom_minimum_size.x = 640
	add_child(box)
	box.add_child(UiTheme.title("Envoyer « %s »" % (account["name"] if account != null else "?"), 40))
	box.add_child(UiTheme.label("Sur l'autre appareil, connecté au même Wi-Fi : « Recevoir un compte » (accueil, ou « Continuer »). Choisis-le ci-dessous, puis tape le code qu'il affiche.", 17, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 150
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = UiTheme.vbox(8)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var row := UiTheme.hbox(10)
	box.add_child(row)
	_ip_edit = _field(row, "Adresse IP", "192.168.1.20", 15, LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL)
	_code_edit = _field(row, "Code", "0000", 4, LineEdit.KEYBOARD_TYPE_NUMBER)
	_code_edit.get_parent().size_flags_horizontal = SIZE_FILL
	_code_edit.custom_minimum_size.x = 140
	_code_edit.text_submitted.connect(func(_t: String) -> void: _on_send())
	_status = UiTheme.label("", 17, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_status)
	var buttons := UiTheme.hbox(12)
	box.add_child(buttons)
	var back := UiTheme.button("Retour", go_back)
	back.size_flags_horizontal = SIZE_EXPAND_FILL
	buttons.add_child(back)
	_send = UiTheme.button("Envoyer", _on_send)
	_send.size_flags_horizontal = SIZE_EXPAND_FILL
	buttons.add_child(_send)
	_sender = AccountSender.new()
	_sender.receivers_changed.connect(_refresh)
	_sender.finished.connect(_on_finished)
	if account == null:
		_send.disabled = true
		_status.text = "Ce compte est illisible ou a été supprimé."
		return
	_text = AccountStore.export_text(Data.db, _id)
	if not _sender.start_browse():
		_status.text = "Recherche automatique indisponible (port %d occupé) : saisis l'IP affichée sur l'autre appareil." % AccountTransfer.UDP_PORT
	_refresh([])


func _field(parent: Control, heading: String, placeholder: String, max_length: int, keyboard: int) -> LineEdit:
	var col := UiTheme.vbox(4)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(col)
	col.add_child(UiTheme.label(heading, 14, UiTheme.MUTED))
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.max_length = max_length
	edit.custom_minimum_size.y = 52
	edit.virtual_keyboard_type = keyboard
	col.add_child(edit)
	return edit


func _process(_delta: float) -> void:
	if _sender != null:
		_sender.poll()


func _exit_tree() -> void:
	if _sender != null:
		_sender.stop()


func go_back() -> void:
	_nav.show_accounts()


func _refresh(receivers: Array) -> void:
	UiTheme.clear(_list)
	if receivers.is_empty():
		_list.add_child(UiTheme.label("Aucun appareil en attente pour l'instant.", 16, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return
	for r in receivers:
		var ip: String = r["ip"]
		_list.add_child(UiTheme.button("%s — %s" % [r["name"], ip], func() -> void:
			_ip_edit.text = ip
			_code_edit.grab_focus()))


func _on_send() -> void:
	if _sender.is_sending():
		return
	var err := _sender.send(_ip_edit.text.strip_edges(), _code_edit.text.strip_edges(), _text)
	if err != "":
		_show(err, UiTheme.DANGER)
		return
	_send.disabled = true
	_show("Envoi…", UiTheme.MUTED)


func _on_finished(error: String) -> void:
	_send.disabled = false
	if error == "":
		_show("Compte envoyé : confirme l'import sur l'autre appareil.", UiTheme.SUCCESS)
	else:
		_show(error, UiTheme.DANGER)


func _show(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)

class_name JoinScreen
extends CenterContainer
## Recherche des parties du réseau local, ou connexion par adresse IP.

var _nav: Node
var _list: VBoxContainer
var _status: Label
var _ip_edit: LineEdit
var _join_button: Button


func _init(nav: Node) -> void:
	_nav = nav
	set_anchors_preset(PRESET_FULL_RECT)


func _ready() -> void:
	var box := UiTheme.vbox(14)
	box.custom_minimum_size.x = 560
	add_child(box)
	box.add_child(UiTheme.label("Rejoindre une partie", 36, UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_status = UiTheme.label("Recherche des parties sur le réseau…", 18, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 220
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = UiTheme.vbox(8)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(UiTheme.label("Ou saisis l'adresse IP affichée chez l'hôte :", 18, UiTheme.MUTED))
	var row := UiTheme.hbox()
	box.add_child(row)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.1.20"
	_ip_edit.text = Settings.last_ip
	_ip_edit.max_length = 15
	_ip_edit.custom_minimum_size.y = 52
	_ip_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_ip_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_ip_edit.text_submitted.connect(func(_t: String) -> void: _join(_ip_edit.text.strip_edges()))
	row.add_child(_ip_edit)
	_join_button = UiTheme.button("Rejoindre", func() -> void: _join(_ip_edit.text.strip_edges()), 52, false)
	row.add_child(_join_button)
	box.add_child(UiTheme.button("Retour", go_back))
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.discovery.hosts_changed.connect(_refresh)
	if not Net.discovery.start_listen():
		_status.text = "Recherche automatique indisponible (port %d occupé) : saisis l'IP de l'hôte." % LanDiscovery.PORT
	_refresh([])


func _exit_tree() -> void:
	Net.discovery.stop_listen()


func go_back() -> void:
	Net.leave()
	_nav.show_menu()


func _refresh(hosts: Array) -> void:
	UiTheme.clear(_list)
	if hosts.is_empty():
		_list.add_child(UiTheme.label("Aucune partie trouvée pour l'instant.", 18, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return
	for h in hosts:
		var text := "%s — %s — %d/%d joueurs" % [h["name"], Net.MODE_NAMES[h["mode"]], h["players"], h["max"]]
		var reason := ""
		if h["version"] != Net.version():
			reason = "version %s" % h["version"]
		elif h["started"]:
			reason = "en cours"
		elif h["players"] >= h["max"]:
			reason = "complet"
		if reason != "":
			text += " (%s)" % reason
		var ip: String = h["ip"]
		var b := UiTheme.button(text, func() -> void: _join(ip))
		b.disabled = reason != ""
		_list.add_child(b)


func _join(ip: String) -> void:
	if not Check.is_ipv4(ip):
		_status.text = "Adresse IP invalide (exemple : 192.168.1.20)."
		return
	Settings.set_last_ip(ip)
	var err := Net.join(ip, Progress.account_name)
	if err != "":
		_status.text = err
		return
	_status.text = "Connexion à %s…" % ip
	_join_button.disabled = true


func _on_lobby_changed() -> void:
	_nav.show_lobby()

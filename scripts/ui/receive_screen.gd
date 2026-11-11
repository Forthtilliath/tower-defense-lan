class_name ReceiveScreen
extends CenterContainer
## « Recevoir un compte » : cet appareil attend un compte envoyé depuis un autre appareil du
## même Wi-Fi, en affichant un code à 4 chiffres à taper là-bas. Le compte reçu (déjà vérifié)
## est montré, puis enregistré seulement si le joueur confirme.

var _nav: Node
var _receiver: AccountReceiver
var _steps: Label
var _code: Label
var _status: Label
var _preview: VBoxContainer
var _import: Button
var _account := {}


func _init(nav: Node) -> void:
	_nav = nav
	set_anchors_preset(PRESET_FULL_RECT)


func _ready() -> void:
	var box := UiTheme.vbox(12)
	box.custom_minimum_size.x = 640
	add_child(box)
	box.add_child(UiTheme.title("Recevoir un compte", 40))
	_steps = UiTheme.label("", 17, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_steps)
	_code = UiTheme.title("", 72)
	box.add_child(_code)
	_status = UiTheme.label("", 17, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_status)
	_preview = UiTheme.vbox(8)
	box.add_child(_preview)
	var row := UiTheme.hbox(12)
	box.add_child(row)
	var back := UiTheme.button("Annuler", go_back)
	back.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(back)
	_import = UiTheme.button("Importer", _on_import)
	_import.size_flags_horizontal = SIZE_EXPAND_FILL
	_import.visible = false
	row.add_child(_import)
	_receiver = AccountReceiver.new(Data.db)
	_receiver.received.connect(_on_received)
	_receiver.failed.connect(_on_failed)
	var label := AccountTransfer.device_label()
	var err := _receiver.start(label)
	if err != "":
		_on_failed(err)
		return
	var ips := LanDiscovery.local_addresses()
	_steps.text = "Sur l'autre appareil, connecté au même Wi-Fi : « Continuer », puis « Envoyer » sur le compte voulu. Choisis « %s »%s et tape ce code :" % [
		label, " (IP %s)" % " / ".join(ips) if not ips.is_empty() else ""]
	_code.text = " ".join(_receiver.code.split(""))
	_status.text = "En attente du compte…"


func _process(_delta: float) -> void:
	if _receiver != null:
		_receiver.poll()


func _exit_tree() -> void:
	if _receiver != null:
		_receiver.stop()


func go_back() -> void:
	if AccountStore.list(Data.db)["accounts"].is_empty():
		_nav.show_start()
	else:
		_nav.show_accounts()


func _on_received(account: Dictionary) -> void:
	_account = account
	_steps.text = "Compte reçu. Vérifie-le avant de l'importer :"
	_code.visible = false
	UiTheme.clear(_preview)
	var card := PanelContainer.new()
	card.add_child(AccountView.summary(account["name"], account["classes"]))
	_preview.add_child(card)
	var existing: Array = AccountStore.list(Data.db)["accounts"]
	var same := AccountStore.find(existing, account["name"])
	if same != "":
		_status.text = "Un compte « %s » existe déjà sur cet appareil : il sera remplacé par celui-ci." % account["name"]
		_status.add_theme_color_override("font_color", UiTheme.GOLD)
		_import.text = "Remplacer"
	else:
		_status.text = "Ce compte sera ajouté à cet appareil."
		_import.text = "Importer"
	_import.visible = true


func _on_failed(message: String) -> void:
	_code.visible = false
	_steps.text = ""
	_status.text = message
	_status.add_theme_color_override("font_color", UiTheme.DANGER)


func _on_import() -> void:
	var err := Progress.import_account(_account)
	if err != "":
		_on_failed(err)
		_import.visible = false
		return
	_nav.show_menu()

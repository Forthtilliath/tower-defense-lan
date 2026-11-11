class_name StartScreen
extends CenterContainer
## Écran d'accueil, au lancement : continuer un compte de l'appareil, en créer un nouveau, ou
## en recevoir un d'un autre appareil du Wi-Fi (passage du PC au téléphone, par exemple).

var _nav: Node
var _message := ""


func _init(nav: Node, message := "") -> void:
	_nav = nav
	_message = message
	set_anchors_preset(PRESET_FULL_RECT)


func _ready() -> void:
	var box := UiTheme.vbox(14)
	box.custom_minimum_size.x = 460
	add_child(box)
	box.add_child(UiTheme.title("Tower Defense LAN", 48))
	box.add_child(UiTheme.label("Défendez ensemble ou affrontez-vous en réseau local.", 18, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var valid := Data.db.is_valid()
	var count: int = AccountStore.list(Data.db)["accounts"].size() if valid else 0
	var resume := UiTheme.button("Continuer", _nav.show_accounts, 60)
	resume.disabled = count == 0
	box.add_child(resume)
	var note := "Aucun compte sur cet appareil pour l'instant." if count == 0 \
		else "%d compte%s sur cet appareil." % [count, "s" if count > 1 else ""]
	box.add_child(UiTheme.label(note, 15, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var create := UiTheme.button("Nouveau compte", _nav.show_new_account)
	create.disabled = not valid
	box.add_child(create)
	var receive := UiTheme.button("Recevoir un compte d'un autre appareil", _nav.show_receive)
	receive.disabled = not valid
	box.add_child(receive)
	if not OS.has_feature("mobile"):
		box.add_child(UiTheme.button("Quitter", func() -> void: get_tree().quit()))
	if _message == "" and Progress.load_warning != "":
		_message = Progress.load_warning
		Progress.load_warning = ""
	box.add_child(UiTheme.label(_message, 17, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("Version %s" % Net.version(), 14, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not resume.disabled:
		resume.grab_focus.call_deferred()


func go_back() -> void:
	get_tree().quit()

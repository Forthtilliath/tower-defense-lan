class_name MenuScreen
extends CenterContainer
## Menu principal du compte ouvert : héberger, rejoindre, changer de compte.

var _nav: Node
var _message := ""
var _error: Label


func _init(nav: Node, message := "") -> void:
	_nav = nav
	_message = message
	set_anchors_preset(PRESET_FULL_RECT)


func _ready() -> void:
	var box := UiTheme.vbox(14)
	box.custom_minimum_size.x = 460
	add_child(box)
	box.add_child(UiTheme.title("Tower Defense LAN", 48))
	var who := UiTheme.vbox(2)
	box.add_child(who)
	who.add_child(UiTheme.label("Compte", 15, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	who.add_child(UiTheme.label(Progress.account_name, 28, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	who.add_child(UiTheme.label(_best_text(), 15, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var host := UiTheme.button("Héberger une partie", _on_host)
	box.add_child(host)
	box.add_child(UiTheme.button("Rejoindre une partie", _nav.show_join))
	box.add_child(UiTheme.button("Changer de compte", go_back))
	if not OS.has_feature("mobile"):
		box.add_child(UiTheme.button("Quitter", func() -> void: get_tree().quit()))
	_error = UiTheme.label(_message, 18, UiTheme.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_error)
	host.grab_focus.call_deferred()


## Retour (Android ou bouton) : on revient à l'accueil, le compte est refermé.
func go_back() -> void:
	Progress.close_account()
	_nav.show_start()


## « Meilleure classe : Arcaniste niv. 12 » (vide pour un compte tout neuf).
func _best_text() -> String:
	var best := -1
	for b in Data.db.builders.size():
		if Progress.xp(b) > 0 and (best < 0 or Progress.level(b) > Progress.level(best)):
			best = b
	if best < 0:
		return "Nouveau compte : chaque classe commence au niveau 1."
	return "Meilleure classe : %s niv. %d" % [Data.db.builders[best]["name"], Progress.level(best)]


func _on_host() -> void:
	var err := Net.host(Progress.account_name)
	if err != "":
		_error.text = err
		return
	_nav.show_lobby()

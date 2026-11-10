class_name MenuScreen
extends CenterContainer
## Menu principal : pseudo, héberger, rejoindre.

var _nav: Node
var _message := ""
var _name_edit: LineEdit
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
	box.add_child(UiTheme.label("Défendez ensemble ou affrontez-vous en réseau local.", 18, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("Ton pseudo", 18, UiTheme.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.text = Settings.player_name
	_name_edit.max_length = Check.NAME_MAX
	_name_edit.custom_minimum_size.y = 52
	_name_edit.select_all_on_focus = true
	box.add_child(_name_edit)
	box.add_child(UiTheme.button("Héberger une partie", _on_host))
	box.add_child(UiTheme.button("Rejoindre une partie", _on_join))
	if not OS.has_feature("mobile"):
		box.add_child(UiTheme.button("Quitter", func() -> void: get_tree().quit()))
	if _message == "" and Progress.load_warning != "":
		_message = Progress.load_warning
	_error = UiTheme.label(_message, 18, UiTheme.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_error)
	box.add_child(UiTheme.label("Version %s" % Net.version(), 14, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func go_back() -> void:
	get_tree().quit()


func _player_name() -> String:
	Settings.set_player_name(_name_edit.text)
	return Settings.player_name


func _on_host() -> void:
	var err := Net.host(_player_name())
	if err != "":
		_error.text = err
		return
	_nav.show_lobby()


func _on_join() -> void:
	_player_name()
	_nav.show_join()

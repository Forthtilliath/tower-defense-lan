class_name NewAccountScreen
extends CenterContainer
## Création d'un compte : un pseudo (unique sur l'appareil), puis direction le menu.

var _nav: Node
var _name_edit: LineEdit
var _error: Label


func _init(nav: Node) -> void:
	_nav = nav
	set_anchors_preset(PRESET_FULL_RECT)


func _ready() -> void:
	var box := UiTheme.vbox(14)
	box.custom_minimum_size.x = 460
	add_child(box)
	box.add_child(UiTheme.title("Nouveau compte", 40))
	box.add_child(UiTheme.label("Ton compte garde ton pseudo, le niveau et les talents de chaque classe.", 17, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("Ton pseudo", 18, UiTheme.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.max_length = Check.NAME_MAX
	_name_edit.placeholder_text = "%d caractères au plus" % Check.NAME_MAX
	_name_edit.custom_minimum_size.y = 52
	_name_edit.text_submitted.connect(func(_t: String) -> void: _create())
	box.add_child(_name_edit)
	_error = UiTheme.label("", 17, UiTheme.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_error)
	var row := UiTheme.hbox(12)
	box.add_child(row)
	var back := UiTheme.button("Retour", go_back)
	back.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(back)
	var create := UiTheme.button("Créer le compte", _create)
	create.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(create)
	_name_edit.grab_focus.call_deferred()


func go_back() -> void:
	_nav.show_start()


func _create() -> void:
	var err := Progress.create_account(_name_edit.text)
	if err != "":
		_error.text = err
		return
	_nav.show_menu()

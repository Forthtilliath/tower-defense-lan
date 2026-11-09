class_name GameScreen
extends Control
## Écran de partie : plateau au centre, barre d'infos en haut, panneau d'actions à droite.
## Toutes les actions passent par Net.send_command ; l'affichage suit les instantanés de l'hôte.

const SIDE_WIDTH := 320

var config: Dictionary
var state: ViewState
var map: MapDef
var my_id := 1
var my_board := 0
var viewed_board := 0
var names := {}  # id -> pseudo
var colors := {}  # id -> Color
var order: Array[int] = []  # ids dans l'ordre de la partie
var is_versus := false
var _nav: Node
var _view: BoardView
var _hud: HudBar
var _panel: SidePanel
var _versus: VersusPanel
var _end: EndOverlay
var _toast: Label
var _toast_time := 0.0
var _confirm: ConfirmationDialog


func _init(nav: Node, p_config: Dictionary) -> void:
	_nav = nav
	config = p_config
	set_anchors_preset(PRESET_FULL_RECT)


func _ready() -> void:
	my_id = Net.my_id()
	is_versus = config["mode"] == SimMatch.Mode.VERSUS
	map = Data.db.maps[config["map"]]
	for e in config["roster"]:
		order.append(e[0])
		names[e[0]] = e[1]
		colors[e[0]] = UiTheme.player_color(e[2])
	my_board = maxi(0, order.find(my_id)) if is_versus else 0
	viewed_board = my_board
	state = ViewState.new(Data.db, map, order.size() if is_versus else 1)
	_build_layout()
	Net.snapshot_received.connect(_on_snapshot)
	Net.notice.connect(show_toast)


func _build_layout() -> void:
	var root := UiTheme.vbox(0)
	root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(root)
	_hud = HudBar.new(self)
	root.add_child(_hud)
	var body := UiTheme.hbox(0)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(body)
	_view = BoardView.new()
	_view.data = Data.db
	_view.state = state
	_view.player_colors = colors
	_view.board_index = viewed_board
	_view.size_flags_horizontal = SIZE_EXPAND_FILL
	_view.set_map(map)
	_view.cell_pressed.connect(_on_cell_pressed)
	body.add_child(_view)
	var side_bg := PanelContainer.new()
	side_bg.custom_minimum_size.x = SIDE_WIDTH
	side_bg.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, 0))
	body.add_child(side_bg)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_bg.add_child(scroll)
	var side := UiTheme.vbox(16)
	side.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(side)
	_panel = SidePanel.new(self)
	side.add_child(_panel)
	if is_versus:
		_versus = VersusPanel.new(self)
		side.add_child(_versus)
	_toast = UiTheme.label("", 20, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_toast.position.y -= 70
	_toast.add_theme_stylebox_override("normal", UiTheme.box(Color(0, 0, 0, 0.75)))
	_toast.visible = false
	_toast.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_toast)
	_end = EndOverlay.new(self)
	add_child(_end)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Quitter la partie"
	_confirm.dialog_text = "Quitter la partie ?" + ("\nTu es l'hôte : la partie s'arrêtera pour tout le monde." if Net.is_host() else "")
	_confirm.ok_button_text = "Quitter"
	_confirm.cancel_button_text = "Annuler"
	_confirm.confirmed.connect(quit_game)
	add_child(_confirm)


func _process(delta: float) -> void:
	state.advance(delta)
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
		_toast.visible = _toast_time > 0.0


func _on_snapshot(snap: Dictionary) -> void:
	if not state.apply(snap):
		return
	_hud.refresh()
	_panel.refresh()
	if _versus != null:
		_versus.refresh()
	if state.ended:
		_end.show_result()


func _on_cell_pressed(cell: int) -> void:
	_view.selected = -1 if cell == _view.selected else cell
	_panel.set_selected(_view.selected)


# --- API utilisée par les panneaux ---

func send(cmd: Dictionary) -> void:
	Net.send_command(cmd)


func me() -> Dictionary:
	return state.players.get(my_id, {})


func viewed() -> Dictionary:
	return state.boards[viewed_board] if viewed_board < state.boards.size() else {}


func view_board(index: int) -> void:
	viewed_board = clampi(index, 0, state.board_count - 1)
	_view.board_index = viewed_board
	_view.selected = -1
	_panel.set_selected(-1)
	if _versus != null:
		_versus.refresh()


func difficulty_name() -> String:
	return Data.db.difficulties[int(config.get("difficulty", 1))]["name"]


func player_on_board(index: int) -> int:
	if not is_versus:
		return 0
	return order[index] if index < order.size() else 0


func show_toast(message: String) -> void:
	_toast.text = message
	_toast.reset_size()
	_toast.position.x = (size.x - _toast.size.x) / 2.0
	_toast.visible = true
	_toast_time = 2.5


func ask_quit() -> void:
	_confirm.popup_centered()


func go_back() -> void:
	if _view.selected >= 0:
		_on_cell_pressed(_view.selected)
	else:
		ask_quit()


func quit_game() -> void:
	Net.leave()
	_nav.show_menu()

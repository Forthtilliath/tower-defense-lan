class_name GameScreen
extends Control
## Écran de partie : plateau au centre, barre d'infos en haut, panneau d'actions à droite.
## Toutes les actions passent par Net.send_command ; l'affichage suit les instantanés de l'hôte.

const SIDE_WIDTH := 320

var config: Dictionary
## Commande en attente d'une case (voir aim), vide sinon.
var aiming := {}
var state: ViewState
var map: MapDef
var my_id := 1
var my_board := 0
var viewed_board := 0
var names := {}  # id -> pseudo
var colors := {}  # id -> Color
var builders := {}  # id -> index du bâtisseur
var kits := {}  # id -> PlayerKit (bâtisseur et talents)
var order: Array[int] = []  # ids dans l'ordre de la partie
var is_versus := false
var _coop: CoopPanel
## Fin de partie pour ce compte (MatchRecap.close : expérience, étoiles), vide tant qu'elle dure.
var recap := {}
var _start_lives := 0
var _last_wave := 0
var _map_version := 0
var _nav: Node
var _view: BoardView
var _hud: HudBar
var _panel: SidePanel
var _versus: VersusPanel
var _end: EndOverlay
var _toast: Label
var _toast_time := 0.0
var _confirm: ConfirmationDialog
var _talents: TalentPanel  # arbre en lecture seule, ouvert depuis la barre du haut


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
		builders[e[0]] = e[3]
		kits[e[0]] = PlayerKit.make(Data.db, e[3], e[4], e[5] if e.size() > 5 else [])
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
	_view.kit_of = func(id: int) -> Variant: return kits.get(id)
	if not is_versus:
		var ordered: Array[Color] = []
		for id in order:
			ordered.append(colors[id])
		_view.zone_colors = BoardPainter.zone_colors(map, ordered)
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
	else:
		_coop = CoopPanel.new(self)
		side.add_child(_coop)
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
	if state.map_version != _map_version:  # décor rasé ou case posée par un Terrassier
		_map_version = state.map_version
		_show_board_map()
	_hud.refresh()
	_panel.refresh()
	if _versus != null:
		_versus.refresh()
	if _coop != null:
		_coop.refresh()
	if state.wave != _last_wave:
		_last_wave = state.wave
		var mod := wave_modifier(state.wave - 1)
		if not mod.is_empty():
			show_toast("Vague spéciale : %s — %s" % [mod["name"], mod["description"]])
	if my_board < state.boards.size():  # vies de départ : le plus haut vu (étoiles de fin de partie)
		_start_lives = maxi(_start_lives, int(state.boards[my_board]["lives"]))
	if state.ended:
		if recap.is_empty():
			recap = MatchRecap.close(self, _start_lives)
			close_talents()  # le résultat ne doit pas rester caché sous l'arbre
		_end.show_result()


func _on_cell_pressed(cell: int) -> void:
	if not aiming.is_empty():  # pouvoir à viser ou tourelle à déplacer : cette case est la cible
		var cmd := aiming.duplicate()
		cmd[cmd.get("target", "cell")] = cell
		cmd.erase("target")
		aiming = {}
		send(cmd)
		return
	_view.selected = -1 if cell == _view.selected else cell
	_panel.set_selected(_view.selected)


# --- API utilisée par les panneaux ---

## Commande qui attend une case (pouvoir à viser, déplacement) : la prochaine case touchée la
## complète (clé « target » : où ranger la case, « cell » par défaut).
func aim(cmd: Dictionary, message: String) -> void:
	aiming = cmd
	show_toast(message)

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
	_show_board_map()
	_panel.set_selected(-1)
	if _versus != null:
		_versus.refresh()


## Carte du plateau affiché (changements du Terrassier compris) : décor redessiné, panneau à jour.
func _show_board_map() -> void:
	map = state.maps[viewed_board]
	_view.set_map(map)
	_panel.refresh(true)


## Vague spéciale de la vague n° index (0 = première), dictionnaire vide si normale.
func wave_modifier(index: int) -> Dictionary:
	if index < 0:
		return {}
	return state.data.wave_modifier(map.waves[mini(index, map.waves.size() - 1)])


## Portée de la tourelle envisagée, dessinée autour de la case sélectionnée (0 : rien).
func preview_range(reach: float) -> void:
	_view.preview_range = reach


func my_builder() -> int:
	return int(builders.get(my_id, 0))


func my_kit() -> PlayerKit:
	return kits.get(my_id, PlayerKit.make(Data.db, 0))


## Rythme « entre les vagues » : construire n'est possible que pendant la phase de construction.
func rhythm() -> int:
	return int(config.get("rhythm", 0)) if not is_versus else SimMatch.Rhythm.FREE


func host_launches() -> bool:
	return not is_versus and int(config.get("launch", 0)) == SimMatch.Launch.HOST


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


## Talents de la partie (ceux envoyés à l'hôte), sans pouvoir les changer ; la partie continue.
func open_talents() -> void:
	if _talents == null:
		_talents = TalentPanel.viewer(my_kit(), NetPayloads.heritage_on(config), close_talents)
		add_child(_talents)


func close_talents() -> void:
	if _talents != null:
		_talents.queue_free()
		_talents = null


func go_back() -> void:
	if _talents != null:
		close_talents()
	elif _view.selected >= 0:
		_on_cell_pressed(_view.selected)
	else:
		ask_quit()


func quit_game() -> void:
	Net.leave()
	_nav.show_menu()

extends Node
## Captures d'écran automatiques (vérification visuelle), lancé avec
## « -- --screenshot=<dossier> [--mode=0|1] [--map=N] ». Ouvre une fenêtre quelques secondes.

var main: Node
var role := ""
var _dir := ""
var _mode := 0
var _map := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_dir = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--mode="):
			_mode = int(arg.trim_prefix("--mode="))
		elif arg.begins_with("--map="):
			_map = int(arg.trim_prefix("--map="))
	_run()


func _run() -> void:
	var tag := "versus" if _mode == 1 else "coop"
	main.show_menu()
	await _wait(0.5)
	_shot("1-menu")
	# Arbre de talents (sans réseau) : celui de l'Arcaniste, avec la progression de cet appareil
	var tree := TalentPanel.new(2, func() -> void: pass, func() -> void: pass)
	main.add_child(tree)
	await _wait(0.4)
	_shot("1b-talents")
	tree.queue_free()
	Net.host("Forth")
	Net.set_option("mode", _mode)
	Net.set_option("map", _map)
	main.show_lobby()
	await _wait(0.6)
	_shot("2-salon-%s" % tag)
	Net.start_match()
	await _wait(0.4)
	_shot("2b-avant-premiere-vague-%s" % tag)
	# Démonstration : assez d'or, et saut à la vague 9 (troll, chamans) pour montrer les effets
	Net.host_loop.sim.players[1]["gold"] += 1000
	Net.host_loop.sim.wave_index = 7
	await _wait(0.3)
	var map: MapDef = Data.db.maps[_map]
	var placed := 0
	# Arbalète, Tambour (aura), Brasier, Gong, Épouvantail, Flûte (indices dans tower_order)
	var plan := [0, 15, 10, 12, 13, 14]
	for cell in [2 * map.width + 2, 3 * map.width + 3, 3 * map.width + 6, 5 * map.width + 5, 2 * map.width + 9, 6 * map.width + 5]:
		if map.is_buildable(cell) and placed < plan.size():
			Net.send_command({"a": "build", "cell": cell, "tower": plan[placed]})
			placed += 1
	Net.send_command({"a": "upgrade", "cell": 2 * map.width + 2})
	Net.send_command({"a": "ready"})
	Net.send_command({"a": "speed"})
	if _mode == 1:
		Net.send_command({"a": "send", "monster": 0})
	await _wait(3.0)
	var screen: GameScreen = main.get("_screen")
	screen._on_cell_pressed(2 * map.width + 2)
	await _wait(0.4)
	_shot("3-partie-%s" % tag)
	screen._on_cell_pressed(4 * map.width + 13)
	var panel: SidePanel = screen.get("_panel")
	panel.set("_previewed", "thorns")  # fiche d'une tourelle avant construction
	panel.refresh(true)
	await _wait(0.3)
	_shot("4-construire-%s" % tag)
	await _showcase(map)
	Net.leave()
	get_tree().quit(0)


## Vitrine du rendu : toutes les tourelles posées d'office et un monstre de chaque sorte,
## placés directement dans la simulation (sans les règles de construction ni les talents).
func _showcase(map: MapDef) -> void:
	var board: SimBoard = Net.host_loop.sim.boards[0]
	var free: Array[int] = []
	for i in map.cell_count():
		if board.can_build(i):
			free.append(i)
	var types: Array = Data.db.tower_order
	for k in mini(types.size(), free.size()):
		board.add_tower(free[k * free.size() / types.size()], types[k], 1, 0)
	var monsters: Array = Data.db.monster_order
	for k in monsters.size():
		board.spawn(monsters[k], 50.0, -1, 2.0 + k * 1.6)
	await _wait(1.2)
	_shot("5-vitrine")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(name + ".png")
	img.save_png(path)
	print("CAPTURE ", path)

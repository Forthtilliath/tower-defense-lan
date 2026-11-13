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
	main.show_start()
	await _wait(0.5)
	_shot("0-accueil")
	main.show_new_account()
	await _wait(0.3)
	_shot("0b-nouveau-compte")
	main.show_accounts()  # comptes de cet appareil (retour à l'accueil s'il n'y en a aucun)
	await _wait(0.4)
	_shot("0c-continuer")
	var shown: Node = main.get("_screen")
	if shown is AccountsScreen:
		var hovered: Array = shown.find_children("*", "Button", true, false)
		if not hovered.is_empty():
			hovered[0].mouse_entered.emit()  # aspect de la carte au survol
			await _wait(0.2)
			_shot("0c2-continuer-survol")
	var accounts: Array = AccountStore.list(Data.db)["accounts"]
	var screen_now: Node = main.get("_screen")
	if screen_now is AccountsScreen and not accounts.is_empty():
		screen_now._confirm_remove(accounts[0])  # affichée puis refermée : rien n'est supprimé
		await _wait(0.3)
		_shot("0d-suppression")
		for child in screen_now.get_children():
			if child is ConfirmationDialog:
				child.queue_free()
		main.show_send(accounts[0]["id"])
		await _wait(0.3)
		_shot("0f-envoyer")
	main.show_receive()
	await _wait(1.5)  # laisse passer une annonce : l'écran d'envoi ouvert juste avant n'écoute plus
	_shot("0e-recevoir")
	# Compte invité, jamais enregistré : la suite ne touche pas aux comptes de l'appareil.
	Progress.use_guest("Forth")
	main.show_menu()
	await _wait(0.5)
	_shot("1-menu")
	# Arbre de talents (sans réseau) : celui de l'Arcaniste, avec la progression de cet appareil
	var tree := TalentPanel.new(1, func() -> void: pass, func() -> void: pass)
	main.add_child(tree)
	await _wait(0.4)
	_shot("1b-talents")
	tree.queue_free()
	_fill_history()
	main.show_history()
	await _wait(0.4)
	_shot("1c-historique")
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
	var menu: GameMenu = screen.get("_menu")
	menu.open()  # l'hôte qui ouvre le menu met la partie en pause
	await _wait(0.5)
	_shot("4b-menu-%s" % tag)
	menu.open_bestiary()
	await _wait(0.4)
	_shot("4c-bestiaire")
	menu.close_all()
	await _wait(0.3)
	screen.toggle_pause()
	await _wait(0.5)
	_shot("4d-pause-%s" % tag)
	screen.toggle_pause()
	await _wait(0.3)
	await _showcase(map)
	Net.leave()
	get_tree().quit(0)


## Vitrine du rendu : toutes les tourelles posées d'office et un monstre de chaque sorte,
## placés directement dans la simulation (sans les règles de construction ni les talents).
func _showcase(map: MapDef) -> void:
	var board: SimBoard = Net.host_loop.sim.boards[0]
	# Terrassier : le premier arbre rasé, une Rune posée sur la case voisine si elle est libre
	var tree := board.map.cells.find(MapDef.Cell.TREE)
	if tree >= 0:
		BoardTerrain.raze(board, tree)
		if board.map.is_buildable(tree + 1) and board.map.special_at(tree + 1) < 0:
			BoardTerrain.place(board, tree + 1, 2)
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


## Quelques parties pour le compte invité (jamais enregistré) : historique et étoiles du salon.
func _fill_history() -> void:
	var base := {"t": int(Time.get_unix_time_from_system()) - 86400, "map": Data.db.maps[_map].id, "diff": "normal", "mode": "coop",
		"won": true, "wave": 20, "waves": 20, "lives": 18, "start": 20, "stars": 3, "class": "arcanist", "lvl": 12, "xp": 640, "team": []}
	var games := [
		{"team": [["Atthis", "support"], ["Bob", "gunner"]], "lives": 54, "start": 60},
		{"won": false, "stars": 0, "wave": 14, "lives": 0, "diff": "hard", "team": [["Atthis", "support"]], "xp": 210},
		{"lives": 20, "stars": 2, "class": "gunner", "lvl": 7, "diff": "easy", "start": 30},
		{"lives": 6, "stars": 1, "map": Data.db.maps[(_map + 1) % Data.db.maps.size()].id},
	]
	for i in games.size():
		var g := base.duplicate(true)
		g.merge(games[games.size() - 1 - i], true)
		g["t"] += i * 3600
		MatchHistory.add(Progress.history, g)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(name + ".png")
	img.save_png(path)
	print("CAPTURE ", path)

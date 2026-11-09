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
	Net.host("Forth")
	Net.set_option("mode", _mode)
	Net.set_option("map", _map)
	main.show_lobby()
	await _wait(0.6)
	_shot("2-salon-%s" % tag)
	Net.start_match()
	await _wait(0.3)
	var map: MapDef = Data.db.maps[_map]
	var placed := 0
	for cell in [2 * map.width + 2, 3 * map.width + 11, 5 * map.width + 4, 2 * map.width + 9, 6 * map.width + 5]:
		if map.is_buildable(cell):
			Net.send_command({"a": "build", "cell": cell, "tower": placed % 4})
			placed += 1
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
	await _wait(0.3)
	_shot("4-construire-%s" % tag)
	Net.leave()
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(name + ".png")
	img.save_png(path)
	print("CAPTURE ", path)

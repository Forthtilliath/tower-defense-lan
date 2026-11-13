extends Node
## Captures d'écran de la stratégie du joueur automatique : une partie par spécialisation (ou
## celle demandée) sur une carte, jouée dans l'interface, avec une capture à chaque vague
## demandée et une à la fin. Ouvre une fenêtre. Lancé avec
## « -- --botshots=<dossier> [--map=N] [--level=N] [--difficulty=N] [--class=N] [--spec=N] [--waves=10,20] ».
## Fichiers : <dossier>/<classe>-<spécialisation>-v<vague>.png et -fin.png.

const Bot := preload("res://tests/bot/balance_bot.gd")
## Pas de simulation joués entre deux images (2 s de jeu par image).
const STEPS_PER_FRAME := 40
## Secondes de jeu après le départ d'une vague avant sa capture (les monstres sont sur la route).
const SETTLE := 12.0

var main: Node
var role := ""
var _dir := ""
var _map := 0
var _level := Bot.BOT_LEVEL
var _difficulty := 1
var _class := -1
var _spec := -1
var _waves := [10, 20]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"--botshots":
				_dir = kv[1]
			"--map":
				_map = int(kv[1])
			"--level":
				_level = int(kv[1])
			"--difficulty":
				_difficulty = int(kv[1])
			"--class":
				_class = int(kv[1])
			"--spec":
				_spec = int(kv[1])
			"--waves":
				_waves = Array(kv[1].split(",")).map(func(s: String) -> int: return int(s))
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	var gd: GameData = Data.db
	var bot = Bot.new()
	Progress.use_guest("Bot")
	for b in gd.builders.size():
		if _class >= 0 and b != _class:
			continue
		for s in bot.spec_count(gd, b):
			if _spec >= 0 and s != _spec:
				continue
			await _play(gd, bot, b, s)
	get_tree().quit(0)


## Une partie : salon, kit du bot, départ, puis la simulation avancée image par image.
func _play(gd: GameData, bot, b: int, s: int) -> void:
	var name := "%s-%s" % [gd.builders[b]["id"], bot.spec_id(gd, b, s)]
	Net.host("Bot")
	Net.set_option("mode", SimMatch.Mode.COOP)
	Net.set_option("map", _map)
	Net.set_choice(1, "vote", _difficulty)
	Net.set_choice(1, "kit", {"b": b, "lv": _level, "t": bot.auto_talents(gd, b, _level, s), "h": []})
	main.show_lobby()
	await _wait(0.2)
	Net.start_match()
	var sim: SimMatch = Net.host_loop.sim
	Net.host_loop = null  # la simulation est avancée ici, pas par la boucle de l'hôte
	await _wait(0.3)
	bot.start(sim)
	var shot_wave := -1
	var since_wave := 0.0
	var frames := 0
	while not sim.ended and frames < 4000:
		for k in STEPS_PER_FRAME:
			if sim.ended:
				break
			var before := sim.wave_index
			bot.tick(sim)
			since_wave += Bot.DT
			if sim.wave_index != before:
				since_wave = 0.0
		_show(sim)
		await _wait(0.0)
		frames += 1
		var wave := sim.wave_index + 1
		if _waves.has(wave) and shot_wave != wave and (since_wave >= SETTLE or sim.ended):
			shot_wave = wave
			await _shot("%s-v%d" % [name, wave])
	_show(sim)
	await _wait(0.1)
	var screen: Node = main.get("_screen")
	if screen != null and screen.get("_end") != null:
		screen.get("_end").visible = false  # la fin de partie cacherait le plateau
	await _shot("%s-fin" % name)
	print("PARTIE %s : %s à la vague %d, vies %d" % [name, sim.result, sim.wave_index + 1, sim.boards[0].lives])
	Net.leave()
	await _wait(0.2)


## Transmet l'état à l'écran de jeu, comme la boucle de l'hôte le ferait.
func _show(sim: SimMatch) -> void:
	var snap := sim.snapshot()
	snap["speed"] = 1
	snap["iv"] = 0.5  # intervalle affiché (l'écran interpole) ; la partie avance plus vite que ça
	Net.snapshot_received.emit(snap)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _wait(0.1)
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(name + ".png")
	img.save_png(path)
	print("CAPTURE ", path)

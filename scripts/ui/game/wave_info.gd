class_name WaveInfo
extends RefCounted
## Info-bulle d'une entrée du plateau : ce qui en sortira à la prochaine vague (nombre de chaque
## monstre, bonus, vague spéciale), ou pourquoi rien n'en sortira.


## Multiplicateur du nombre de monstres de la partie (difficulté, renfort coop), pour l'annoncer.
static func count_mult(game: GameScreen) -> float:
	return WaveScaling.count_mult(Data.db, game.map, game.difficulty(), not game.is_versus, game.order.size())


## Chemins défendus (carte à couloirs séparés en coop : un par joueur) ; vide : tous.
static func lane_paths(game: GameScreen) -> Array[int]:
	if game.is_versus or game.map.lanes <= 1:
		return []
	return game.map.open_paths(game.order.size())


static func entry_text(game: GameScreen, path: int) -> String:
	var s := game.state
	var map := game.map
	var label: int = map.path_labels[path]
	var name := "Entrée %d" % label if label > 0 else "Entrée des monstres"
	if s.wave >= s.total:
		return name + "\nPlus aucune vague à venir."
	var lanes := lane_paths(game)
	if not lanes.is_empty() and not lanes.has(path):
		return name + "\nCouloir fermé : aucun joueur ne le défend dans cette partie."
	var coming := MapSpawns.wave_paths(map, s.wave)
	var lines := ["%s · vague %d / %d" % [name, s.wave + 1, s.total]]
	if not coming.is_empty() and not coming.has(path):
		lines.append("Rien ne sort d'ici à cette vague (%s)." % EntryPainter.text(map, s.wave).to_lower())
		return "\n".join(lines)
	var data := s.data
	var wave: Dictionary = data.waves[map.waves[mini(s.wave, map.waves.size() - 1)]]
	var mod := game.wave_modifier(s.wave)
	if not mod.is_empty():
		lines.append("Vague spéciale « %s » : %s" % [mod["name"], mod["description"]])
	var shared := coming.size() if not coming.is_empty() else (lanes.size() if not lanes.is_empty() else map.start_count())
	lines.append("Toute la vague%s :" % (" (répartie entre %d entrées)" % shared if shared > 1 else ""))
	lines.append(MonsterText.wave_text(data, wave, count_mult(game)))
	return "\n".join(lines)

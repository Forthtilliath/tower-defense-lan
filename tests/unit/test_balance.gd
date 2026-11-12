extends "res://tests/unit/test_base.gd"
## Équilibrage, avec le joueur automatique de balance_bot.gd : courbe de progression voulue
## (niveau 1, 10, 15), coopération en équipes mixtes, partie perdue sans tourelle.

const Bot := preload("res://tests/bot/balance_bot.gd")
const DT := 0.05
const EASY := 0
const NORMAL := 1
const HARD := 2
## Équipes mixtes, comme en vraie coopération : Artilleur et Arcaniste, puis Fléau et Support.
const TEAM := [0, 1, 2, 3]
const LANE_TEAM := [0, 1, 2, 0]

var bot = Bot.new()


func play(gd: GameData, map_index: int, count: int, difficulty: int, options := {}, builders := [], level := Bot.BOT_LEVEL) -> SimMatch:
	return bot.play(gd, map_index, count, difficulty, options, builders, level)


## Niveau 10 en Normal : le joueur de référence gagne une bonne partie des cartes (pas forcément
## toutes : les vagues de squelettes et de fantômes demandent d'autres tourelles que les siennes).
func test_level_ten_wins_most_maps_in_normal() -> void:
	var gd := load_data()
	var lost := []
	for i in gd.maps.size():
		var sim := play(gd, i, 1, NORMAL)
		if sim.result != "victory":
			lost.append("%s (vague %d)" % [gd.maps[i].id, sim.wave_index + 1])
	check(lost.size() <= 3, "niveau 10 en Normal : trop de cartes perdues : %s" % ", ".join(lost))


func test_bot_wins_duo_coop() -> void:
	var gd := load_data()
	var sim := play(gd, 1, 2, NORMAL, {}, TEAM)
	check(sim.result == "victory", "duo : %s à la vague %d" % [sim.result, sim.wave_index + 1])


## Grandes cartes : gagnées à 2 et à 4 ; une petite carte à 4 aussi (renforcement coop).
## À 4 sur une carte à couloirs séparés, chacun défend un couloir plein : l'équipe joue sans Support
## (classe d'équipe, moins utile là, choix assumé le 2026-11-11 ; son passif l'y aide sans suffire au bot).
func test_bot_teams_win_big_maps() -> void:
	var gd := load_data()
	for entry in [[6, 2], [6, 4], [7, 2], [7, 4], [8, 2], [8, 4], [1, 4]]:
		var team: Array = LANE_TEAM if gd.maps[entry[0]].lanes > 1 and entry[1] >= 4 else TEAM
		var sim := play(gd, entry[0], entry[1], NORMAL, {}, team)
		check(sim.result == "victory", "%s à %d : %s à la vague %d" % [gd.maps[entry[0]].id, entry[1], sim.result, sim.wave_index + 1])


## Chaque spécialisation de chaque classe gagne aux côtés d'un Artilleur, et gagne sa part d'or :
## même le Support, qui fait peu de dégâts, est payé pour ses contrôles (prime partagée selon la contribution).
func test_every_spec_wins_in_a_duo() -> void:
	var gd := load_data()
	for b in gd.builders.size():
		for s in bot.spec_count(gd, b):
			var sim := play(gd, 0, 2, NORMAL, {}, [0, [b, s]])
			check(sim.result == "victory", "%s / %s : %s à la vague %d" % [gd.builders[b]["id"], bot.spec_id(gd, b, s), sim.result, sim.wave_index + 1])


func test_damage_builders_win_solo() -> void:
	var gd := load_data()
	for b in gd.builders.size():
		if gd.builders[b]["id"] == "support":
			continue  # classe de soutien : faite pour jouer en équipe
		var sim := play(gd, 0, 1, NORMAL, {}, [b])
		check(sim.result == "victory", "%s : %s à la vague %d" % [gd.builders[b]["id"], sim.result, sim.wave_index + 1])


func test_bot_wins_between_waves_rhythm() -> void:
	var gd := load_data()
	var sim := play(gd, 0, 2, NORMAL, {"rhythm": SimMatch.Rhythm.BETWEEN})
	check(sim.result == "victory", "entre les vagues : %s à la vague %d" % [sim.result, sim.wave_index + 1])


func test_difficulty_ordering() -> void:
	var gd := load_data()
	var easy := play(gd, 0, 1, 0)
	var nightmare := play(gd, 0, 1, 3)
	check(easy.result == "victory", "Facile gagné")
	check(_score(nightmare) < _score(easy), "Cauchemar plus dur que Facile : %f / %f" % [_score(nightmare), _score(easy)])


func test_no_tower_loses() -> void:
	var gd := load_data()
	var sim := SimMatch.new(gd, 0, SimMatch.Mode.COOP, [[1, "Passif", 0]])
	sim.apply_command(1, {"a": "ready"})
	for i in int(900.0 / DT):
		sim.step(DT)
		if sim.ended:
			break
	check(sim.result == "defeat", "défaite attendue sans tourelle : %s" % sim.result)


## Progression : vagues franchies + part des vies restantes.
func _score(sim: SimMatch) -> float:
	return sim.wave_index + float(sim.boards[0].lives) / float(sim.difficulty["lives"])


## Courbe de progression voulue : au niveau 1 (0 XP, un seul point de talent), chaque classe gagne
## en Facile la carte la plus facile ; en Normal, la carte la plus dure demande de progresser pour
## la plupart des classes.
func test_level_one_beginners() -> void:
	var gd := load_data()
	var hardest: int = hard_maps(gd)[-1]
	var lost := 0
	for b in gd.builders.size():
		var easy := play(gd, 0, 1, EASY, {}, [b], 1)
		check(easy.result == "victory", "%s niveau 1 en Facile : %s à la vague %d" % [gd.builders[b]["id"], easy.result, easy.wave_index + 1])
		lost += 0 if play(gd, hardest, 1, NORMAL, {}, [b], 1).result == "victory" else 1
	check(lost * 2 > gd.builders.size(), "niveau 1 en Normal : %s se gagne trop facilement (%d classe(s) sur %d la perdent)" % [gd.maps[hardest].id, lost, gd.builders.size()])


## Niveau 1 en Normal, toutes classes et toutes cartes : le joueur débutant en finit quelques-unes,
## pas la plupart (un humain joue mieux que le bot : la marge doit rester nette).
func test_level_one_wins_few_maps_in_normal() -> void:
	var gd := load_data()
	var won := 0
	for b in gd.builders.size():
		for m in gd.maps.size():
			won += 1 if play(gd, m, 1, NORMAL, {}, [b], 1).result == "victory" else 0
	var total := gd.builders.size() * gd.maps.size()
	check(won * 5 <= total * 2, "niveau 1 en Normal : %d parties gagnées sur %d (40 %% au plus)" % [won, total])


## Au niveau 20, chaque classe de dégâts (Artilleur, Arcaniste, Fléau) a au moins une
## spécialisation qui finit la plupart des cartes difficiles en Difficile (un joueur choisit sa
## spécialisation selon la carte) ; les classes utilitaires, elles, comptent sur le groupe.
## Niveau 15 avant la refonte des difficultés (Difficile : +20 % de PV, +5 % de monstres).
func test_level_twenty_wins_hard_maps_in_hard() -> void:
	var gd := load_data()
	for b in [0, 1, 2]:
		var best := []
		for s in bot.spec_count(gd, b):
			var lost := []
			for m in hard_maps(gd):
				var sim := play(gd, m, 1, HARD, {}, [[b, s]], 20)
				if sim.result != "victory":
					lost.append("%s/%s : %s (vague %d)" % [gd.builders[b]["id"], bot.spec_id(gd, b, s), gd.maps[m].id, sim.wave_index + 1])
			if best.is_empty() or lost.size() < best.size():
				best = lost
			if lost.size() <= 1:
				break
		check(best.size() <= 1, "niveau 20 en Difficile, meilleure spécialisation : %s" % ", ".join(best))


func hard_maps(gd: GameData) -> Array[int]:
	var out: Array[int] = []
	for m in gd.maps.size():
		if gd.maps[m].tier == 2:
			out.append(m)
	return out

class_name WaveScaling
extends RefCounted
## Renfort des vagues : nombre et PV des monstres selon la difficulté et le nombre de joueurs.
## Utilisé par la simulation (SimMatch) et par l'écran pour annoncer la prochaine vague.


## Renfort coop selon le nombre de joueurs : [PV, nombre de monstres, or des joueurs].
## Sur une carte à plusieurs couloirs, seuls les couloirs ouverts (un par joueur au départ)
## reçoivent des monstres, chacun une vague solo complète. Si des joueurs partent, les couloirs
## restent ouverts : ceux qui restent en défendent plusieurs, avec l'or en proportion.
static func coop(data: GameData, lanes_count: int, player_count: int) -> Array:
	var lanes := float(lanes_count)
	var per_lane := maxf(1.0, float(player_count)) / lanes
	if per_lane < 1.0:
		return [1.0, lanes, 1.0 / per_lane]
	var extra := per_lane - 1.0
	var hp := 1.0 + float(data.coop_scaling["hp"]) * extra
	var count := lanes * (1.0 + float(data.coop_scaling["count"]) * extra)
	return [hp, count, 1.0]


## Couloirs qui reçoivent des monstres au départ d'une partie coop à player_count joueurs.
static func lanes_open(map: MapDef, player_count: int) -> int:
	var paths := map.open_paths(player_count)
	return paths.size() if map.lanes > 1 and not paths.is_empty() else map.lanes


## Multiplicateur du nombre de monstres d'une partie (difficulté, renfort coop), tel que
## SimMatch.launch_next_wave l'applique.
static func count_mult(data: GameData, map: MapDef, difficulty: Dictionary, coop_mode: bool, player_count: int) -> float:
	var mult := float(difficulty["count"])
	if coop_mode:
		mult *= float(coop(data, lanes_open(map, player_count), player_count)[1])
	return mult


## Nombre de monstres d'un groupe de vague (même arrondi que SimBoard.queue_wave).
static func group_count(data: GameData, wave: Dictionary, group: Dictionary, mult: float) -> int:
	var mod: Dictionary = data.modifiers.get(wave.get("modifier", ""), {})
	return maxi(1, roundi(int(group["count"]) * mult * float(mod.get("count", 1.0))))

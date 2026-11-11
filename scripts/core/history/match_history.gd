class_name MatchHistory
extends RefCounted
## Historique des parties d'un compte et étoiles gagnées sur chaque carte (format et validation
## du fichier : HistoryFile).
##
## {"games": [partie, …] (la plus récente d'abord, MAX_GAMES au plus),
##  "best": {"<carte>": {"<difficulté>": étoiles}}}
## Une partie : {t (date unix), map, diff, mode ("coop"|"versus"), won, wave, waves, lives,
## start (vies de départ), stars, class, lvl, xp, team: [[pseudo, classe], …] (les autres joueurs)}.
## Les records sont gardés à part : une vieille victoire sortie de l'historique garde ses étoiles.

const MAX_GAMES := 100
const MODES := ["coop", "versus"]
## Étoiles d'une victoire en coopération, selon la part des vies de départ encore là :
## 3 à 90 % ou plus (18 vies sur 20 en Normal seul), 2 à 50 % ou plus, 1 sinon.
const THREE_STARS := 0.9
const TWO_STARS := 0.5


static func empty() -> Dictionary:
	return {"games": [], "best": {}}


## Étoiles d'une partie : 0 pour une défaite ou le versus (pas de vies communes à défendre).
static func stars(won: bool, coop: bool, lives: int, start_lives: int) -> int:
	if not won or not coop:
		return 0
	var ratio := float(lives) / float(maxi(1, start_lives))
	if ratio >= THREE_STARS:
		return 3
	return 2 if ratio >= TWO_STARS else 1


## Ajoute une partie en tête, coupe l'historique à MAX_GAMES et met à jour le record de la carte.
## Renvoie true si c'est un nouveau record d'étoiles pour cette carte et cette difficulté.
static func add(history: Dictionary, game: Dictionary) -> bool:
	var games: Array = history["games"]
	games.push_front(game)
	if games.size() > MAX_GAMES:
		games.resize(MAX_GAMES)
	var earned := int(game["stars"])
	if earned <= best(history, game["map"], game["diff"]):
		return false
	var best_all: Dictionary = history["best"]
	if not best_all.has(game["map"]):
		best_all[game["map"]] = {}
	best_all[game["map"]][game["diff"]] = earned
	return true


## Meilleur nombre d'étoiles sur cette carte à cette difficulté (0 : jamais gagnée).
static func best(history: Dictionary, map_id: String, diff_id: String) -> int:
	return int(history["best"].get(map_id, {}).get(diff_id, 0))


## Parties qui correspondent aux filtres (vide = pas de filtre) : classe jouée, coéquipier
## (pseudo), classe d'un coéquipier, carte. solo : seulement les parties sans coéquipier.
static func filter(games: Array, filters: Dictionary) -> Array:
	var cls: String = filters.get("class", "")
	var mate: String = filters.get("mate", "")
	var mate_class: String = filters.get("mate_class", "")
	var map_id: String = filters.get("map", "")
	var solo: bool = filters.get("solo", false)
	var out := []
	for g in games:
		if (cls != "" and g["class"] != cls) or (map_id != "" and g["map"] != map_id):
			continue
		if solo and not g["team"].is_empty():
			continue
		if mate != "" and not g["team"].any(func(e: Array) -> bool: return e[0] == mate):
			continue
		if mate_class != "" and not g["team"].any(func(e: Array) -> bool: return e[1] == mate_class):
			continue
		out.append(g)
	return out


## Pseudos des coéquipiers rencontrés, par ordre alphabétique.
static func mates(games: Array) -> Array[String]:
	var seen := {}
	for g in games:
		for e in g["team"]:
			seen[e[0]] = true
	var out: Array[String] = []
	out.assign(seen.keys())
	out.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return out


## {count, wins, stars (total des étoiles gagnées)} d'une liste de parties.
static func summary(games: Array) -> Dictionary:
	var wins := 0
	var total := 0
	for g in games:
		if g["won"]:
			wins += 1
		total += int(g["stars"])
	return {"count": games.size(), "wins": wins, "stars": total}

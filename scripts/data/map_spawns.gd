class_name MapSpawns
extends RefCounted
## Par où arrivent les monstres d'une carte : couloirs ouverts selon le nombre de joueurs (cartes
## à couloirs séparés) et entrées par vague (cartes à départs numérotés « 1 » à « 4 »).
## Un départ « S » est toujours ouvert ; un départ numéroté ne l'est qu'aux vagues dont le
## motif (MapDef.entries, répété en boucle) contient son numéro.

const MAX_ENTRIES := 4
const MAX_PATTERN := 40


## Couloirs ouverts pour `players` joueurs sur une carte à plusieurs couloirs : un par joueur
## (jusqu'à `lanes`), celui qui traverse la zone de chacun (zone 0 pour le 1er, etc.) ; tous les
## départs sur une carte à un seul couloir.
static func open_paths(m: MapDef, players: int) -> Array[int]:
	var out: Array[int] = []
	if m.lanes <= 1:
		for p in m.start_count():
			out.append(p)
		return out
	for z in clampi(players, 1, m.lanes):
		for p in m.start_count():
			if not out.has(p) and start_zone(m, p) == z:
				out.append(p)
				break
	for p in m.start_count():  # carte sans zones ou zones incomplètes : les premiers départs
		if out.size() >= clampi(players, 1, m.lanes):
			break
		if not out.has(p):
			out.append(p)
	return out


## Zone la plus présente autour du départ d'un chemin (-1 si aucune).
static func start_zone(m: MapDef, path: int) -> int:
	var c := Vector2i(m.ground_paths[path][0].floor())
	var counts := {}
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var at := c + Vector2i(dx, dy)
			if m.in_bounds(at) and m.zones[at.y * m.width + at.x] >= 0:
				var z: int = m.zones[at.y * m.width + at.x]
				counts[z] = int(counts.get(z, 0)) + 1
	var best := -1
	for z in counts:
		if best < 0 or counts[z] > counts[best]:
			best = z
	return best


## Numéros d'entrée ouverts à la vague n° wave (0 = première), ex. "12" ; "" si la carte n'a
## pas d'entrées par vague (tous ses départs servent à chaque vague).
static func wave_entries(m: MapDef, wave: int) -> String:
	if m.entries.is_empty():
		return ""
	return m.entries[posmod(wave, m.entries.size())]


## Chemins où apparaissent les monstres de la vague n° wave ; vide : tous (règle habituelle).
static func wave_paths(m: MapDef, wave: int) -> Array[int]:
	var out: Array[int] = []
	var open := wave_entries(m, wave)
	if open == "":
		return out
	for p in m.start_count():
		var label: int = m.path_labels[p]
		if label == 0 or open.contains(str(label)):
			out.append(p)
	return out


## Départ du chemin (case) : pour signaler sur le plateau les entrées de la prochaine vague.
static func path_start(m: MapDef, path: int) -> int:
	var c := Vector2i(m.ground_paths[path][0].floor())
	return c.y * m.width + c.x


## Vérifie le motif d'entrées d'une carte. Renvoie "" ou un message d'erreur.
static func check(m: MapDef, pattern: Array) -> String:
	var labels := {}
	for l in m.path_labels:
		if l > 0:
			labels[l] = true
	if pattern.is_empty():
		return "" if labels.is_empty() else "départs numérotés sans motif d'entrées (entries)"
	if labels.is_empty():
		return "entries sans départ numéroté (1 à %d)" % MAX_ENTRIES
	if m.lanes > 1:
		return "entries impossible sur une carte à couloirs séparés"
	if pattern.size() > MAX_PATTERN:
		return "entries : %d motifs au plus" % MAX_PATTERN
	var used := {}
	for i in pattern.size():
		var e = pattern[i]
		if typeof(e) != TYPE_STRING or e == "" or String(e).length() > MAX_ENTRIES:
			return "entries[%d] : 1 à %d numéros attendus" % [i, MAX_ENTRIES]
		for ch in String(e):
			if not ch.is_valid_int() or not labels.has(int(ch)):
				return "entries[%d] : entrée « %s » absente de la carte" % [i, ch]
			used[int(ch)] = true
	for l in labels:
		if not used.has(l):
			return "entries : l'entrée %d ne sert jamais" % l
	return ""

class_name LobbyTexts
extends RefCounted
## Textes d'aide du salon : mode, rythme, lancement, carte, difficulté votée, bâtisseur.

const MODE_HELP := [
	"Une seule carte, vies communes. Chacun construit avec son or ; la prime d'un monstre est partagée selon la contribution de chacun.",
	"Chacun son plateau. Envoie des monstres chez ton voisin pour augmenter ton revenu. Le dernier en vie gagne.",
]
const RHYTHM_HELP := [
	"Rythme libre : construction à tout moment ; « Vague suivante » appelle la prochaine vague, même pendant une vague.",
	"Entre les vagues : construire, améliorer et vendre seulement quand la carte est vide ; aucune vague ne peut être appelée pendant une autre.",
]
const LAUNCH_HELP := [
	"Les vagues partent en avance quand tous les joueurs sont prêts.",
	"Seul l'hôte lance les vagues en avance.",
]


static func help(settings: Dictionary, player_count: int) -> String:
	var mode: int = settings["mode"]
	var lines := [MODE_HELP[mode]]
	if mode == SimMatch.Mode.COOP:
		lines.append(RHYTHM_HELP[settings["rhythm"]] + " " + LAUNCH_HELP[settings["launch"]])
	lines.append(map_text(Data.db.maps[settings["map"]], mode, player_count))
	return "\n".join(lines)


## « Quatre fiefs · carte en zones · 20 vagues · conseillée de 2 à 4 joueurs ».
static func map_text(map: MapDef, mode: int, player_count: int) -> String:
	var parts := [map.name, "difficulté %s" % DataSchema.MAP_TIERS[map.tier]]
	if mode == SimMatch.Mode.COOP:
		parts.append(MapDef.LAYOUT_NAMES[map.layout()].to_lower())
	parts.append("%d vagues" % map.waves.size())
	if map.min_players == map.max_players:
		parts.append("conseillée à %d" % map.min_players)
	elif map.min_players <= 1:
		parts.append("conseillée jusqu'à %d joueurs" % map.max_players)
	else:
		parts.append("conseillée de %d à %d joueurs" % [map.min_players, map.max_players])
	var text := " · ".join(parts)
	if mode == SimMatch.Mode.COOP and map.lanes > 1:
		var open := clampi(player_count, 1, map.lanes)
		text += "\n%d couloirs séparés : un par joueur reçoit des monstres (%d ouvert%s à %d), chacun avec la vague complète." % [
			map.lanes, open, "s" if open > 1 else "", player_count]
	if mode == SimMatch.Mode.COOP and map.layout() != MapDef.Layout.SHARED:
		text += "\nChacun ne construit que dans sa zone (couleur du joueur)%s." % (" ; les cases neutres sont communes" if map.layout() == MapDef.Layout.MIXED else "")
	return text


## « Difficulté retenue : Normal (2 votes) · Difficile (1) ».
static func vote_text(players: Dictionary) -> String:
	var count := Data.db.difficulties.size()
	var tally := NetPayloads.tally_votes(players, count)
	var chosen := NetPayloads.voted_difficulty(players, count)
	var d: Dictionary = Data.db.difficulties[chosen]
	var others := []
	for i in count:
		if i != chosen and tally[i] > 0:
			others.append("%s (%d)" % [Data.db.difficulties[i]["name"], tally[i]])
	var text := "Difficulté retenue : %s (%d vote%s)" % [d["name"], tally[chosen], "s" if tally[chosen] > 1 else ""]
	if not others.is_empty():
		text += " · " + ", ".join(others)
	return text + "\n%d vies, PV des monstres x%s, or de départ x%s. En cas d'égalité, la plus facile l'emporte." % [
		d["lives"], _num(d["hp"]), _num(d["gold"])]


static func builder_text(index: int) -> String:
	var b: Dictionary = Data.db.builders[index]
	var kit := PlayerKit.make(Data.db, index, Progress.talents(index))
	var names := []
	for id in Data.db.tower_order:
		if kit.allows(id):
			names.append(Data.db.towers[id]["name"])
	var specs := []
	for branch in b["branches"]:
		if not branch["trunk"]:
			specs.append(branch["name"])
	var chosen := kit.spec_name(Data.db) if kit.spec >= 0 else "à choisir dans les talents (%s)" % ", ".join(specs)
	return "%s : %s\nSpécialisation : %s.\nTes tourelles : %s." % [b["name"], b["description"], chosen, ", ".join(names)]


static func _num(v: float) -> String:
	return str(v).replace(".", ",")

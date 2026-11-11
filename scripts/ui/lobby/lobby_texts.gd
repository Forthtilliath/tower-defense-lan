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
## Versions courtes, affichées sous les options (le texte complet est en infobulle).
const MODE_SHORT := [
	"Une carte, vies communes ; primes partagées selon la contribution.",
	"Chacun son plateau : envoie des monstres chez ton voisin. Le dernier en vie gagne.",
]
const RHYTHM_SHORT := [
	"Construction à tout moment, vague suivante à la demande.",
	"Construction seulement quand la carte est vide.",
]
const LAUNCH_SHORT := [
	"Vagues en avance quand tous sont prêts.",
	"Seul l'hôte lance les vagues en avance.",
]
const HERITAGE_HELP := [
	"Héritage activé : chaque classe montée au niveau maximum donne son bonus aux autres classes du joueur.",
	"Héritage désactivé : aucun bonus d'héritage, chacun ne joue qu'avec sa classe et ses talents (plus équitable).",
]
const HERITAGE_SHORT := [
	"Bonus d'héritage actifs.",
	"Héritage désactivé : tous à égalité.",
]


## Résumé des options choisies, une ligne par option qui s'applique au mode.
static func short_help(settings: Dictionary) -> String:
	var mode: int = settings["mode"]
	var lines := [MODE_SHORT[mode]]
	if mode == SimMatch.Mode.COOP:
		lines.append("%s %s" % [RHYTHM_SHORT[settings["rhythm"]], LAUNCH_SHORT[settings["launch"]]])
	else:
		lines.append("Rythme et lancement : réservés à la coopération.")
	lines.append(HERITAGE_SHORT[int(settings.get("heritage", SimMatch.Heritage.ON))])
	return "\n".join(lines)


## « Carte en zones · 20 vagues · conseillée de 2 à 4 joueurs » (le nom est dans la liste).
static func map_text(map: MapDef, mode: int, player_count: int) -> String:
	var parts := []
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
	text = text.left(1).to_upper() + text.substr(1)
	if mode == SimMatch.Mode.COOP and map.lanes > 1:
		var open := clampi(player_count, 1, map.lanes)
		text += "\n%d couloirs séparés, %d ouvert%s (un par joueur)%s." % [map.lanes, open, "s" if open > 1 else "",
			" : les zones des autres sont fermées" if open < map.lanes else ""]
	if mode == SimMatch.Mode.COOP and map.layout() != MapDef.Layout.SHARED:
		text += "\nChacun construit dans sa zone (sa couleur)%s." % (", cases neutres communes" if map.layout() == MapDef.Layout.MIXED else "")
	return text


## « Tes étoiles : Facile ★★★ · Normal ★ » (records de ce compte sur la carte, par difficulté).
static func record_text(map_index: int) -> String:
	var parts := []
	for d in Data.db.difficulties.size():
		var stars := Progress.best_stars(map_index, d)
		if stars > 0:
			parts.append("%s %s" % [Data.db.difficulties[d]["name"], StarsView.text(stars)])
	if parts.is_empty():
		return "Carte pas encore gagnée avec ce compte."
	return "Tes étoiles : " + " · ".join(parts)


## [« Normal · 2 votes (Difficile : 1) », « 20 vies · PV des monstres x1 · or de départ x1 »].
static func vote_lines(players: Dictionary) -> Array[String]:
	var count := Data.db.difficulties.size()
	var tally := NetPayloads.tally_votes(players, count)
	var chosen := NetPayloads.voted_difficulty(players, count)
	var d: Dictionary = Data.db.difficulties[chosen]
	var others := []
	for i in count:
		if i != chosen and tally[i] > 0:
			others.append("%s : %d" % [Data.db.difficulties[i]["name"], tally[i]])
	var title := "%s · %d vote%s" % [d["name"], tally[chosen], "s" if tally[chosen] > 1 else ""]
	if not others.is_empty():
		title += " (%s)" % ", ".join(others)
	var detail := "%d vies · PV des monstres x%s · or de départ x%s.\nÉgalité : la plus facile l'emporte." % [
		d["lives"], _num(d["hp"]), _num(d["gold"])]
	return [title, detail]


## Bonus de la classe, spécialisation, tourelles en plus du tronc commun, héritage (listé même
## désactivé par l'hôte, avec la mention).
static func builder_text(index: int, heritage_active: bool) -> String:
	var b: Dictionary = Data.db.builders[index]
	var kit := PlayerKit.make(Data.db, index, Progress.talents(index), Progress.heritage() if heritage_active else [])
	var extra := []
	for id in Data.db.tower_order:
		if kit.allows(id) and not Data.db.common_towers.has(id):
			extra.append(Data.db.towers[id]["name"])
	var specs := []
	for branch in b["branches"]:
		if not branch["trunk"]:
			specs.append(branch["name"])
	var text := String(b["description"])
	if kit.spec >= 0:
		text += "\nSpécialisation : %s." % kit.spec_name(Data.db)
	else:
		text += "\nSpécialisation à choisir dans les talents : %s." % ", ".join(specs)
	if not extra.is_empty():
		text += "\nEn plus du tronc commun : %s." % ", ".join(extra)
	return text + heritage_text(index, heritage_active)


## « Héritage : Artilleur (+20 % de dégâts des tirs physiques), … » (vide sans classe au niveau
## maximum) ; « Héritage désactivé pour cette partie : … » si l'hôte l'a coupé.
static func heritage_text(builder: int, active: bool) -> String:
	var parts := []
	for h in heritage_classes(builder):
		parts.append("%s (%s)" % [Data.db.builders[h]["name"], heritage_bonus(h).trim_suffix(".")])
	if parts.is_empty():
		return ""
	return "\nHéritage%s : %s." % ["" if active else " désactivé pour cette partie", ", ".join(parts)]


## Classes de ce compte dont l'héritage profite à `builder` : montées au niveau maximum, sauf elle.
static func heritage_classes(builder: int) -> Array[int]:
	return PlayerKit.make(Data.db, builder, {}, Progress.heritage()).heritage


## Description du bonus d'héritage d'une classe (« +20 % de dégâts des tirs physiques. »).
static func heritage_bonus(builder: int) -> String:
	return String(Data.db.builders[builder]["heritage"]["description"])


static func _num(v: float) -> String:
	return str(v).replace(".", ",")

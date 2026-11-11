class_name MatchActions
extends RefCounted
## Actions des joueurs sur une partie (construire, améliorer, vendre, viser, envoyer, donner).
## Chaque action vérifie les règles et renvoie "" si elle est acceptée, sinon la raison du refus.

const LOCKED := "Construction possible seulement entre les vagues"
const CLOSED := "Zone fermée : aucun monstre ne passe par ce couloir"


## Aiguille une commande déjà vérifiée (Commands) vers l'action qui la joue.
static func dispatch(sim: SimMatch, id: int, p: Dictionary, board: SimBoard, cmd: Dictionary) -> String:
	match cmd["a"]:
		"build":
			return build(sim, id, p, board, cmd["cell"], cmd["tower"])
		"upgrade":
			return upgrade(sim, id, p, board, cmd["cell"])
		"sell":
			return sell(sim, id, p, board, cmd["cell"])
		"move":
			return move(sim, id, p, board, cmd["cell"], cmd["to"])
		"mode":
			return cycle_target(id, board, cmd["cell"])
		"raze":
			return raze(sim, id, p, board, cmd["cell"])
		"tile":
			return place_tile(sim, id, p, board, cmd["cell"], cmd["special"])
		"send":
			return send(sim, id, p, cmd["monster"])
		"give":
			return give(sim, id, p, cmd["to"], cmd["amount"])
		"power":
			return MatchPowers.use(sim, id, p, board, cmd["cell"])
		"ready":
			return MatchFlow.call_wave(sim, id)
	return "Commande inconnue"


static func build(sim: SimMatch, id: int, p: Dictionary, board: SimBoard, cell: int, type: String) -> String:
	if not MatchFlow.can_trade(sim):
		return LOCKED
	if not board.can_build(cell):
		return "Impossible de construire ici"
	if not p["kit"].allows(type):
		return "Ton bâtisseur ne sait pas construire cette tourelle"
	var zone := zone_refusal(sim, id, cell)
	if zone != "":
		return zone
	var cost: int = p["kit"].cost(sim.data.tower_levels(type)[0]["cost"], zone_discount(board, cell))
	if p["gold"] < cost:
		return "Or insuffisant"
	p["gold"] -= cost
	BoardLayout.on_build(board.add_tower(cell, type, id, cost, p["kit"]))
	return ""


## Zones de joueurs (coopération) : "" si le joueur peut construire sur cette case.
## Une zone dont tous les propriétaires ont quitté la partie devient commune ; une zone fermée
## (couloir sans joueur) le reste. Un joueur qui « roams » (Support) construit dans toutes les
## zones ouvertes, et sa zone est ouverte à tous (voir zone_open_to).
static func zone_refusal(sim: SimMatch, id: int, cell: int) -> String:
	var zone := sim.map.zone_at(cell)
	if sim.mode != SimMatch.Mode.COOP or zone < 0:
		return ""
	var n := sim.order.size()
	if sim.map.zone_closed(zone, n):
		return CLOSED
	var builders: Array[int] = []
	var connected: Array[bool] = []
	for pid in sim.order:
		builders.append(int(sim.players[pid]["builder"]))
		connected.append(bool(sim.players[pid]["connected"]))
	return "" if zone_open_to(sim.data, sim.map, zone, sim.order.find(id), builders, connected) else "Cette zone appartient à un autre joueur"


## Le joueur n° index (dans l'ordre des joueurs) peut-il construire dans cette zone ouverte ?
## Oui s'il en est propriétaire, s'il « roams », si un propriétaire connecté « roams », ou si plus
## aucun propriétaire n'est connecté. Partagé par l'hôte et l'interface (même règle).
static func zone_open_to(data: GameData, map: MapDef, zone: int, index: int, builders: Array[int], connected: Array[bool]) -> bool:
	var n := builders.size()
	if index >= 0 and _roams(data, builders[index]):
		return true
	var owned := false
	for i in n:
		if map.zone_allows(zone, i, n) and connected[i]:
			if i == index or _roams(data, builders[i]):
				return true
			owned = true
	return not owned


static func _roams(data: GameData, builder: int) -> bool:
	return builder >= 0 and builder < data.builders.size() and data.builders[builder]["roams"]


## Case où ce joueur peut construire en ce moment (hors or) : utile aux joueurs automatiques.
static func can_build_for(sim: SimMatch, id: int, board: SimBoard, cell: int) -> bool:
	return MatchFlow.can_trade(sim) and board.can_build(cell) and zone_refusal(sim, id, cell) == ""


static func upgrade(sim: SimMatch, id: int, p: Dictionary, board: SimBoard, cell: int) -> String:
	if not MatchFlow.can_trade(sim):
		return LOCKED
	var t := own_tower(id, board, cell)
	if t == null:
		return "Aucune tourelle à toi sur cette case"
	var levels := sim.data.levels_for(t.type, p["kit"])
	if t.level + 1 >= levels.size():
		return "Niveau maximum atteint"
	var cut := zone_discount(board, cell) + MatchEconomy.team_discount(sim, id) + TileBonus.discount(sim.data, board.map, cell, t.type)
	var cost: int = p["kit"].cost(levels[t.level + 1]["cost"], cut)
	if p["gold"] < cost:
		return "Or insuffisant"
	p["gold"] -= cost
	t.level += 1
	t.invested += cost
	board.refresh_stats(t)
	return ""


static func sell(sim: SimMatch, id: int, p: Dictionary, board: SimBoard, cell: int) -> String:
	if not MatchFlow.can_trade(sim):
		return LOCKED
	var t := own_tower(id, board, cell)
	if t == null:
		return "Aucune tourelle à toi sur cette case"
	var ratio: float = 1.0 if MatchPowers.active(board, "remount", id) else p["kit"].sell_ratio()  # Remontage
	p["gold"] += int(t.invested * ratio)
	board.remove_tower(cell)
	BoardLayout.on_sell(p["kit"])
	return ""


## Ferrailleur : déplacer une de ses tourelles sur une case libre, gratuitement (moves par vague).
static func move(sim: SimMatch, id: int, p: Dictionary, board: SimBoard, cell: int, to: int) -> String:
	if not MatchFlow.can_trade(sim):
		return LOCKED
	var t := own_tower(id, board, cell)
	if t == null:
		return "Aucune tourelle à toi sur cette case"
	if int(p.get("moves_used", 0)) >= int(p["kit"].m("moves")) and not MatchPowers.active(board, "remount", id):
		return "Plus de déplacement possible avant la prochaine vague"
	if not board.can_build(to):
		return "Impossible de construire ici"
	var zone := zone_refusal(sim, id, to)
	if zone != "":
		return zone
	p["moves_used"] = int(p.get("moves_used", 0)) + 1
	BoardLayout.move(board, t, to)
	return ""


## Terrassier : raser un arbre ou un rocher (une charge, dans une zone où le joueur construit).
static func raze(sim: SimMatch, id: int, p: Dictionary, board: SimBoard, cell: int) -> String:
	if not MatchFlow.can_trade(sim):
		return LOCKED
	if charges_left(p, "raze") <= 0:
		return "Plus de terrain à raser (talents du Terrassier)"
	var refusal := BoardTerrain.raze_refusal(board, cell)
	if refusal == "":
		refusal = zone_refusal(sim, id, cell)
	if refusal != "":
		return refusal
	BoardTerrain.raze(board, cell)
	p["used_raze"] = int(p.get("used_raze", 0)) + 1
	return ""


## Terrassier : poser une case spéciale (une charge).
static func place_tile(sim: SimMatch, id: int, p: Dictionary, board: SimBoard, cell: int, special: int) -> String:
	if not MatchFlow.can_trade(sim):
		return LOCKED
	var kind := BoardTerrain.charge_kind(sim.data, special)
	if charges_left(p, kind) <= 0:
		return "Plus de case à poser (talents du Terrassier)"
	var refusal := BoardTerrain.place_refusal(board, cell, special)
	if refusal == "":
		refusal = zone_refusal(sim, id, cell)
	if refusal != "":
		return refusal
	BoardTerrain.place(board, cell, special)
	p["used_" + kind] = int(p.get("used_" + kind, 0)) + 1
	return ""


## Charges restantes d'un joueur : « raze » (décor à raser), « tile » (Colline, Cristal, Rune),
## « vein » (Filon), « mound » (Butte), « ditch » (Fossé).
static func charges_left(p: Dictionary, kind: String) -> int:
	var kit: PlayerKit = p["kit"]
	var total: int = {"raze": kit.raze_charges, "tile": kit.tile_charges}.get(kind, int(kit.m(kind + "_tiles")))
	return maxi(0, total - int(p.get("used_" + kind, 0)))


## Charges restantes des cases à charges propres (BoardTerrain.OWN_CHARGES), dans l'ordre.
static func own_charges(p: Dictionary) -> Array:
	return BoardTerrain.OWN_CHARGES.values().map(func(kind: String) -> int: return charges_left(p, kind))


## Fin de l'état d'un joueur dans l'instantané : charges du Terrassier, puis vagues avant le
## retour de son pouvoir (-1 : aucun).
static func snapshot_tail(sim: SimMatch, p: Dictionary) -> Array:
	return own_charges(p) + [MatchPowers.waves_left(sim, p)]


static func cycle_target(id: int, board: SimBoard, cell: int) -> String:
	var t := own_tower(id, board, cell)
	if t == null:
		return "Aucune tourelle à toi sur cette case"
	t.target_mode = (t.target_mode + 1) % SimTower.TARGET_NAMES.size()
	return ""


static func send(sim: SimMatch, id: int, p: Dictionary, type: String) -> String:
	if sim.mode != SimMatch.Mode.VERSUS:
		return "L'envoi de monstres est réservé au mode versus"
	var def: Dictionary = sim.data.monsters[type]
	var cost := int(def["send_cost"])
	if cost <= 0:
		return "Ce monstre ne peut pas être envoyé"
	var target := sim.next_opponent_board(id)
	if target < 0:
		return "Aucun adversaire en jeu"
	if p["gold"] < cost:
		return "Or insuffisant"
	if not sim.boards[target].queue_monster(type, sim.monster_hp_mult()):
		return "Trop de monstres en attente chez l'adversaire"
	p["gold"] -= cost
	p["income"] += int(def["income"])
	return ""


## Don d'or à un allié (coopération). Le don coûte cher : l'allié ne reçoit qu'une part du montant
## (gift_ratio, plus le bonus de dons du donneur).
static func give(sim: SimMatch, id: int, p: Dictionary, to_index: int, amount: int) -> String:
	if sim.mode != SimMatch.Mode.COOP:
		return "Le don d'or est réservé à la coopération"
	if to_index < 0 or to_index >= sim.order.size():
		return "Joueur inconnu"
	var to: int = sim.order[to_index]
	var target: Dictionary = sim.players[to]
	if to == id:
		return "Impossible de se donner de l'or"
	if not target["connected"]:
		return "Ce joueur a quitté la partie"
	var minimum := int(sim.data.player["gift_min"])
	if amount < minimum:
		return "Don minimum : %d or" % minimum
	if p["gold"] < amount:
		return "Or insuffisant"
	var received := gift_received(sim.data, amount, p["kit"])
	p["gold"] -= amount
	target["gold"] += received
	MatchEconomy.invest(sim, p, amount)
	sim.notices.append([to, "%s t'a donné %d or" % [p["name"], received]])
	return ""


## Or réellement reçu pour un don de `amount` (kit du donneur : bonus de dons).
static func gift_received(data: GameData, amount: int, kit: PlayerKit = null) -> int:
	var ratio := kit.gift_ratio(data) if kit != null else float(data.player["gift_ratio"])
	return maxi(1, floori(amount * ratio))


## Réduction du Chantier le plus fort qui atteint cette case (alliés compris).
static func zone_discount(board: SimBoard, cell: int) -> float:
	return float(BoardAuras.best_at(board, board.map.cell_center(cell), "aura_discount")[0])


static func own_tower(id: int, board: SimBoard, cell: int) -> SimTower:
	var t: SimTower = board.towers.get(cell)
	if t == null or t.owner != id:
		return null
	return t

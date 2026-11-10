class_name MatchActions
extends RefCounted
## Actions des joueurs sur une partie (construire, améliorer, vendre, viser, envoyer, donner).
## Chaque action vérifie les règles et renvoie "" si elle est acceptée, sinon la raison du refus.

const LOCKED := "Construction possible seulement entre les vagues"


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
	var cost: int = p["kit"].cost(sim.data.tower_levels(type)[0]["cost"])
	if p["gold"] < cost:
		return "Or insuffisant"
	p["gold"] -= cost
	board.add_tower(cell, type, id, cost, p["kit"])
	return ""


## Zones de joueurs (coopération) : "" si le joueur peut construire sur cette case.
## Une zone dont tous les propriétaires ont quitté la partie devient commune.
static func zone_refusal(sim: SimMatch, id: int, cell: int) -> String:
	var zone := sim.map.zone_at(cell)
	if sim.mode != SimMatch.Mode.COOP or zone < 0:
		return ""
	var n := sim.order.size()
	var owned := false
	for i in n:
		if sim.map.zone_allows(zone, i, n) and sim.players[sim.order[i]]["connected"]:
			if sim.order[i] == id:
				return ""
			owned = true
	return "Cette zone appartient à un autre joueur" if owned else ""


## Case où ce joueur peut construire en ce moment (hors or) : utile aux joueurs automatiques.
static func can_build_for(sim: SimMatch, id: int, board: SimBoard, cell: int) -> bool:
	return MatchFlow.can_trade(sim) and board.can_build(cell) and zone_refusal(sim, id, cell) == ""


static func upgrade(sim: SimMatch, id: int, p: Dictionary, board: SimBoard, cell: int) -> String:
	if not MatchFlow.can_trade(sim):
		return LOCKED
	var t := own_tower(id, board, cell)
	if t == null:
		return "Aucune tourelle à toi sur cette case"
	var levels := sim.data.tower_levels(t.type)
	if t.level + 1 >= levels.size():
		return "Niveau maximum atteint"
	var cost: int = p["kit"].cost(levels[t.level + 1]["cost"])
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
	p["gold"] += int(t.invested * p["kit"].sell_ratio())
	board.remove_tower(cell)
	return ""


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
	sim.notices.append([to, "%s t'a donné %d or" % [p["name"], received]])
	return ""


## Or réellement reçu pour un don de `amount` (kit du donneur : bonus de dons).
static func gift_received(data: GameData, amount: int, kit: PlayerKit = null) -> int:
	var ratio := kit.gift_ratio(data) if kit != null else float(data.player["gift_ratio"])
	return maxi(1, floori(amount * ratio))


static func own_tower(id: int, board: SimBoard, cell: int) -> SimTower:
	var t: SimTower = board.towers.get(cell)
	if t == null or t.owner != id:
		return null
	return t

class_name MatchActions
extends RefCounted
## Actions des joueurs sur une partie (construire, améliorer, vendre, viser, envoyer).
## Chaque action vérifie les règles et renvoie "" si elle est acceptée, sinon la raison du refus.


static func build(sim: SimMatch, id: int, p: Dictionary, board: SimBoard, cell: int, type: String) -> String:
	if not board.can_build(cell):
		return "Impossible de construire ici"
	var cost: int = sim.data.tower_levels(type)[0]["cost"]
	if p["gold"] < cost:
		return "Or insuffisant"
	p["gold"] -= cost
	board.add_tower(cell, type, id, cost)
	return ""


static func upgrade(sim: SimMatch, id: int, p: Dictionary, board: SimBoard, cell: int) -> String:
	var t := own_tower(id, board, cell)
	if t == null:
		return "Aucune tourelle à toi sur cette case"
	var levels := sim.data.tower_levels(t.type)
	if t.level + 1 >= levels.size():
		return "Niveau maximum atteint"
	var cost: int = levels[t.level + 1]["cost"]
	if p["gold"] < cost:
		return "Or insuffisant"
	p["gold"] -= cost
	t.level += 1
	t.invested += cost
	board.refresh_stats(t)
	return ""


static func sell(id: int, p: Dictionary, board: SimBoard, cell: int) -> String:
	var t := own_tower(id, board, cell)
	if t == null:
		return "Aucune tourelle à toi sur cette case"
	p["gold"] += int(t.invested * SimMatch.SELL_RATIO)
	board.towers.erase(cell)
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


static func own_tower(id: int, board: SimBoard, cell: int) -> SimTower:
	var t: SimTower = board.towers.get(cell)
	if t == null or t.owner != id:
		return null
	return t

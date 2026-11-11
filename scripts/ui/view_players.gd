class_name ViewPlayers
extends RefCounted
## Joueurs reçus avec l'instantané d'une partie : or, revenu, prêt, vivant, plateau, et charges
## restantes du Terrassier (raser, Géomancie, Filon, Butte, Fossé). Rejet au moindre défaut.


static func parse(raw: Variant, board_count: int) -> Variant:
	if not ViewState._is_list(raw, 8):
		return null
	var out := {}
	for e in raw:
		if not ViewState._is_tuple(e, 8 + BoardTerrain.OWN_CHARGES.size()):
			return null
		var id = Check.as_int(e[0], 1, NetPayloads.MAX_PEER_ID)
		var razes = Check.as_int(e[6], 0, 1000)  # charges du Terrassier restantes
		var tiles = Check.as_int(e[7], 0, 1000)
		var own := {}  # Filon, Butte, Fossé
		for k in BoardTerrain.OWN_CHARGES.size():
			var n = Check.as_int(e[8 + k], 0, 1000)
			if n == null:
				return null
			own[BoardTerrain.OWN_CHARGES.values()[k]] = n
		var gold = Check.as_int(e[1], 0, 1000000000)
		var income = Check.as_int(e[2], 0, 1000000000)
		var ready = Check.as_bool(e[3])
		var alive = Check.as_bool(e[4])
		var board = Check.as_int(e[5], 0, board_count - 1)
		if id == null or gold == null or income == null or ready == null or alive == null or board == null or razes == null or tiles == null:
			return null
		out[id] = {"gold": gold, "income": income, "ready": ready, "alive": alive, "board": board, "raze": razes, "tile": tiles}
		out[id].merge(own)
	return out

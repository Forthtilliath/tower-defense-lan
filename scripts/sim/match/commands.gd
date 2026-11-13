class_name Commands
extends RefCounted
## Vérifie le format des commandes envoyées par les joueurs (types, bornes, clés).
## Les règles du jeu (or, propriétaire de la tourelle…) sont ensuite vérifiées par SimMatch.
## Une commande mal formée est rejetée en entier.

const INVALID := "Commande invalide"
const MAX_PLAYER_INDEX := 7
const MAX_GIFT := 1000000


## Renvoie la commande normalisée (Dictionary) ou un message d'erreur (String).
static func sanitize(raw: Variant, data: GameData, map: MapDef) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return INVALID
	var d: Dictionary = raw
	if d.size() > 3 or typeof(d.get("a")) != TYPE_STRING:
		return INVALID
	var action: String = d["a"]
	var last_cell := map.cell_count() - 1
	match action:
		"build":
			var cell = Check.as_int(d.get("cell"), 0, last_cell)
			var tower = Check.as_int(d.get("tower"), 0, data.tower_order.size() - 1)
			if cell == null or tower == null or d.size() != 3:
				return INVALID
			return {"a": action, "cell": cell, "tower": data.tower_order[tower]}
		"tile":
			var cell = Check.as_int(d.get("cell"), 0, last_cell)
			var special = Check.as_int(d.get("special"), 0, data.specials.size() - 1)
			if cell == null or special == null or d.size() != 3:
				return INVALID
			return {"a": action, "cell": cell, "special": special}
		"upgrade", "sell", "mode", "raze", "power":
			var cell = Check.as_int(d.get("cell"), 0, last_cell)
			if cell == null or d.size() != 2:
				return INVALID
			return {"a": action, "cell": cell}
		"move":
			var cell = Check.as_int(d.get("cell"), 0, last_cell)
			var to = Check.as_int(d.get("to"), 0, last_cell)
			if cell == null or to == null or cell == to or d.size() != 3:
				return INVALID
			return {"a": action, "cell": cell, "to": to}
		"send":
			var monster = Check.as_int(d.get("monster"), 0, data.monster_order.size() - 1)
			if monster == null or d.size() != 2:
				return INVALID
			return {"a": action, "monster": data.monster_order[monster]}
		"give":
			var to = Check.as_int(d.get("to"), 0, MAX_PLAYER_INDEX)
			var amount = Check.as_int(d.get("amount"), 1, MAX_GIFT)
			if to == null or amount == null or d.size() != 3:
				return INVALID
			return {"a": action, "to": to, "amount": amount}
		"pause":
			var on = Check.as_bool(d.get("on"))
			if on == null or d.size() != 2:
				return INVALID
			return {"a": action, "on": on}
		"ready", "speed":
			if d.size() != 1:
				return INVALID
			return {"a": action}
	return INVALID

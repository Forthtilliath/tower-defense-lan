class_name Commands
extends RefCounted
## Vérifie le format des commandes envoyées par les joueurs (types, bornes, clés).
## Les règles du jeu (or, propriétaire de la tourelle…) sont ensuite vérifiées par SimMatch.
## Une commande mal formée est rejetée en entier.

const INVALID := "Commande invalide"


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
		"upgrade", "sell", "mode":
			var cell = Check.as_int(d.get("cell"), 0, last_cell)
			if cell == null or d.size() != 2:
				return INVALID
			return {"a": action, "cell": cell}
		"send":
			var monster = Check.as_int(d.get("monster"), 0, data.monster_order.size() - 1)
			if monster == null or d.size() != 2:
				return INVALID
			return {"a": action, "monster": data.monster_order[monster]}
		"ready", "speed":
			if d.size() != 1:
				return INVALID
			return {"a": action}
	return INVALID

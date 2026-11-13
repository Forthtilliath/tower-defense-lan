class_name BestiaryData
extends RefCounted
## Où l'on croise chaque monstre : cartes dont les vagues l'envoient, et monstres qui le font
## naître (petits d'araignée, gelées divisées, morts relevés…).

const CHILD_KEYS := ["split_into", "brood_into", "raise_into"]


## id du monstre -> ids des cartes où il apparaît (directement ou né d'un autre), dans l'ordre des cartes.
static func maps_by_monster(data: GameData) -> Dictionary:
	var out := {}
	for id in data.monster_order:
		out[id] = []
	for m in data.maps:
		for wave_id in m.waves:
			for g in data.waves[wave_id]["groups"]:
				_add_with_children(data, out, g["monster"], m.id, 0)
	return out


static func _add_with_children(data: GameData, out: Dictionary, id: String, map_id: String, depth: int) -> void:
	if depth > 4 or not out.has(id):
		return
	if not out[id].has(map_id):
		out[id].append(map_id)
	var def: Dictionary = data.monsters[id]
	for key in CHILD_KEYS:
		var child: String = str(def.get(key, ""))
		if child != "" and child != id:
			_add_with_children(data, out, child, map_id, depth + 1)


## id du monstre -> noms des monstres qui le font naître (vide pour les monstres des vagues).
static func parents(data: GameData) -> Dictionary:
	var out := {}
	for id in data.monster_order:
		var def: Dictionary = data.monsters[id]
		for key in CHILD_KEYS:
			var child: String = str(def.get(key, ""))
			if child == "" or not data.monsters.has(child):
				continue
			if not out.has(child):
				out[child] = []
			if not out[child].has(def["name"]):
				out[child].append(def["name"])
	return out


## Noms des cartes, dans l'ordre : « Prairie, Carrefour ».
static func map_names(data: GameData, ids: Array) -> String:
	var names := []
	for m in data.maps:
		if ids.has(m.id):
			names.append(m.name)
	return ", ".join(names)

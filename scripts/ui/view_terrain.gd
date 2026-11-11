class_name ViewTerrain
extends RefCounted
## Cases changées par un Terrassier, reçues avec l'instantané d'un plateau. Chaque changement est
## vérifié (un arbre ou un rocher rasé devient constructible ; une case spéciale posable va sur
## une case constructible qui n'en avait pas), puis appliqué à une copie de la carte d'origine.


## Carte du plateau avec ses changements, ou null au moindre changement invalide.
static func parse(raw: Variant, base: MapDef, data: GameData) -> Variant:
	if typeof(raw) != TYPE_ARRAY or raw.size() > base.cell_count():
		return null
	var m := base.clone()
	var allowed := BoardTerrain.placeable(data)
	for i in data.specials.size():  # Filon, Butte, Fossé : posés avec leurs propres charges
		if BoardTerrain.charge_kind(data, i) != "tile":
			allowed.append(i)
	for e in raw:
		if typeof(e) != TYPE_ARRAY or e.size() != 3:
			return null
		var cell = Check.as_int(e[0], 0, base.cell_count() - 1)
		var kind = Check.as_int(e[1], MapDef.Cell.BUILD, MapDef.Cell.BUILD)
		var special = Check.as_int(e[2], -1, data.specials.size() - 1)
		if cell == null or kind == null or special == null:
			return null
		var decor := base.is_decor(cell)
		if not decor and not base.is_buildable(cell):
			return null  # la route, l'eau, le départ et l'arrivée ne changent jamais
		if special >= 0 and (not allowed.has(special) or base.special_at(cell) >= 0):
			return null
		if special < 0 and not decor:
			return null
		m.set_cell(cell, kind, special)
	return m

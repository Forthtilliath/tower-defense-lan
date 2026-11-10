class_name BoardTerrain
extends RefCounted
## Terrassier : raser un arbre ou un rocher (la case devient constructible) et poser une case
## spéciale (Colline, Cristal, Rune ; jamais un Filon d'or) sur une case constructible qui n'en a
## pas, même sous une tourelle. La route et l'eau ne changent jamais. Chaque changement est noté
## dans SimBoard.edits et transmis aux joueurs avec l'instantané du plateau.


## Cases spéciales que l'on peut poser (index dans GameData.specials).
static func placeable(data: GameData) -> Array[int]:
	var out: Array[int] = []
	for i in data.specials.size():
		if int(data.specials[i]["gold_per_wave"]) == 0:
			out.append(i)
	return out


static func raze_refusal(b: SimBoard, cell: int) -> String:
	if not b.alive or not b.map.is_decor(cell):
		return "Seuls les arbres et les rochers se rasent"
	return ""


static func place_refusal(b: SimBoard, cell: int, special: int) -> String:
	if not b.alive or not b.map.is_buildable(cell):
		return "Case spéciale possible seulement sur une case constructible"
	if b.map.special_at(cell) >= 0:
		return "Cette case a déjà un bonus"
	if not placeable(b.data).has(special):
		return "Cette case spéciale ne se pose pas"
	return ""


static func raze(b: SimBoard, cell: int) -> void:
	b.map.set_cell(cell, MapDef.Cell.BUILD, -1)
	b.edits[cell] = [MapDef.Cell.BUILD, -1]


## Pose la case spéciale ; une tourelle déjà dessus en profite tout de suite.
static func place(b: SimBoard, cell: int, special: int) -> void:
	b.map.set_cell(cell, MapDef.Cell.BUILD, special)
	b.edits[cell] = [MapDef.Cell.BUILD, special]
	var t: SimTower = b.towers.get(cell)
	if t != null:
		t.special = special
		b.refresh_stats(t)


## Instantané : [[index de case, type de case, case spéciale], ...]
static func snapshot(b: SimBoard) -> Array:
	var out := []
	for cell in b.edits:
		out.append([cell, b.edits[cell][0], b.edits[cell][1]])
	return out

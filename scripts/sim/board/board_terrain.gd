class_name BoardTerrain
extends RefCounted
## Terrassier : raser un arbre ou un rocher (la case devient constructible) et poser une case
## spéciale (Colline, Cristal, Rune ; Filon, Butte et Fossé avec leurs propres charges) sur une
## case constructible qui n'en a pas, même sous une tourelle. La route et l'eau ne changent jamais. Chaque changement est noté
## dans SimBoard.edits et transmis aux joueurs avec l'instantané du plateau.


## Fossé : rayon autour de la case où les monstres au sol sont ralentis (durée du ralentissement).
const DITCH_REACH := 1.0
const DITCH_SLOW_TIME := 0.5
## Charges propres à une case : « vein » (Filon), « mound » (Butte), « ditch » (Fossé) ; les
## autres cases spéciales (Colline, Cristal, Rune) prennent les charges « tile » (Géomancie).
const OWN_CHARGES := {"gold": "vein", "mound": "mound", "ditch": "ditch"}


## Cases spéciales que l'on peut poser avec la Géomancie (index dans GameData.specials).
static func placeable(data: GameData) -> Array[int]:
	var out: Array[int] = []
	for i in data.specials.size():
		if int(data.specials[i]["gold_per_wave"]) == 0 and not data.specials[i]["rare"]:
			out.append(i)
	return out


## Charges que coûte la pose de cette case spéciale (voir OWN_CHARGES).
static func charge_kind(data: GameData, special: int) -> String:
	return OWN_CHARGES.get(data.specials[special]["id"], "tile")


## Fossés : chaque monstre au sol près d'un fossé est ralenti.
static func ditches(b: SimBoard) -> void:
	for cell in b.edits:
		var s: int = b.edits[cell][1]
		if s < 0 or float(b.data.specials[s]["slow"]) <= 0.0:
			continue
		var at := b.map.cell_center(cell)
		for m in b.monsters:
			if not m.flying and m.pos.distance_to(at) <= DITCH_REACH:
				m.apply_slow(1.0 - float(b.data.specials[s]["slow"]), DITCH_SLOW_TIME)


static func raze_refusal(b: SimBoard, cell: int) -> String:
	if not b.alive or not b.map.is_decor(cell):
		return "Seuls les arbres et les rochers se rasent"
	return ""


static func place_refusal(b: SimBoard, cell: int, special: int) -> String:
	if not b.alive or not b.map.is_buildable(cell):
		return "Case spéciale possible seulement sur une case constructible"
	if b.map.special_at(cell) >= 0:
		return "Cette case a déjà un bonus"
	if not placeable(b.data).has(special) and charge_kind(b.data, special) == "tile":
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

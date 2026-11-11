class_name BoardTiles
extends RefCounted
## Cases spéciales qui s'épuisent (Filon instable) : à chaque vague lancée, chaque tourelle posée
## sur une telle case l'use d'une vague ; au bout de « wears » vagues, la case redevient normale
## (changement noté dans SimBoard.edits, comme ceux du Terrassier, et donc diffusé aux joueurs).


## Usure de chaque case (index de case -> vagues déjà passées avec une tourelle dessus).
static func worn(b: SimBoard) -> Dictionary:
	if not b.has_meta("tile_wear"):
		b.set_meta("tile_wear", {})
	return b.get_meta("tile_wear")


## Vagues qu'il reste avant épuisement de la case (-1 : elle ne s'épuise pas).
static func waves_left(b: SimBoard, cell: int) -> int:
	var special := b.map.special_at(cell)
	if special < 0 or int(b.data.specials[special]["wears"]) <= 0:
		return -1
	return int(b.data.specials[special]["wears"]) - int(worn(b).get(cell, 0))


## Départ d'une vague : use les cases occupées, épuise celles qui arrivent au bout.
static func on_wave(b: SimBoard) -> void:
	if not b.alive:
		return
	var wear := worn(b)
	for cell in b.towers.keys():
		if waves_left(b, cell) < 0:
			continue
		wear[cell] = int(wear.get(cell, 0)) + 1
		if waves_left(b, cell) <= 0:
			wear.erase(cell)
			b.map.set_cell(cell, MapDef.Cell.BUILD, -1)
			b.edits[cell] = [MapDef.Cell.BUILD, -1]
			var t: SimTower = b.towers[cell]
			t.special = -1
			b.refresh_stats(t)

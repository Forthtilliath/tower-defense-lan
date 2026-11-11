class_name BoardSnapshot
extends RefCounted
## Instantané d'un plateau diffusé aux joueurs : vies, monstres, tourelles, projectiles, effets,
## nappes au sol et cases changées par un Terrassier.


static func of(b: SimBoard) -> Dictionary:
	var mons := []
	for m in b.monsters:
		var hp := int(roundf(clampf(m.hp / m.max_hp, 0.0, 1.0) * 255.0))
		mons.append([m.id, m.type_index, m.path, snappedf(m.progress, 0.01), hp, _flags(m)])
	var tws := []
	for cell in b.towers:
		var t: SimTower = b.towers[cell]
		tws.append([t.cell, b.data.tower_order.find(t.type), t.level, t.owner, t.target_mode, t.buff_flags(), t.invested])
	var prs := []
	for p in b.projectiles:
		prs.append([p.id, snappedf(p.pos.x, 0.01), snappedf(p.pos.y, 0.01), p.kind])
	var fx := []
	for f in b._fx:
		var pos: Vector2 = f["pos"]
		var to: Vector2 = f["to"]
		var circle := SimBoard.is_round_fx(f["kind"])
		var a: float = f["radius"] if circle else to.x
		var c: float = float(f["tint"]) if circle else to.y
		fx.append([f["kind"], snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(a, 0.01), snappedf(c, 0.01), snappedf(f["ttl"] / SimBoard.FX_DURATION, 0.01)])
	return {"lives": b.lives, "alive": b.alive, "m": mons, "t": tws, "p": prs, "fx": fx, "z": BoardPatches.snapshot(b),
		"e": BoardTerrain.snapshot(b)}


## États visibles d'un monstre, un bit chacun (voir ViewState).
static func _flags(m: SimMonster) -> int:
	return (1 if m.is_slowed() else 0) | (2 if m.is_poisoned() else 0) | (4 if m.is_elite() else 0) \
			| (8 if m.is_burning() else 0) | (16 if m.is_bleeding() else 0) | (32 if m.is_stunned() else 0) \
			| (64 if m.is_feared() else 0) | (128 if m.is_charmed() else 0) | (256 if m.warded > 0.0 else 0) \
			| (512 if m.marks.is_frostbitten() else 0) | (1024 if m.marks.is_shocked() else 0) \
			| (2048 if m.marks.is_grounded() else 0) | (4096 if m.marks.burrowed else 0)

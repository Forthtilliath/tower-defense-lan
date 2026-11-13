extends RefCounted
## Traces du joueur automatique (bilans en mode verbeux) : ce que son modèle croit pouvoir tuer
## de chaque groupe de la vague en cours et de la suivante.

const Foes := preload("res://tests/bot/bot_foes.gd")


## Une ligne par vague : « type×nombre/couloir r=… » (r : fois où la défense tuerait un monstre
## du groupe sur son trajet ; « + » : groupe de la vague suivante).
static func ratios(player, towers: Array) -> void:
	var sim: SimMatch = player.sim
	var descs := []
	for t in towers:
		descs.append(player.defense.describe(t))
	var r: PackedFloat32Array = player.defense.ratios(descs)
	var parts := []
	for e in player.foes.size():
		var f: Dictionary = player.foes[e]
		var share: float = f["weight"] / maxf(0.001, float(f["count"]) * (float(f["damage"]) + Foes.spawns(sim, f)))
		if share >= Foes.LOOK[1] - 0.01:
			parts.append("%s%s×%d/c%d r=%.2f" % ["" if is_equal_approx(share, Foes.LOOK[0]) else "+", f["type"], int(f["count"]), f["path"], r[e]])
	print("    vague %d, vies %d, or %d : %s" % [maxi(0, sim.wave_index) + 1, sim.boards[0].lives, sim.players[player.id]["gold"], ", ".join(parts)])

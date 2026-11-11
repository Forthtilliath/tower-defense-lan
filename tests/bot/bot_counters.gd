extends RefCounted
## Lecture de la vague suivante par le joueur automatique (balance_bot.gd) : part de sa puissance de
## feu qui la toucherait vraiment, et tourelle à construire contre elle si ses tirs ne portent pas.

## En dessous de cette part de sa puissance de feu efficace contre la vague suivante, il s'adapte.
const ADAPT_BELOW := 0.5
## Au-delà de ce nombre de tourelles efficaces contre la vague suivante, il améliore au lieu d'en ajouter.
const MAX_ANSWERS := 3

var _foes := {}  # cache : vague -> [[monstre type, poids], ...]


## Tourelle à construire contre la vague suivante si la plupart de sa puissance de feu ne la
## toucherait pas ("" sinon) : la plus efficace contre elle, ses tourelles renforcées comptant plus.
func counter_pick(sim: SimMatch, id: int, mine: Array[SimTower]) -> String:
	var next := sim.wave_index + 1
	if next >= sim.map.waves.size():
		return ""
	var foes := _wave_foes(sim, sim.map.waves[next])
	var data := sim.data
	var total := 0.0
	var useful := 0.0
	var answers := 0  # tourelles déjà efficaces contre cette vague
	for t in mine:
		if not t.support:
			var power := dps_of(t.stats)
			var e := effect(data, t.type, foes)
			total += power
			useful += power * e
			answers += 1 if e >= 0.5 else 0
	if total <= 0.0 or useful >= total * ADAPT_BELOW or answers >= MAX_ANSWERS:
		return ""  # ses tirs portent, ou il a déjà de quoi répondre : il améliore plutôt
	var kit: PlayerKit = sim.players[id]["kit"]
	var best := ""
	var best_score := 0.0
	for type in data.tower_order:
		if not kit.allows(type) or data.towers[type]["support"] or float(data.tower_levels(type)[0]["damage"]) <= 0.0:
			continue
		var e := effect(data, type, foes)
		var score := early_value(data, type) * kit.mult(type, "damage") * e
		if e >= 0.5 and score > best_score:
			best_score = score
			best = type
	return best


## Monstres d'une vague tels qu'ils apparaîtront (vague spéciale et armure de la difficulté
## comprises), avec leur poids (nombre × PV).
func _wave_foes(sim: SimMatch, wave_id: String) -> Array:
	if not _foes.has(wave_id):
		var wave: Dictionary = sim.data.waves[wave_id]
		var mod: Dictionary = sim.data.modifiers.get(wave.get("modifier", ""), {})
		var out := []
		for g in wave["groups"]:
			var m := SimMonster.new()
			m.setup(sim.data.monsters[g["monster"]], 1.0, 1.0, mod)
			m.armor += sim.boards[0].armor_bonus
			out.append([m, float(g["count"]) * m.max_hp])
		_foes[wave_id] = out
	return _foes[wave_id]


## Part de la puissance d'une tourelle qui touche vraiment ces monstres (0 à 1) : cible (sol ou
## air), résistance à son élément, armure contre ses coups directs (les effets continus l'ignorent).
static func effect(data: GameData, type: String, foes: Array) -> float:
	var def: Dictionary = data.towers[type]
	var l: Dictionary = data.tower_levels(type)[0]
	var dot := float(l["poison_dps"]) + float(l["burn_dps"]) + float(l["bleed"]) * 100.0 > float(l["damage"])
	var total := 0.0
	var hit := 0.0
	for f in foes:
		var m: SimMonster = f[0]
		total += f[1]
		if not (def["air"] if m.flying else def["ground"]):
			continue
		var part := m.taken(def["element"])
		var d := float(l["damage"])
		if not dot and d > 0.0 and m.armor > 0.0:
			part *= maxf(d - m.armor, d * BoardCombat.ARMOR_MIN_RATIO) / d
		hit += f[1] * part
	return hit / total if total > 0.0 else 1.0


## Puissance d'une tourelle (dégâts par seconde, rebonds, poison, brûlure et nappes comptés grossièrement).
static func dps_of(l: Dictionary) -> float:
	var dps: float = l["damage"] * l["rate"] * (1.0 + 0.5 * l["chain"] + 0.5 * (l["multishot"] - 1))
	return dps + l["poison_dps"] + l["burn_dps"] * l["burn_stacks"] * 0.5 + l["patch_dps"]


## Dégâts par seconde au niveau 1 pour l'or dépensé : l'ordre dans lequel un joueur choisirait.
static func early_value(data: GameData, type: String) -> float:
	var l: Dictionary = data.tower_levels(type)[0]
	return dps_of(l) / float(l["cost"])

class_name MatchEconomy
extends RefCounted
## Or d'une partie : primes (bonus de classe et d'équipe), or versé au départ de chaque vague
## (intérêts, or de la vague, bonus de vague lancée en avance, or des vagues sans fuite,
## filons d'or), et crédit des joueurs encore connectés.


## Or versé à chacun quand une vague part : intérêts sur l'or gardé, or de la vague, bonus
## d'avance (`early` : multiplié par le talent du Parieur), or des vagues franchies sans perdre
## de vie (Parieur), filons d'or. `clean` : plateaux qui n'ont perdu aucune vie depuis la vague
## précédente (index -> true).
static func pay_wave(sim: SimMatch, wave: Dictionary, early: int, clean: Dictionary) -> void:
	_pay_gold_tiles(sim)
	for id in sim.order:
		var p: Dictionary = sim.players[id]
		p["ready"] = false
		if not p["alive"] or not p["connected"]:
			continue
		var kit: PlayerKit = p["kit"]
		p["gold"] += MatchFlow.interest(sim.data, p["gold"], kit)
		p["gold"] += roundi(int(wave["gold"]) * float(p["gold_mult"])) + roundi(early * (1.0 + kit.early_bonus))
		if clean.has(int(p["board"])):
			p["gold"] += kit.clean_gold
		if sim.mode == SimMatch.Mode.VERSUS:
			p["gold"] += SimMatch.VERSUS_BASE_INCOME + int(p["income"])


## Part de prime d'un monstre tué : bonus de classe du joueur, plus les bonus d'équipe (Mécène)
## de tous les joueurs de la partie encore connectés (le sien compris).
static func credit_bounty(sim: SimMatch, owner: int, gold: int) -> void:
	var p: Dictionary = sim.players.get(owner, {})
	if p.is_empty():
		return
	var mult := float(p["kit"].bounty)
	for id in sim.order:
		if sim.players[id]["connected"]:
			mult += float(sim.players[id]["kit"].team_bounty)
	credit(sim, owner, roundi(gold * mult))


static func credit(sim: SimMatch, owner: int, gold: int) -> void:
	var p: Dictionary = sim.players.get(owner, {})
	if not p.is_empty() and p["connected"]:
		p["gold"] += gold


## Filons d'or : chaque tourelle posée dessus rapporte de l'or à son propriétaire à chaque vague.
static func _pay_gold_tiles(sim: SimMatch) -> void:
	for b in sim.boards:
		if not b.alive:
			continue
		for cell in b.towers:
			var t: SimTower = b.towers[cell]
			if t.special >= 0:
				credit(sim, t.owner, int(sim.data.specials[t.special]["gold_per_wave"]))

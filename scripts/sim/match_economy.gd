class_name MatchEconomy
extends RefCounted
## Or d'une partie : primes (bonus de classe et d'équipe), or versé au départ de chaque vague
## (intérêts, or de la vague, bonus de vague lancée en avance, or des vagues sans fuite,
## filons d'or), crédit des joueurs encore connectés, et économie des talents (PlayerKit.MONEY :
## prêt, butin, jackpot, trophées, contrat, rente, intérêts composés, aides aux alliés, Parieur).

const LOOT_GOLD := 5
const JACKPOT := 10
const LOAN_RATE := 1.2
const LOAN_WAVE := 10
const INVEST_WAVES := 3
const RISK_CAP := 0.3
const NERVE_LIVES := 5


## Départ : prêt (remboursé à la vague LOAN_WAVE), or offert par les alliés (ally_start).
static func setup(sim: SimMatch) -> void:
	for id in sim.order:
		var p: Dictionary = sim.players[id]
		var kit: PlayerKit = p["kit"]
		p["start_lives"] = sim.boards[int(p["board"])].lives
		p["returns"] = []
		if kit.m("loan") > 0.0:
			p["gold"] += int(kit.m("loan"))
			p["loan_due"] = roundi(kit.m("loan") * LOAN_RATE)
		for other in sim.order:
			if other != id:
				p["gold"] += int(sim.players[other]["kit"].m("ally_start"))


## Or versé à chacun quand une vague part : intérêts sur l'or gardé, or de la vague, bonus
## d'avance (`early` : multiplié par le talent du Parieur), or des vagues franchies sans perdre
## de vie (Parieur), filons d'or, puis les talents d'économie. `clean` : plateaux qui n'ont perdu
## aucune vie depuis la vague précédente (index -> true).
static func pay_wave(sim: SimMatch, wave: Dictionary, early: int, clean: Dictionary) -> void:
	_pay_gold_tiles(sim)
	var shared := {}  # id -> intérêts partagés avec les alliés (Mécénat)
	for id in sim.order:
		var p: Dictionary = sim.players[id]
		p["ready"] = false
		if not p["alive"] or not p["connected"]:
			continue
		var kit: PlayerKit = p["kit"]
		var interest := MatchFlow.interest(sim.data, p["gold"] + roundi(kit.m("compound") * invested(sim, id)), kit)
		p["gold"] += interest
		shared[id] = roundi(interest * kit.m("share_interest"))
		var wave_gold := roundi(int(wave["gold"]) * float(p["gold_mult"]))
		p["gold"] += wave_gold + roundi(early * (1.0 + kit.early_bonus)) + int(kit.m("rent"))
		if early > 0:
			p["gold"] += roundi(wave_gold * kit.m("early_wave"))
		if clean.has(int(p["board"])):
			kit.clean_waves += 1
			kit.clean_streak += 1
			p["gold"] += kit.clean_gold + int(kit.m("hot_hand")) * kit.clean_streak
		else:
			kit.clean_streak = 0
		_settle(sim, p)
		if sim.mode == SimMatch.Mode.VERSUS:
			p["gold"] += SimMatch.VERSUS_BASE_INCOME + int(p["income"])
	for id in shared:
		for other in sim.order:
			if other != id and shared[id] > 0:
				credit(sim, other, shared[id])


## Remboursement du prêt (ce qu'il peut, le reste à la vague suivante) et retours des dons investis.
static func _settle(sim: SimMatch, p: Dictionary) -> void:
	if int(p.get("loan_due", 0)) > 0 and sim.wave_index >= LOAN_WAVE:
		var paid := mini(int(p["gold"]), int(p["loan_due"]))
		p["gold"] -= paid
		p["loan_due"] -= paid
	var left := []
	for r in p.get("returns", []):
		if sim.wave_index >= int(r[0]):
			p["gold"] += int(r[1])
		else:
			left.append(r)
	p["returns"] = left


## Don fait par `p` : une part lui reviendra INVEST_WAVES vagues plus tard (Investissement).
static func invest(sim: SimMatch, p: Dictionary, amount: int) -> void:
	var back := roundi(amount * p["kit"].m("invest"))
	if back > 0:
		p["returns"].append([sim.wave_index + INVEST_WAVES, back])


## Réduction des améliorations offerte par les alliés (Commande publique).
static func team_discount(sim: SimMatch, id: int) -> float:
	var total := 0.0
	for other in sim.order:
		if other != id and sim.players[other]["connected"]:
			total += sim.players[other]["kit"].m("team_discount")
	return total


## Or investi dans les tourelles d'un joueur (Intérêts composés).
static func invested(sim: SimMatch, id: int) -> int:
	var total := 0
	for b in sim.boards:
		for cell in b.towers:
			if b.towers[cell].owner == id:
				total += int(b.towers[cell].invested)
	return total


## Part de prime d'un monstre tué : bonus de classe du joueur, plus les bonus d'équipe (Mécène)
## de tous les joueurs de la partie encore connectés (le sien compris), et ses talents : gros
## monstre, trophées, prise de risque, nerfs d'acier, contrat, jackpot, butin.
static func credit_bounty(sim: SimMatch, owner: int, gold: int, big := false) -> void:
	var p: Dictionary = sim.players.get(owner, {})
	if p.is_empty():
		return
	var kit: PlayerKit = p["kit"]
	var mult := float(kit.bounty)
	for id in sim.order:
		if sim.players[id]["connected"]:
			mult += float(sim.players[id]["kit"].team_bounty)
	var lives := sim.boards[int(p["board"])].lives
	mult += kit.m("trophy") * kit.trophies
	mult += minf(RISK_CAP, kit.m("risk") * maxi(0, int(p.get("start_lives", lives)) - lives))
	if lives <= NERVE_LIVES:
		mult += kit.m("nerve")
	if big:
		mult += kit.m("boss_bounty")
		kit.trophies += 1
	if kit.m("contract") > 0.0 and kit.contract_wave != sim.wave_index:
		kit.contract_wave = sim.wave_index
		mult *= 1.0 + kit.m("contract")
	var rng := sim.boards[0].rng
	if kit.m("jackpot") > 0.0 and rng.randf() < kit.m("jackpot"):
		mult *= JACKPOT
	var bonus := LOOT_GOLD if kit.m("loot") > 0.0 and rng.randf() < kit.m("loot") else 0
	credit(sim, owner, roundi(gold * mult) + bonus)


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

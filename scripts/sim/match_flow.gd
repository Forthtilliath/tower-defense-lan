class_name MatchFlow
extends RefCounted
## Enchaînement des vagues : compte à rebours, phases de construction, appel de la vague suivante.
##
## Rythme libre : on construit à tout moment. Le compte à rebours démarre quand la vague a fini
## d'apparaître, et l'on peut appeler la vague suivante même pendant une vague (une seule d'avance).
## Rythme « entre les vagues » (coopération) : une phase de construction démarre quand la carte est
## vide. Construire, améliorer et vendre n'est possible que pendant cette phase, et aucune vague
## ne peut être appelée tant qu'une autre est en cours.
## Lancement : par vote (tous les joueurs prêts) ou par l'hôte seul.
## La première vague ne part jamais seule : elle attend d'être lancée (sans limite de temps).


static func update(sim: SimMatch, dt: float) -> void:
	if not sim.started():
		return
	if sim.countdown < 0.0:
		if _should_start_countdown(sim):
			sim.countdown = SimMatch.BUILD_PHASE if sim.rhythm == SimMatch.Rhythm.BETWEEN else SimMatch.BETWEEN_WAVES
		return
	sim.countdown -= dt
	if sim.countdown <= 0.0:
		sim.countdown = 0.0
		sim.launch_next_wave()


static func _should_start_countdown(sim: SimMatch) -> bool:
	if not sim.has_next_wave():
		return false
	for b in sim.boards:
		if not b.alive:
			continue
		if b.spawns_pending() or (sim.rhythm == SimMatch.Rhythm.BETWEEN and not b.is_clear()):
			return false
	return true


## Construire, améliorer et vendre sont-ils permis en ce moment ?
static func can_trade(sim: SimMatch) -> bool:
	return sim.rhythm == SimMatch.Rhythm.FREE or sim.countdown >= 0.0


## La vague suivante peut-elle être appelée maintenant ?
static func can_call(sim: SimMatch) -> bool:
	return call_refusal(sim) == ""


static func call_refusal(sim: SimMatch) -> String:
	if sim.ended or not sim.has_next_wave():
		return "Plus aucune vague à appeler"
	if sim.countdown >= 0.0:
		return ""
	if sim.rhythm == SimMatch.Rhythm.BETWEEN:
		return "Impossible pendant une vague"
	if sim.mode == SimMatch.Mode.VERSUS:
		return "Aucune vague en attente"
	if sim.boards[0].pending_waves() > 1:
		return "Une vague est déjà en attente"
	return ""


## Demande de lancer la vague suivante (bouton « Prêt » / « Vague suivante »).
static func call_wave(sim: SimMatch, id: int) -> String:
	var refusal := call_refusal(sim)
	if refusal != "":
		return refusal
	if sim.launch == SimMatch.Launch.HOST:
		if id != sim.leader():
			return "Seul l'hôte lance les vagues"
		sim.launch_next_wave()
		return ""
	sim.players[id]["ready"] = true
	if sim.all_ready():
		sim.launch_next_wave()
	return ""


## Or offert à chacun quand une vague part en avance : les secondes d'attente évitées.
## Appelée pendant une vague, elle évite tout le compte à rebours qui aurait suivi.
## La première vague, lancée quand les joueurs le décident, ne rapporte pas de bonus.
static func early_bonus(sim: SimMatch) -> int:
	if not sim.started():
		return 0
	if sim.countdown >= 0.0:
		return int(sim.countdown)
	return int(SimMatch.BETWEEN_WAVES)


## Intérêts versés à chaque vague sur l'or gardé (plafonnés).
static func interest(data: GameData, gold: int) -> int:
	return mini(int(data.player["interest_cap"]), floori(gold * float(data.player["interest"])))

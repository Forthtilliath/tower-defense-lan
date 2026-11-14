class_name MatchFlow
extends RefCounted
## Enchaînement des vagues : compte à rebours, phases de construction, appel de la vague suivante.
##
## Rythme libre (coopération) : on construit à tout moment. Le compte à rebours de la vague
## suivante (SimMatch.CALL_WINDOW) démarre dès qu'une vague est appelée ; on peut l'appeler à tout
## moment, contre 1 or par seconde restante. Elle arrive aussitôt, en plus de celle en cours
## (appeler plusieurs vagues d'affilée les fait arriver ensemble : c'est le risque à prendre).
## Versus : le compte à rebours (SimMatch.BETWEEN_WAVES) démarre quand la vague a fini d'apparaître.
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


## Le compte à rebours part-il de l'appel de la vague précédente (coopération, rythme libre) ?
static func timed_from_call(sim: SimMatch) -> bool:
	return sim.mode == SimMatch.Mode.COOP and sim.rhythm == SimMatch.Rhythm.FREE


static func _should_start_countdown(sim: SimMatch) -> bool:
	if timed_from_call(sim) or not sim.has_next_wave():
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
	if timed_from_call(sim) or sim.countdown >= 0.0:
		return ""
	if sim.rhythm == SimMatch.Rhythm.BETWEEN:
		return "Impossible pendant une vague"
	return "Aucune vague en attente"


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


## Or offert à chacun quand une vague part en avance : les secondes d'attente évitées (1 or par
## seconde). En versus, appelée pendant une vague, elle évite tout le compte à rebours qui aurait suivi.
## La première vague, lancée quand les joueurs le décident, ne rapporte pas de bonus.
static func early_bonus(sim: SimMatch) -> int:
	if not sim.started():
		return 0
	if sim.countdown >= 0.0:
		return int(sim.countdown)
	return int(SimMatch.BETWEEN_WAVES)


## « 4 % de l'or gardé » (4,5 % avec une décimale).
static func interest_text(rate: float) -> String:
	var pct := snappedf(rate * 100.0, 0.1)
	return "%s %% de l'or gardé" % (str(int(pct)) if is_equal_approx(pct, roundf(pct)) else str(pct).replace(".", ","))


## Intérêts versés au départ de chaque vague sur l'or gardé, sans plafond : seul le Gobelin en
## touche (taux de sa classe et de ses talents). Comptés avant l'or de la vague et le bonus d'avance.
static func interest(gold: int, kit: PlayerKit) -> int:
	return floori(maxi(0, gold) * kit.interest) if kit != null else 0

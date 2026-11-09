class_name HostLoop
extends RefCounted
## Boucle de jeu de l'hôte : simulation à pas fixe, vitesse x1/x2, limite de commandes par joueur.

const TICK := 0.05
const NET_EVERY := 2  # un instantané réseau tous les 2 ticks (10 par seconde)
const MAX_STEPS_PER_FRAME := 8
const COMMANDS_PER_SECOND := 20

var sim: SimMatch
var speed := 1
var _accum := 0.0
var _budget := {}
var _budget_timer := 1.0


func _init(p_sim: SimMatch) -> void:
	sim = p_sim


## Avance la partie. Appelle on_tick(instantané, à_envoyer_sur_le_réseau) après chaque tick.
func advance(delta: float, on_tick: Callable) -> void:
	_budget_timer -= delta
	if _budget_timer <= 0.0:
		_budget_timer = 1.0
		_budget.clear()
	_accum += delta * speed
	var steps := 0
	while _accum >= TICK and steps < MAX_STEPS_PER_FRAME:
		sim.step(TICK)
		_accum -= TICK
		steps += 1
		var to_network := sim.tick % NET_EVERY == 0
		var snap := sim.snapshot()
		snap["speed"] = speed
		snap["iv"] = TICK * (NET_EVERY if to_network else 1) / speed
		on_tick.call(snap, to_network)
	if steps == MAX_STEPS_PER_FRAME:
		_accum = 0.0  # machine trop lente : on ralentit plutôt que d'accumuler du retard


## Applique la commande d'un joueur. Renvoie "" ou le message d'erreur à lui afficher.
func handle(id: int, raw: Variant) -> String:
	_budget[id] = int(_budget.get(id, 0)) + 1
	if _budget[id] > COMMANDS_PER_SECOND:
		return ""  # inondation de commandes : ignorées sans réponse
	var cmd = Commands.sanitize(raw, sim.data, sim.map)
	if typeof(cmd) == TYPE_STRING:
		return cmd
	if cmd["a"] == "speed":
		if id == 1:
			speed = 3 - speed
		return ""
	return sim.apply_command(id, cmd)

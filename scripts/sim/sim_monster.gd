class_name SimMonster
extends RefCounted
## Monstre simulé par l'hôte. Avance le long d'un chemin de la carte (unités : cases).
##
## Effets : ralentissement, poison, brûlure (cumulable), saignement, et contrôles « durs »
## (étourdi : immobile ; apeuré : recule ; charmé : recule et frappe les autres monstres).
## Après un contrôle dur, une courte immunité évite de bloquer un monstre indéfiniment ;
## cc_resist (boss) raccourcit les contrôles et protège du charme à partir de 0,5.
## contrib : contribution de chaque joueur à sa mort (dégâts, contrôles), pour partager la prime.
## Bonus (DataSchema.PASSIVE_TRAITS) : lévitation, véhicule (insensible aux effets continus, à
## la peur et au charme), résistances aux éléments. Capacités (DataSchema.ABILITIES, jouées par
## MonsterAbilities) : bond en avant, protection des voisins, brouillage des tourelles.

enum Crowd { STUN, FEAR, CHARM }

## Vitesse de recul (part de la vitesse normale) quand le monstre a peur ou est charmé.
const BACK_SPEED := 0.6
## Immunité aux contrôles durs après la fin d'un contrôle (secondes).
const CONTROL_GUARD := 1.0
## Contribution d'une seconde de contrôle dur, en part des PV max du monstre.
const CONTROL_POINTS := 0.08
## Contribution d'une seconde de ralentissement complet, en part des PV max.
const SLOW_POINTS := 0.05
const CHARM_IMMUNE_FROM := 0.5

var id := 0
var type := ""
var type_index := 0
var hp := 1.0
var max_hp := 1.0
var hp_mult := 1.0
var speed := 1.0
var gold := 0
var damage := 1
var flying := false
var armor := 0.0
var regen := 0.0
var slow_immune := false
var cc_resist := 0.0
var heal_radius := 0.0
var heal_rate := 0.0
var split_into := ""
var split_count := 0
## Vague spéciale qui renforce ce monstre (vide si aucune), transmise à ses divisions.
var modifier := {}
var path := 0
var progress := 0.0
var length := 1.0
var pos := Vector2.ZERO
var slow_factor := 1.0
var slow_timer := 0.0
var poison_dps := 0.0
var poison_timer := 0.0
var poison_owner := 0
## Charges de poison et de saignement (1 sauf talents du Fléau : ses effets se cumulent).
var poison_stacks := 1
var bleed_stacks := 1
## Portée de contagion du poison en cours (0 : il ne se propage pas) et horloge de propagation.
var poison_spread := 0.0
var spread_clock := 0.0
## Armure rongée (part retirée) et durée restante.
var shred := 0.0
var shred_timer := 0.0
var burn_dps := 0.0  # par charge
var burn_stacks := 0
var burn_timer := 0.0
var burn_owner := 0
var bleed_rate := 0.0  # part des PV max par seconde
var bleed_timer := 0.0
var bleed_owner := 0
var stun_timer := 0.0
var fear_timer := 0.0
var charm_timer := 0.0
var charm_owner := 0
var control_guard := 0.0
var contrib := {}  # id joueur -> points
var hover := false
var mechanical := false
## Élément -> part des dégâts (et des effets) de cet élément réellement subie.
var element_taken := {}
var blink_interval := 0.0
var blink_distance := 0.0
var blink_clock := 0.0
var ward_radius := 0.0
var ward := 0.0
## Protection reçue du meilleur protecteur voisin (part des dégâts évitée), à chaque pas.
var warded := 0.0
var jam_radius := 0.0
var jam_interval := 0.0
var jam_duration := 0.0
var jam_clock := 0.0
## Gelure, électrifié, soins coupés, cloué au sol (spécialisations).
var marks := MonsterMarks.new()


## Remplit les caractéristiques depuis la définition du monstre (données du jeu).
## p_hp_mult inclut déjà le multiplicateur de PV de la vague spéciale `mod`.
func setup(def: Dictionary, p_hp_mult: float, reward_mult: float, mod := {}) -> void:
	modifier = mod
	hp_mult = p_hp_mult
	max_hp = float(def["hp"]) * hp_mult
	hp = max_hp
	speed = float(def["speed"]) * float(mod.get("speed", 1.0))
	var base_gold: int = def["gold"]
	var gold_mult := reward_mult * float(mod.get("gold", 1.0))
	gold = maxi(1, roundi(base_gold * gold_mult)) if base_gold > 0 else 0
	damage = def["damage"]
	flying = def["flying"]
	armor = float(def["armor"]) + float(mod.get("armor", 0.0))
	regen = float(def["regen"]) + max_hp * float(mod.get("regen", 0.0))
	slow_immune = def["slow_immune"]
	cc_resist = def.get("cc_resist", 0.0)
	heal_radius = def["heal_radius"]
	heal_rate = def["heal_rate"]
	split_into = def["split_into"]
	split_count = def["split_count"]
	hover = def["hover"] or mod.get("hover", false)
	mechanical = def["mechanical"] or mod.get("mechanical", false)
	var magic := 1.0 - _trait(def, mod, "resist_elements")
	for e in DataSchema.ELEMENTS:
		element_taken[e] = magic * (1.0 - _trait(def, mod, "resist_" + e))
	var physical := 1.0 - _trait(def, mod, "resist_physical")
	element_taken[""] = physical
	for e in DataSchema.PHYSICAL:
		element_taken[e] = physical * (1.0 - _trait(def, mod, "resist_" + e))
	for key in DataSchema.ABILITIES:  # blink_*, ward*, jam_* : mêmes noms que les variables
		set(key, float(def[key]))


## Bonus passif chiffré du monstre ou de sa vague spéciale : le plus fort des deux.
static func _trait(def: Dictionary, mod: Dictionary, key: String) -> float:
	return maxf(float(def.get(key, 0.0)), float(mod.get(key, 0.0)))


## Part des dégâts d'un élément réellement subie ("", « pierce », « blunt » : coups physiques ;
## 0 : le monstre y est insensible, les tourelles ne le visent pas).
func taken(element: String) -> float:
	return float(element_taken.get(element, 1.0))


func is_alive() -> bool:
	return hp > 0.0


func reached_end() -> bool:
	return progress >= length


## Part du chemin déjà parcourue (0 à 1), sert à viser « le plus avancé ».
func ratio() -> float:
	return progress / length if length > 0.0 else 1.0


func is_slowed() -> bool:
	return slow_timer > 0.0


func is_poisoned() -> bool:
	return poison_timer > 0.0


func is_burning() -> bool:
	return burn_timer > 0.0


func is_bleeding() -> bool:
	return bleed_timer > 0.0


func is_stunned() -> bool:
	return stun_timer > 0.0


func is_feared() -> bool:
	return fear_timer > 0.0


## Un monstre charmé se bat pour les joueurs : les tourelles l'ignorent.
func is_charmed() -> bool:
	return charm_timer > 0.0


func is_elite() -> bool:
	return not modifier.is_empty()


func move(dt: float) -> void:
	control_guard = maxf(0.0, control_guard - dt)
	var mult := slow_factor if slow_timer > 0.0 else 1.0
	slow_timer = maxf(0.0, slow_timer - dt)
	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - dt)
		return
	if fear_timer > 0.0 or charm_timer > 0.0:
		fear_timer = maxf(0.0, fear_timer - dt)
		charm_timer = maxf(0.0, charm_timer - dt)
		progress = maxf(0.0, progress - speed * BACK_SPEED * mult * dt)
		return
	progress += speed * mult * dt


## Ajoute des points de contribution. credit : [[id joueur, part], ...] (parts de somme 1).
func add_contrib(credit: Array, points: float) -> void:
	if points <= 0.0:
		return
	for c in credit:
		contrib[c[0]] = float(contrib.get(c[0], 0.0)) + points * float(c[1])


## Applique un ralentissement : garde le plus fort, prolonge la durée.
## Renvoie les secondes de ralentissement ajoutées (pour la contribution).
func apply_slow(factor: float, duration: float) -> float:
	if slow_immune or factor >= 1.0 or duration <= 0.0:
		return 0.0
	var before := slow_timer
	if slow_timer <= 0.0 or factor < slow_factor:
		slow_factor = factor
	slow_timer = maxf(slow_timer, duration)
	return slow_timer - before


## Empoisonne : garde le poison le plus fort (et son auteur pour la prime, et sa contagion),
## prolonge la durée.
## max_stacks > 1 (Fléau) : chaque coup ajoute une charge, comme la brûlure ; une source au
## plafond plus bas ne retire jamais de charges déjà posées.
func apply_poison(dps: float, duration: float, owner: int, spread := 0.0, max_stacks := 1) -> void:
	if mechanical or dps <= 0.0 or duration <= 0.0:
		return
	poison_stacks = 1 if poison_timer <= 0.0 else maxi(poison_stacks, mini(poison_stacks + 1, max_stacks))
	if poison_timer <= 0.0 or dps >= poison_dps:
		poison_dps = dps
		poison_owner = owner
		poison_spread = spread
	poison_timer = maxf(poison_timer, duration)


## Ronge l'armure : garde la plus forte part retirée, prolonge la durée.
func apply_shred(part: float, duration: float) -> void:
	if part <= 0.0 or duration <= 0.0:
		return
	if shred_timer <= 0.0 or part > shred:
		shred = part
	shred_timer = maxf(shred_timer, duration)


## Armure restante face à un coup qui en ignore la part `pierce`.
func armor_against(pierce: float) -> float:
	var left := armor * (1.0 - pierce)
	return left * (1.0 - shred) if shred_timer > 0.0 else left


## Brûlure : chaque coup ajoute une charge (jusqu'à max_stacks) et relance la durée.
## Une source au plafond plus bas ne retire jamais de charges déjà posées.
func apply_burn(dps: float, duration: float, max_stacks: int, owner: int) -> void:
	if mechanical or dps <= 0.0 or duration <= 0.0 or max_stacks <= 0:
		return
	if burn_timer <= 0.0:
		burn_stacks = 0
	burn_dps = maxf(burn_dps if burn_timer > 0.0 else 0.0, dps)
	burn_stacks = maxi(burn_stacks, mini(burn_stacks + 1, max_stacks))
	burn_owner = owner
	burn_timer = duration


## Saignement : part des PV max par seconde (les boss y résistent en partie).
func apply_bleed(rate: float, duration: float, owner: int, max_stacks := 1) -> void:
	if mechanical or rate <= 0.0 or duration <= 0.0:
		return
	bleed_stacks = 1 if bleed_timer <= 0.0 else maxi(bleed_stacks, mini(bleed_stacks + 1, max_stacks))
	if bleed_timer <= 0.0 or rate >= bleed_rate:
		bleed_rate = rate
		bleed_owner = owner
	bleed_timer = maxf(bleed_timer, duration)


## Contrôle dur. Renvoie la durée réellement appliquée (0 si résisté ou immunisé).
func apply_control(kind: int, duration: float, owner: int) -> float:
	if control_guard > 0.0 or duration <= 0.0:
		return 0.0
	if kind == Crowd.CHARM and (cc_resist >= CHARM_IMMUNE_FROM or flying):
		return 0.0
	if kind != Crowd.STUN and mechanical:  # un véhicule ne s'effraie pas et ne se laisse pas charmer
		return 0.0
	var d := duration * (1.0 - cc_resist)
	if d < 0.1:
		return 0.0
	match kind:
		Crowd.STUN:
			stun_timer = d
		Crowd.FEAR:
			fear_timer = d
		Crowd.CHARM:
			charm_timer = d
			charm_owner = owner
	control_guard = d + CONTROL_GUARD
	return d

class_name MonsterMarks
extends RefCounted
## États posés sur un monstre par les spécialisations :
## - gelure : dégâts continus de gel (qui ignorent l'armure), plus forts sur un monstre ralenti
##   et plus encore sur un monstre gelé (étourdi) ; la plus forte garde la main ;
## - électrifié : le monstre subit une part de dégâts en plus, de toutes les sources ;
## - soins coupés : régénération et soins des chamans réduits d'une part ;
## - cloué au sol : un volant devient touchable par toutes les tourelles (il garde sa route).

const FROSTBITE_DURATION := 2.5
const SHOCK_DURATION := 2.5
const FROSTBITE_SLOWED := 1.5
const FROSTBITE_FROZEN := 2.0

var frost_dps := 0.0
var frost_timer := 0.0
var frost_owner := 0
var shock := 0.0
var shock_timer := 0.0
var heal_block := 0.0
var heal_block_timer := 0.0
var grounded := 0.0
## Talents (BoardFeats) : marque (part de dégâts subis en plus), armure brisée (points retirés),
## effets transmis à la mort (nombre de voisins : brûlure, poison, électrifié).
var mark := 0.0
var mark_timer := 0.0
var armor_down := 0
var death_spread := {}  # "burn" / "poison" / "shock" -> nombre de voisins
## Flaque laissée à la mort (part des PV max par seconde, et qui la pose), coups de foudre reçus.
var puddle := 0.0
var puddle_owner := 0
var static_hits := 0


func apply_mark(part: float, duration: float) -> void:
	if part <= 0.0:
		return
	if mark_timer <= 0.0 or part > mark:
		mark = part
	mark_timer = maxf(mark_timer, duration)


## Retire 1 point d'armure, jusqu'à `cap` points en tout.
func break_armor(cap: int) -> void:
	armor_down = maxi(armor_down, mini(cap, armor_down + 1))


func spread_on_death(kind: String, count: int) -> void:
	if count > int(death_spread.get(kind, 0)):
		death_spread[kind] = count


func apply_frostbite(dps: float, owner: int) -> void:
	if dps <= 0.0:
		return
	if frost_timer <= 0.0 or dps >= frost_dps:
		frost_dps = dps
		frost_owner = owner
	frost_timer = FROSTBITE_DURATION


func apply_shock(part: float) -> void:
	if part <= 0.0:
		return
	if shock_timer <= 0.0 or part > shock:
		shock = part
	shock_timer = SHOCK_DURATION


func apply_heal_block(part: float, duration: float) -> void:
	if part <= 0.0 or duration <= 0.0:
		return
	if heal_block_timer <= 0.0 or part > heal_block:
		heal_block = part
	heal_block_timer = maxf(heal_block_timer, duration)


func ground(duration: float) -> void:
	grounded = maxf(grounded, duration)


## Fait passer le temps (la gelure, elle, s'écoule dans MonsterEffects avec ses dégâts).
func update(dt: float) -> void:
	shock_timer = maxf(0.0, shock_timer - dt)
	heal_block_timer = maxf(0.0, heal_block_timer - dt)
	grounded = maxf(0.0, grounded - dt)
	mark_timer = maxf(0.0, mark_timer - dt)


## Part de dégâts subis en plus (électrifié, marqué).
func vulnerability() -> float:
	return (shock if shock_timer > 0.0 else 0.0) + (mark if mark_timer > 0.0 else 0.0)


## Part des soins et de la régénération qui passe encore.
func heal_mult() -> float:
	return 1.0 - heal_block if heal_block_timer > 0.0 else 1.0


func is_frostbitten() -> bool:
	return frost_timer > 0.0


func is_shocked() -> bool:
	return shock_timer > 0.0


func is_grounded() -> bool:
	return grounded > 0.0

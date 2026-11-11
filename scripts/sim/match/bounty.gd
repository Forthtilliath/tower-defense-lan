class_name Bounty
extends RefCounted
## Partage de la prime d'un monstre entre les joueurs qui ont contribué à sa mort
## (dégâts infligés, part des auras, secondes de contrôle), au prorata, sans perte ni création
## d'or : les arrondis vont aux plus grosses parts restantes.


## Renvoie [[id joueur, or], ...] (parts nulles omises). fallback : joueur crédité si personne
## n'a contribué (prime entière).
static func split(gold: int, contrib: Dictionary, fallback: int) -> Array:
	if gold <= 0:
		return []
	var total := 0.0
	for owner in contrib:
		total += maxf(0.0, float(contrib[owner]))
	if total <= 0.0:
		return [[fallback, gold]]
	var shares := []
	var given := 0
	for owner in contrib:
		var exact := gold * maxf(0.0, float(contrib[owner])) / total
		var whole := floori(exact)
		shares.append([owner, whole, exact - whole])
		given += whole
	shares.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	for i in gold - given:
		shares[i % shares.size()][1] += 1
	var out := []
	for s in shares:
		if s[1] > 0:
			out.append([s[0], s[1]])
	return out

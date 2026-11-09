class_name DataSchema
extends RefCounted
## Schémas des données du jeu, appliqués par DataValidator.
##
## Règle de schéma : [type, arguments..., (valeur par défaut)].
## Types : "int" (min, max), "num" (min, max), "text" (longueur max), "bool", "id", "color".

const ARGC := {"int": 2, "num": 2, "text": 1}

## interest : part de l'or gardé versée à chaque vague (plafonnée à interest_cap).
## gift_ratio : part d'un don d'or réellement reçue par l'allié (le reste est perdu).
const PLAYER := {
	"start_gold": ["int", 0, 100000], "interest": ["num", 0.0, 0.5, 0.0],
	"interest_cap": ["int", 0, 100000, 0], "gift_ratio": ["num", 0.05, 1.0, 0.5],
	"gift_min": ["int", 1, 100000, 10],
}
const COOP_SCALING := {"hp": ["num", 0.0, 5.0], "count": ["num", 0.0, 5.0]}
const DIFFICULTY := {
	"id": ["id"], "name": ["text", 24], "hp": ["num", 0.1, 10.0], "lives": ["int", 1, 1000],
	"gold": ["num", 0.1, 10.0], "reward": ["num", 0.1, 10.0],
}
## Bâtisseur : tourelles autorisées et bonus appliqués à toutes ses tourelles.
const BUILDER := {
	"id": ["id"], "name": ["text", 24], "color": ["color"], "description": ["text", 120, ""],
	"damage": ["num", 0.5, 3.0, 1.0], "range": ["num", 0.5, 3.0, 1.0], "rate": ["num", 0.5, 3.0, 1.0],
}
## Vague spéciale : multiplicateurs (PV, vitesse, nombre, primes) et ajouts (armure, régénération
## en part des PV max par seconde) appliqués à tous les monstres de la vague.
const WAVE_MODIFIER := {
	"id": ["id"], "name": ["text", 24], "color": ["color"], "description": ["text", 120, ""],
	"hp": ["num", 0.1, 20.0, 1.0], "speed": ["num", 0.2, 5.0, 1.0], "count": ["num", 0.1, 10.0, 1.0],
	"gold": ["num", 0.0, 20.0, 1.0], "armor": ["num", 0.0, 1000.0, 0.0], "regen": ["num", 0.0, 1.0, 0.0],
}
const SPECIAL := {
	"char": ["text", 1], "id": ["id"], "name": ["text", 24], "color": ["color"],
	"description": ["text", 120, ""], "range": ["num", 0.5, 3.0, 1.0], "damage": ["num", 0.5, 5.0, 1.0],
	"rate": ["num", 0.5, 5.0, 1.0], "gold_per_wave": ["int", 0, 10000, 0],
}
const TOWER := {
	"id": ["id"], "name": ["text", 24], "description": ["text", 120, ""],
	"color": ["color"], "air": ["bool"], "ground": ["bool"],
}
const TOWER_LEVEL := {
	"cost": ["int", 1, 100000], "damage": ["num", 0.0, 100000.0],
	"range": ["num", 0.5, 12.0], "rate": ["num", 0.05, 20.0],
	"projectile_speed": ["num", 1.0, 60.0], "splash": ["num", 0.0, 5.0, 0.0],
	"slow_factor": ["num", 0.1, 1.0, 1.0], "slow_duration": ["num", 0.0, 10.0, 0.0],
	"chain": ["int", 0, 10, 0], "poison_dps": ["num", 0.0, 100000.0, 0.0],
	"poison_duration": ["num", 0.0, 30.0, 0.0],
}
const MONSTER := {
	"id": ["id"], "name": ["text", 24], "color": ["color"],
	"hp": ["num", 1.0, 1000000.0], "speed": ["num", 0.1, 10.0],
	"gold": ["int", 0, 100000], "damage": ["int", 1, 1000], "flying": ["bool"],
	"size": ["num", 0.2, 1.0, 0.5], "send_cost": ["int", 0, 100000, 0],
	"income": ["int", 0, 10000, 0], "armor": ["num", 0.0, 100000.0, 0.0],
	"regen": ["num", 0.0, 100000.0, 0.0], "slow_immune": ["bool", false],
	"heal_radius": ["num", 0.0, 10.0, 0.0], "heal_rate": ["num", 0.0, 100000.0, 0.0],
	"split_into": ["id", ""], "split_count": ["int", 0, 10, 0],
}
const WAVE := {
	"id": ["id"], "gold": ["int", 0, 100000, 0], "hp": ["num", 0.1, 100.0, 1.0], "modifier": ["id", ""],
}
const GROUP := {"monster": ["id"], "count": ["int", 1, 500], "interval": ["num", 0.05, 30.0]}
## flyer_speed : ralentit les volants sur les cartes où leur ligne droite est un raccourci énorme.
## lanes : couloirs séparés, chacun défendu par ses propres tourelles (renforcement coop).
const MAP := {
	"id": ["id"], "name": ["text", 32], "flyer_speed": ["num", 0.2, 1.0, 1.0],
	"min_players": ["int", 1, 4, 1], "max_players": ["int", 1, 4, 4], "lanes": ["int", 1, 8, 1],
}

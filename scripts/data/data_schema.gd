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
## Progression : expérience pour passer du niveau n au suivant = xp_base × xp_growth^(n-1) ;
## une victoire rapporte xp_per_wave par vague (× xp de la difficulté), plus win_bonus de
## cette somme. Défaite : chaque vague passée rapporte une part de xp_per_wave qui dépend du
## palier atteint (la partie est découpée en defeat_steps paliers égaux) : defeat_rate_min au
## premier, defeat_rate_max au dernier, en progression régulière. 1 point de talent par niveau.
## tiers : points à dépenser dans une branche pour atteindre chaque palier (le premier vaut 0).
const PROGRESSION := {
	"max_level": ["int", 1, 50, 15], "xp_base": ["int", 1, 100000, 100], "xp_growth": ["num", 1.0, 3.0, 1.2],
	"xp_per_wave": ["int", 0, 10000, 10], "win_bonus": ["num", 0.0, 2.0, 0.25],
	"defeat_steps": ["int", 1, 10, 4], "defeat_rate_min": ["num", 0.0, 1.0, 0.1],
	"defeat_rate_max": ["num", 0.0, 1.0, 0.85],
}
const DIFFICULTY := {
	"id": ["id"], "name": ["text", 24], "hp": ["num", 0.1, 10.0], "lives": ["int", 1, 1000],
	"gold": ["num", 0.1, 10.0], "reward": ["num", 0.1, 10.0], "xp": ["num", 0.0, 10.0, 1.0],
	"armor": ["num", 0.0, 20.0, 0.0],
}
## Branche de talents. trunk : tronc commun de la classe ; les autres branches sont ses
## spécialisations, exclusives (des points dans une seule à la fois).
const BRANCH := {"id": ["id"], "name": ["text", 24], "description": ["text", 120, ""], "trunk": ["bool", false]}
## Talent : bonus par rang (s'ajoutent), sur les tourelles listées dans « towers » (toutes si vide),
## ou déblocage d'une tourelle (« unlock »). aura : renforce les auras des tourelles de soutien.
## build_cost : réduction du prix de construction et d'amélioration ; sell_bonus : part de revente
## en plus ; gift_bonus : part en plus reçue par l'allié lors d'un don (plafonds : PlayerKit).
const TALENT := {
	"id": ["id"], "name": ["text", 32], "description": ["text", 160, ""], "tier": ["int", 1, 6],
	"max_rank": ["int", 1, 5, 1], "unlock": ["id", ""],
	"damage": ["num", 0.0, 1.0, 0.0], "rate": ["num", 0.0, 1.0, 0.0], "range": ["num", 0.0, 1.0, 0.0],
	"cc": ["num", 0.0, 1.0, 0.0], "aura": ["num", 0.0, 1.0, 0.0], "bounty": ["num", 0.0, 1.0, 0.0],
	"interest": ["num", 0.0, 0.1, 0.0], "interest_cap": ["int", 0, 1000, 0], "start_gold": ["int", 0, 10000, 0],
	"build_cost": ["num", 0.0, 0.2, 0.0], "sell_bonus": ["num", 0.0, 0.1, 0.0], "gift_bonus": ["num", 0.0, 0.25, 0.0],
	"team_bounty": ["num", 0.0, 0.2, 0.0], "early_bonus": ["num", 0.0, 2.0, 0.0], "clean_gold": ["int", 0, 1000, 0],
	"imbue_all": ["bool", false], "raze_charges": ["int", 0, 20, 0], "tile_charges": ["int", 0, 10, 0],
	"ultimate": ["bool", false],
}
## ultimate : talent ultime d'une spécialisation, réservé au niveau maximum (le dernier point).
## grant (objet facultatif, voir GRANT) : effets ajoutés aux tourelles visées (après les bonus).
const GRANT := {
	"armor_pierce": ["num", 0.0, 1.0, 0.0], "splash": ["num", 0.0, 3.0, 0.0],
	"stun_chance": ["num", 0.0, 1.0, 0.0], "stun_duration": ["num", 0.0, 5.0, 0.0],
	"patch_radius": ["num", 0.0, 2.0, 0.0], "patch_duration": ["num", 0.0, 10.0, 0.0], "patch_dps": ["num", 0.0, 1000.0, 0.0],
	"multishot": ["int", 0, 4, 0], "burn_stacks": ["int", 0, 5, 0], "chain": ["int", 0, 5, 0],
	"poison_stacks": ["int", 0, 5, 0], "bleed_stacks": ["int", 0, 5, 0],
	"vs_stunned": ["num", 0.0, 5.0, 0.0], "ground_duration": ["num", 0.0, 5.0, 0.0], "poison_spread": ["num", 0.0, 3.0, 0.0],
	"bleed": ["num", 0.0, 0.1, 0.0], "shred": ["num", 0.0, 0.5, 0.0], "heal_block": ["num", 0.0, 1.0, 0.0],
}
## Plafonds des statistiques après les effets ajoutés (une part au-delà de 1 n'a pas de sens).
const GRANT_CAPS := {"armor_pierce": 1.0, "stun_chance": 1.0, "shred": 0.9, "heal_block": 1.0}
## raze_charges : arbres ou rochers qu'il peut raser par partie ; tile_charges : cases spéciales
## (Colline, Cristal, Rune) qu'il peut poser par partie (Terrassier).
## team_bounty : part de prime en plus pour toute l'équipe (le joueur compris). early_bonus : or
## des vagues lancées en avance multiplié d'autant en plus. clean_gold : or par vague franchie
## sans perdre de vie. imbue_all : ses tourelles d'imprégnation (Stèle de gelure, Paratonnerre)
## renforcent toutes les tourelles voisines, pas seulement celles de leur élément.
## Classe : tourelles en plus du tronc commun (« towers », souvent aucune : les spécialisations
## débloquent les leurs), branches de talents, et bonus de classe. Les multiplicateurs (dégâts,
## portée, cadence, contrôles, auras) valent pour les tourelles de « bonus_towers » (toutes si vide).
## cc : multiplie les chances et durées de contrôle. bounty : multiplie sa part des primes.
## interest / interest_cap / start_gold : s'ajoutent à ceux du joueur.
const BUILDER := {
	"id": ["id"], "name": ["text", 24], "color": ["color"], "description": ["text", 200, ""],
	"damage": ["num", 0.5, 3.0, 1.0], "range": ["num", 0.5, 3.0, 1.0], "rate": ["num", 0.5, 3.0, 1.0],
	"cc": ["num", 0.5, 3.0, 1.0], "aura": ["num", 0.5, 3.0, 1.0], "bounty": ["num", 0.5, 3.0, 1.0],
	"interest": ["num", 0.0, 0.2, 0.0], "interest_cap": ["int", 0, 10000, 0], "start_gold": ["int", 0, 10000, 0],
}
## Éléments des tourelles ("" : coups physiques), auxquels certains monstres résistent.
const ELEMENTS := ["fire", "ice", "lightning", "poison", "bleed", "wind"]
## Coups physiques : perçants (flèches, carreaux, fléchettes) ou contondants (boulets, obus,
## masse). Une tourelle sans élément (contrôle, soutien) frappe aussi physiquement.
const PHYSICAL := ["pierce", "blunt"]
## Bonus passifs d'un monstre, qu'une vague spéciale peut aussi donner à tous ses monstres.
## hover : lévite, les nappes au sol ne le touchent pas. mechanical : véhicule, insensible au
## poison, à la brûlure, au saignement, à la peur et au charme. resist_* : part des dégâts (et
## des effets) de cet élément évitée ; resist_elements vaut pour tous les éléments (la magie et
## les effets continus) ; resist_physical pour tous les coups physiques (1 : intangible, comme
## un fantôme) ; resist_pierce / resist_blunt pour les coups perçants / contondants.
const PASSIVE_TRAITS := {
	"hover": ["bool", false], "mechanical": ["bool", false],
	"resist_fire": ["num", 0.0, 0.9, 0.0], "resist_ice": ["num", 0.0, 0.9, 0.0],
	"resist_lightning": ["num", 0.0, 0.9, 0.0], "resist_elements": ["num", 0.0, 0.9, 0.0],
	"resist_physical": ["num", 0.0, 1.0, 0.0], "resist_pierce": ["num", 0.0, 1.0, 0.0],
	"resist_blunt": ["num", 0.0, 1.0, 0.0],
}
## Vague spéciale : multiplicateurs (PV, vitesse, nombre, primes) et ajouts (armure, régénération
## en part des PV max par seconde, bonus passifs) appliqués à tous les monstres de la vague.
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
## support : tourelle de soutien, qui ne tire pas mais renforce les tourelles dans sa portée.
## attack : façon de frapper (voir ATTACKS). element : voir ELEMENTS (vide : physique).
const TOWER := {
	"id": ["id"], "name": ["text", 24], "description": ["text", 120, ""],
	"color": ["color"], "air": ["bool"], "ground": ["bool"], "support": ["bool", false],
	"attack": ["id", "shot"], "element": ["id", ""],
}
## shot : projectile ; pulse : onde autour de la tourelle (tous les monstres à portée) ;
## line : trait qui traverse tous les monstres alignés jusqu'au bout de la portée ;
## cone : souffle en cône vers la cible ; beam : rayon continu qui s'accroche à sa cible.
const ATTACKS := ["shot", "pulse", "line", "cone", "beam"]
## Effets : poison (le plus fort garde la main), brûlure (cumul jusqu'à burn_stacks charges),
## saignement (part des PV max par seconde), contrôles (chance par coup et durée),
## auras des tourelles de soutien (bonus ajouté, dans la portée de la tourelle).
## armor_pierce : part de l'armure ignorée. patch_* : nappe au sol laissée à l'impact
## (dégâts/s qui ignorent l'armure, effets du tir réappliqués). ramp / ramp_max : chaque coup
## d'un rayon sur la même cible ajoute ramp aux dégâts (multiplicateur plafonné à ramp_max).
## vs_slowed / vs_stunned : dégâts en plus contre un monstre ralenti / étourdi (gelé).
## shred : part de l'armure rongée. poison_spread : portée de contagion du poison.
## crit_every / crit_mult : un coup sur crit_every est critique (dégâts × crit_mult).
## poison_stacks / bleed_stacks : charges maximales (le poison ou le saignement se cumule à chaque
## coup, comme la brûlure ; 1 : il ne se cumule pas). multishot : nombre de monstres visés à chaque tir. heal_block : part des soins et de la
## régénération coupée (heal_block_duration s). ground_duration : un volant touché est cloué
## au sol (toutes les tourelles peuvent le toucher) pendant ces secondes.
## Auras des tourelles de soutien : aura_range (portée des voisines), aura_frostbite (gelure,
## dégâts/s ajoutés aux coups des voisines de glace), aura_shock (électrifie : part de dégâts
## subis en plus, coups des voisines de foudre), aura_bounty (prime en plus des monstres tués à
## portée), aura_discount (réduction des constructions et améliorations à portée).
const TOWER_LEVEL := {
	"cost": ["int", 1, 100000], "damage": ["num", 0.0, 100000.0],
	"range": ["num", 0.5, 12.0], "rate": ["num", 0.05, 20.0],
	"projectile_speed": ["num", 1.0, 60.0, 10.0], "splash": ["num", 0.0, 5.0, 0.0],
	"slow_factor": ["num", 0.1, 1.0, 1.0], "slow_duration": ["num", 0.0, 10.0, 0.0],
	"chain": ["int", 0, 10, 0], "poison_dps": ["num", 0.0, 100000.0, 0.0],
	"poison_duration": ["num", 0.0, 30.0, 0.0],
	"burn_dps": ["num", 0.0, 100000.0, 0.0], "burn_duration": ["num", 0.0, 30.0, 0.0],
	"burn_stacks": ["int", 0, 10, 0],
	"bleed": ["num", 0.0, 1.0, 0.0], "bleed_duration": ["num", 0.0, 30.0, 0.0],
	"stun_chance": ["num", 0.0, 1.0, 0.0], "stun_duration": ["num", 0.0, 10.0, 0.0],
	"fear_chance": ["num", 0.0, 1.0, 0.0], "fear_duration": ["num", 0.0, 10.0, 0.0],
	"charm_chance": ["num", 0.0, 1.0, 0.0], "charm_duration": ["num", 0.0, 10.0, 0.0],
	"aura_rate": ["num", 0.0, 3.0, 0.0], "aura_damage": ["num", 0.0, 3.0, 0.0],
	"aura_cc": ["num", 0.0, 3.0, 0.0],
	"armor_pierce": ["num", 0.0, 1.0, 0.0],
	"patch_radius": ["num", 0.0, 3.0, 0.0], "patch_duration": ["num", 0.0, 20.0, 0.0],
	"patch_dps": ["num", 0.0, 100000.0, 0.0],
	"ramp": ["num", 0.0, 2.0, 0.0], "ramp_max": ["num", 1.0, 10.0, 1.0],
	"vs_slowed": ["num", 0.0, 5.0, 0.0], "vs_stunned": ["num", 0.0, 5.0, 0.0],
	"shred": ["num", 0.0, 0.9, 0.0], "shred_duration": ["num", 0.0, 30.0, 0.0],
	"poison_spread": ["num", 0.0, 5.0, 0.0],
	"crit_every": ["int", 0, 20, 0], "crit_mult": ["num", 1.0, 10.0, 1.0],
	"poison_stacks": ["int", 1, 10, 1], "bleed_stacks": ["int", 1, 10, 1],
	"multishot": ["int", 1, 8, 1], "heal_block": ["num", 0.0, 1.0, 0.0], "heal_block_duration": ["num", 0.0, 30.0, 0.0],
	"ground_duration": ["num", 0.0, 10.0, 0.0],
	"aura_range": ["num", 0.0, 1.0, 0.0], "aura_frostbite": ["num", 0.0, 100000.0, 0.0],
	"aura_shock": ["num", 0.0, 1.0, 0.0], "aura_bounty": ["num", 0.0, 2.0, 0.0], "aura_discount": ["num", 0.0, 0.5, 0.0],
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
	"cc_resist": ["num", 0.0, 1.0, 0.0],
}
## Capacités actives d'un monstre (en plus des PASSIVE_TRAITS), chacune décrite par un groupe
## de champs qui vont ensemble (tous nuls ou tous positifs, voir LINKED) :
## blink : bond en avant de blink_distance cases toutes les blink_interval secondes ;
## ward : les autres monstres à ward_radius cases subissent `ward` (part) de dégâts en moins ;
## jam : toutes les jam_interval s, brouille les tourelles à jam_radius cases pendant jam_duration s.
const ABILITIES := {
	"blink_interval": ["num", 0.0, 60.0, 0.0], "blink_distance": ["num", 0.0, 10.0, 0.0],
	"ward_radius": ["num", 0.0, 5.0, 0.0], "ward": ["num", 0.0, 0.9, 0.0],
	"jam_radius": ["num", 0.0, 5.0, 0.0], "jam_interval": ["num", 0.0, 60.0, 0.0],
	"jam_duration": ["num", 0.0, 10.0, 0.0],
}
const LINKED := [["blink_interval", "blink_distance"], ["ward_radius", "ward"], ["jam_radius", "jam_interval", "jam_duration"]]
const WAVE := {
	"id": ["id"], "gold": ["int", 0, 100000, 0], "hp": ["num", 0.1, 100.0, 1.0], "modifier": ["id", ""],
}
const GROUP := {"monster": ["id"], "count": ["int", 1, 500], "interval": ["num", 0.05, 30.0]}
## flyer_speed : ralentit les volants sur les cartes où leur ligne droite est un raccourci énorme.
## lanes : couloirs séparés, chacun défendu par ses propres tourelles (renforcement coop).
## tier : difficulté de la carte (0 facile, 1 moyenne, 2 difficile, voir MAP_TIERS), mesurée au bot.
const MAP := {
	"id": ["id"], "name": ["text", 32], "flyer_speed": ["num", 0.2, 1.0, 1.0],
	"min_players": ["int", 1, 4, 1], "max_players": ["int", 1, 4, 4], "lanes": ["int", 1, 8, 1],
	"tier": ["int", 0, 2, 1],
}
const MAP_TIERS := ["facile", "moyenne", "difficile"]

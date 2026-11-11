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
## Case spéciale : voir TileBonus pour chaque effet. geomancy : se pose avec la Géomancie du
## Terrassier (les autres cases posables ont leurs propres charges, BoardTerrain.OWN_CHARGES).
## slow : ralentit les monstres qui passent à côté (BoardTerrain.DITCH_REACH).
const SPECIAL := {
	"char": ["text", 1], "id": ["id"], "name": ["text", 24], "color": ["color"],
	"description": ["text", 120, ""], "range": ["num", 0.5, 3.0, 1.0], "damage": ["num", 0.5, 5.0, 1.0],
	"rate": ["num", 0.5, 5.0, 1.0], "only": ["id", ""], "durations": ["num", 1.0, 3.0, 1.0],
	"chain": ["int", 0, 3, 0], "crit": ["num", 0.0, 0.5, 0.0], "vs_big": ["num", 0.0, 3.0, 0.0],
	"air": ["bool", false], "veteran": ["num", 0.0, 0.1, 0.0], "veteran_cap": ["num", 0.0, 1.0, 0.0],
	"kill_gold": ["int", 0, 20, 0], "wears": ["int", 0, 50, 0], "discount": ["num", 0.0, 0.5, 0.0],
	"nojam": ["bool", false], "geomancy": ["bool", false], "slow": ["num", 0.0, 0.9, 0.0],
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
	# Effets des talents (BoardFeats), nuls sur les tourelles de base : voir FEATS
	"crit_chance": ["num", 0.0, 1.0, 0.0], "crit_bonus": ["num", 0.0, 5.0, 0.0], "execute": ["num", 0.0, 0.5, 0.0],
	"pierce": ["int", 0, 10, 0], "ricochet": ["num", 0.0, 1.0, 0.0], "streak": ["num", 0.0, 0.1, 0.0],
	"streak_cap": ["num", 0.0, 3.0, 0.0], "mark": ["num", 0.0, 1.0, 0.0], "warmup": ["num", 0.0, 1.0, 0.0],
	"warmup_cap": ["num", 0.0, 3.0, 0.0], "frag": ["num", 0.0, 2.0, 0.0], "knockback": ["num", 0.0, 1.0, 0.0],
	"armor_break": ["int", 0, 20, 0], "kill_splash": ["num", 0.0, 3.0, 0.0], "vs_big": ["num", 0.0, 5.0, 0.0],
	"reaction": ["num", 0.0, 3.0, 0.0], "resonance": ["num", 0.0, 1.0, 0.0],
	"death_burn": ["int", 0, 5, 0], "death_poison": ["int", 0, 5, 0], "death_shock": ["int", 0, 5, 0],
	"slow": ["num", 0.0, 0.9, 0.0], "dot_duration": ["num", 0.0, 3.0, 0.0], "last_stand": ["num", 0.0, 3.0, 0.0],
	"growth": ["num", 0.0, 0.2, 0.0], "harmony": ["num", 0.0, 0.5, 0.0], "static_charge": ["num", 0.0, 3.0, 0.0],
	"storm": ["num", 0.0, 5.0, 0.0], "chain_keep": ["num", 0.0, 0.2, 0.0], "vs_armored": ["num", 0.0, 5.0, 0.0],
	"all_targets": ["int", 0, 1, 0], "vs_afflicted": ["num", 0.0, 5.0, 0.0], "death_puddle": ["num", 0.0, 0.2, 0.0],
	"vs_fast": ["num", 0.0, 2.0, 0.0], "vs_wounded": ["num", 0.0, 5.0, 0.0],
	"wall": ["num", 0.0, 0.5, 0.0], "keystone": ["num", 0.0, 1.0, 0.0], "twin": ["num", 0.0, 1.0, 0.0],
	"crown": ["num", 0.0, 1.0, 0.0], "plans": ["num", 0.0, 1.0, 0.0], "buttress": ["num", 0.0, 1.0, 0.0],
	"masterpiece": ["num", 0.0, 3.0, 0.0],
	"aura_crit": ["num", 0.0, 1.0, 0.0], "aura_late": ["num", 0.0, 2.0, 0.0], "aura_nojam": ["num", 0.0, 1.0, 0.0],
	"aura_veteran": ["num", 0.0, 0.1, 0.0], "aura_charge": ["num", 0.0, 2.0, 0.0], "aura_rally": ["num", 0.0, 2.0, 0.0],
	"aura_stun": ["num", 0.0, 1.0, 0.0], "aura_light": ["num", 0.0, 1.0, 0.0], "aura_sanct": ["num", 0.0, 0.9, 0.0],
	"aura_rush": ["num", 0.0, 2.0, 0.0], "aura_air": ["num", 0.0, 1.0, 0.0],
	"weaken": ["num", 0.0, 1.0, 0.0], "resist_down": ["num", 0.0, 0.9, 0.0], "hex": ["num", 0.0, 0.9, 0.0],
	"vs_elite": ["num", 0.0, 5.0, 0.0], "vs_controlled": ["num", 0.0, 2.0, 0.0], "fear_spread": ["int", 0, 5, 0],
	"charm_power": ["num", 0.0, 5.0, 0.0],
}
## Support (BoardAuras, BoardFeats) : auras reçues des tourelles de soutien voisines — aura_crit
## (chance de critique), aura_late (dégâts contre un monstre passé à la moitié de la route),
## aura_nojam (ne peut plus être brouillée), aura_veteran (dégâts par monstre tué depuis sa
## construction, plafond VETERAN_CAP), aura_charge (cadence les CHARGE_TIME s après le départ
## d'une vague), aura_rally (dégâts les RALLY_TIME s après une vie perdue), aura_stun (chance
## d'étourdir), aura_light (touche les monstres insensibles à ses coups, à cette part), aura_sanct
## (ralentit les monstres sur le dernier quart de la route), aura_rush (dégâts les RUSH_TIME s après
## le départ d'une vague), aura_air (vise les volants). Coups : weaken (le monstre touché coûte 1
## vie de moins s'il fuit, au moins 1), resist_down (résistances réduites pour toutes les tourelles,
## MARK_DURATION s), hex (capacités des monstres plus lentes à revenir), vs_elite (dégâts contre
## un monstre de vague spéciale), vs_controlled (chances de contrôle en plus sur un monstre déjà
## contrôlé), fear_spread (la peur gagne ce nombre de voisins), charm_power (un charmé frappe plus fort).
## Bâtisseur (BoardFeats) : wall (dégâts en plus par tourelle à lui voisine), keystone (dégâts en
## plus entourée de KEYSTONE de ses tourelles), twin (dégâts en plus à côté d'une tourelle
## identique), crown (dégâts en plus pour sa tourelle la plus chère), plans (portée en plus au
## niveau 5 et plus), buttress (cadence en plus au niveau 6 et plus), masterpiece (sa première
## tourelle au niveau 7 devient un chef-d'œuvre : dégâts en plus).
## Suite (BoardFeats) : slow (ralentissement en plus, part de la vitesse, 1 s au
## moins), dot_duration (durées du poison, de la brûlure et du saignement en plus, en part),
## last_stand (cadence en plus à LAST_STAND vies ou moins), growth (dégâts en plus par vague
## franchie sans fuite dans la partie), harmony (dégâts en plus par élément différent parmi ses
## tourelles voisines), static_charge (tous les STATIC_HITS coups de foudre reçus, le monstre se
## décharge autour : cette part des dégâts), storm (dégâts d'un éclair gratuit toutes les
## STORM_PERIOD s, en part des dégâts du tir), chain_keep (les rebonds perdent moins), vs_armored
## (contre un véhicule ou une armure de 3 et plus), all_targets (vise l'air et le sol), vs_afflicted
## (contre un monstre sous 2 effets ou plus), death_puddle (un monstre mort sous un effet laisse
## une flaque : part de ses PV max par seconde), vs_fast (saignement en plus par point de vitesse),
## vs_wounded (dégâts et saignement en plus sous WOUNDED de PV).
## Effets des talents sur les coups (BoardFeats) : crit_chance (coup critique : dégâts × (2 +
## crit_bonus)), execute (achève un monstre sous cette part de PV, moitié contre un boss),
## pierce (le projectile touche ce nombre de monstres en plus derrière sa cible), ricochet
## (chance de toucher un 2e monstre), streak / streak_cap (+part de dégâts par monstre tué dans la
## vague, plafonnée), mark (le monstre touché subit cette part en plus de toutes les tourelles
## pendant MARK_DURATION), warmup / warmup_cap (+part de cadence par seconde de tir continu,
## plafonnée), frag (un monstre tué projette 3 éclats de cette part des dégâts), knockback (chance
## de repousser d'une demi-case), armor_break (chaque coup retire 1 d'armure, jusqu'à ce nombre),
## kill_splash (un coup qui tue inflige cette part de ses dégâts autour), vs_big (dégâts en plus
## contre un boss ou un gros monstre), reaction (feu sur un ralenti ou gelé : ×(1 + reaction) ;
## foudre sur un brûlé : explosion ; glace sur un brûlé : étourdi), resonance (part des résistances
## aux éléments ignorée), death_* (un monstre qui meurt brûlé, empoisonné ou électrifié transmet
## l'effet à ce nombre de voisins).
const FEATS := ["crit_chance", "crit_bonus", "execute", "pierce", "ricochet", "streak", "streak_cap", "mark",
	"warmup", "warmup_cap", "frag", "knockback", "armor_break", "kill_splash", "vs_big", "reaction", "resonance",
	"death_burn", "death_poison", "death_shock", "slow", "dot_duration", "last_stand", "growth", "harmony",
	"static_charge", "storm", "chain_keep", "vs_armored", "all_targets", "vs_afflicted", "death_puddle", "vs_fast",
	"vs_wounded", "wall", "keystone", "twin", "crown", "plans", "buttress", "masterpiece", "weaken", "resist_down",
	"hex", "vs_elite", "vs_controlled", "fear_spread", "charm_power"]
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
## hp : PV des monstres sur cette carte (une longue route laisse plus de temps pour les abattre).
const MAP := {
	"id": ["id"], "name": ["text", 32], "flyer_speed": ["num", 0.2, 1.0, 1.0],
	"min_players": ["int", 1, 4, 1], "max_players": ["int", 1, 4, 4], "lanes": ["int", 1, 8, 1],
	"tier": ["int", 0, 2, 1], "hp": ["num", 0.5, 4.0, 1.0], "theme": ["id", "prairie"],
}
const MAP_TIERS := ["facile", "moyenne", "difficile"]
## Thèmes de carte : couleurs du sol et dessin du décor (MapTheme).
const THEMES := ["prairie", "tundra", "volcano", "swamp", "necropolis", "canyon", "forest"]

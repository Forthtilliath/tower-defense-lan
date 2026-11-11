class_name TalentSchema
extends RefCounted
## Schéma des classes et des talents (validés par TreeValidator) : branches, talents, effets
## ajoutés aux tourelles (grant) et bonus de classe. Le reste des données : DataSchema.

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
	"loot": ["num", 0.0, 0.2, 0.0], "loan": ["int", 0, 2000, 0], "boss_bounty": ["num", 0.0, 2.0, 0.0],
	"jackpot": ["num", 0.0, 0.1, 0.0], "trophy": ["num", 0.0, 0.1, 0.0], "contract": ["num", 0.0, 10.0, 0.0],
	"rent": ["int", 0, 100, 0], "compound": ["num", 0.0, 0.5, 0.0], "ally_start": ["int", 0, 500, 0],
	"invest": ["num", 0.0, 0.5, 0.0], "team_discount": ["num", 0.0, 0.2, 0.0], "share_interest": ["num", 0.0, 1.0, 0.0],
	"hot_hand": ["int", 0, 50, 0], "early_wave": ["num", 0.0, 2.0, 0.0], "risk": ["num", 0.0, 0.1, 0.0],
	"nerve": ["num", 0.0, 2.0, 0.0], "floors": ["int", 0, 2, 0], "moves": ["int", 0, 3, 0],
	"scrap": ["num", 0.0, 1.0, 0.0], "spare": ["num", 0.0, 0.5, 0.0], "tinker": ["num", 0.0, 1.0, 0.0],
	"team_aura": ["num", 0.0, 0.2, 0.0],
}
## team_aura (Support) : puissance d'aura en plus par allié dans la partie.
## Bâtisseur : floors (étages : niveaux de tourelle en plus, tronc commun seulement), moves
## (tourelles déplacées gratuitement par vague), scrap (prime en plus des véhicules), spare
## (vendre une tourelle renforce d'autant la prochaine construite), tinker (cadence en plus d'une
## tourelle déplacée pendant TINKER_TIME s).
## Économie des talents (MatchEconomy) : loot (chance qu'un monstre tué rapporte LOOT_GOLD de
## plus), loan (prêt au départ, remboursé avec LOAN_RATE à la vague LOAN_WAVE), boss_bounty (prime
## en plus sur les gros monstres), jackpot (chance de prime ×JACKPOT), trophy (+part de primes par
## gros monstre tué dans la partie), contract (le premier monstre tué de chaque vague rapporte ×(1 +
## contract)), rent (or fixe par vague), compound (part de l'or investi dans ses tourelles comptée
## dans ses intérêts), ally_start (or de départ pour chaque allié), invest (part d'un don rendue
## INVEST_WAVES vagues plus tard), team_discount (améliorations moins chères pour les alliés),
## share_interest (part de ses intérêts versée aussi à chaque allié), hot_hand (or par vague
## franchie sans fuite d'affilée), early_wave (part de l'or de la vague en plus si lancée en
## avance), risk (+part de primes par vie perdue, plafond RISK_CAP), nerve (primes en plus à
## NERVE_LIVES vies ou moins).
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
	"vs_slowed": ["num", 0.0, 5.0, 0.0], "ramp_max": ["num", 0.0, 5.0, 0.0], "slow_duration": ["num", 0.0, 5.0, 0.0],
	"heal_block_duration": ["num", 0.0, 10.0, 0.0],
	"wall": ["num", 0.0, 0.5, 0.0], "keystone": ["num", 0.0, 1.0, 0.0], "twin": ["num", 0.0, 1.0, 0.0],
	"crown": ["num", 0.0, 1.0, 0.0], "plans": ["num", 0.0, 1.0, 0.0], "buttress": ["num", 0.0, 1.0, 0.0],
	"masterpiece": ["num", 0.0, 3.0, 0.0], "aura_rate": ["num", 0.0, 1.0, 0.0], "aura_damage": ["num", 0.0, 1.0, 0.0],
	"aura_range": ["num", 0.0, 1.0, 0.0], "aura_cc": ["num", 0.0, 1.0, 0.0], "aura_discount": ["num", 0.0, 0.2, 0.0],
	"fear_duration": ["num", 0.0, 5.0, 0.0], "charm_duration": ["num", 0.0, 5.0, 0.0],
	"aura_crit": ["num", 0.0, 1.0, 0.0], "aura_late": ["num", 0.0, 2.0, 0.0], "aura_nojam": ["num", 0.0, 1.0, 0.0],
	"aura_veteran": ["num", 0.0, 0.1, 0.0], "aura_charge": ["num", 0.0, 2.0, 0.0], "aura_rally": ["num", 0.0, 2.0, 0.0],
	"aura_stun": ["num", 0.0, 1.0, 0.0], "aura_light": ["num", 0.0, 1.0, 0.0], "aura_sanct": ["num", 0.0, 0.9, 0.0],
	"aura_rush": ["num", 0.0, 2.0, 0.0], "aura_air": ["num", 0.0, 1.0, 0.0],
	"weaken": ["num", 0.0, 1.0, 0.0], "resist_down": ["num", 0.0, 0.9, 0.0], "hex": ["num", 0.0, 0.9, 0.0],
	"vs_elite": ["num", 0.0, 5.0, 0.0], "vs_controlled": ["num", 0.0, 2.0, 0.0], "fear_spread": ["int", 0, 5, 0],
	"charm_power": ["num", 0.0, 5.0, 0.0], "fear_chance": ["num", 0.0, 1.0, 0.0], "charm_chance": ["num", 0.0, 1.0, 0.0],
}
## Plafonds des statistiques après les effets ajoutés (une part au-delà de 1 n'a pas de sens).
const GRANT_CAPS := {"armor_pierce": 1.0, "stun_chance": 1.0, "shred": 0.9, "heal_block": 1.0, "crit_chance": 1.0,
	"execute": 0.5, "ricochet": 1.0, "knockback": 1.0, "resonance": 1.0, "mark": 1.0, "slow": 0.9, "all_targets": 1,
	"chain_keep": 0.2}
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

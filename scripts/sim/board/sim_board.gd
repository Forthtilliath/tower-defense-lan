class_name SimBoard
extends RefCounted
## Plateau simulé par l'hôte : file d'apparition, déplacements, morts et état diffusé.
## Le combat (tirs, projectiles, effets) est dans BoardCombat.
## En coopération il n'y a qu'un plateau partagé ; en versus, un par joueur.

## RING : éclat d'explosion (rayon) ; BOLT : éclair ; CONE : souffle de flammes (jusqu'au point
## visé) ; BEAM : rayon ardent ; WAVE : onde autour d'une tourelle (rayon, teinte = index de
## la tourelle) ; SPREAD : contagion du poison d'un monstre à l'autre ; BLINK : bond d'un
## monstre ; JAM : onde de brouillage autour d'un monstre (rayon).
enum Fx { RING, BOLT, CONE, BEAM, WAVE, SPREAD, BLINK, JAM }

const FX_DURATION := 0.35
const MAX_QUEUE := 400
const MAX_MONSTERS := 600
## Part du supplément de prime d'un Comptoir versée en plus à son propriétaire.
const COUNTER_CUT := 0.25

var data: GameData
var map: MapDef
var lives := 20
var alive := true
var reward_mult := 1.0
## Armure ajoutée à chaque monstre (difficulté).
var armor_bonus := 0.0
## Chemins où les monstres apparaissent (vide : tous) : sur une carte à plusieurs couloirs, un par joueur.
var open_paths: Array[int] = []
var monsters: Array[SimMonster] = []
var towers := {}  # index de case -> SimTower
var projectiles: Array[SimProjectile] = []
## Nappes au sol (feu, nuage toxique), gérées par BoardPatches.
var patches: Array[Dictionary] = []
## Cases changées par un Terrassier (BoardTerrain) : index -> [type de case, case spéciale].
var edits := {}
var clock := 0.0
## Hasard des contrôles (chances) : graine fixe, pour des parties et des tests reproductibles.
var rng := RandomNumberGenerator.new()
var _queue: Array[Dictionary] = []  # {time, type, hp_mult, wave (n° de vague, -1 : envoi), mod}
var _fx: Array[Dictionary] = []  # {kind, pos, to, radius, tint, ttl}
var _born: Array[SimMonster] = []  # nés pendant le tick (division), ajoutés à la fin
var _by_id := {}
var _next_id := 1
var _spawn_turn := 0


func _init(p_data: GameData, p_map: MapDef, p_lives: int, p_reward_mult := 1.0) -> void:
	data = p_data
	map = p_map.clone()  # copie propre au plateau : le Terrassier peut la modifier
	lives = p_lives
	reward_mult = p_reward_mult
	rng.seed = 20211109


## Programme les monstres d'une vague, qui commencent à arriver tout de suite (une vague appelée
## en avance s'ajoute à celle en cours au lieu d'attendre sa fin).
## count_mult multiplie le nombre de monstres et resserre leur espacement d'autant.
## Une vague spéciale (champ « modifier ») change aussi leur nombre, leurs PV et leurs capacités.
func queue_wave(wave: Dictionary, hp_mult: float, count_mult := 1.0, number := 0) -> void:
	var mod: Dictionary = data.modifiers.get(wave.get("modifier", ""), {})
	hp_mult *= float(mod.get("hp", 1.0))
	var spacing := maxf(count_mult, 1.0)
	count_mult *= float(mod.get("count", 1.0))
	var t := clock + 0.5
	var paths := MapSpawns.wave_paths(map, number)  # entrées ouvertes à cette vague (vide : toutes)
	for group in wave["groups"]:
		var count := maxi(1, roundi(int(group["count"]) * count_mult))
		var interval := float(group["interval"]) / spacing
		for i in count:
			_queue.append({"time": t, "type": group["monster"], "hp_mult": hp_mult, "wave": number, "mod": mod, "paths": paths})
			t += interval
		t += 1.0


## Ajoute un monstre envoyé par un adversaire (mode versus).
func queue_monster(type: String, hp_mult: float) -> bool:
	if _queue.size() >= MAX_QUEUE:
		return false
	_queue.append({"time": clock + 0.3, "type": type, "hp_mult": hp_mult, "wave": -1, "mod": {}})
	return true


## Vrai tant que des monstres de vague restent à faire apparaître.
func spawns_pending() -> bool:
	return pending_waves() > 0


## Nombre de vagues dont des monstres restent à faire apparaître.
func pending_waves() -> int:
	var seen := {}
	for e in _queue:
		if e["wave"] >= 0:
			seen[e["wave"]] = true
	return seen.size()


func is_clear() -> bool:
	return _queue.is_empty() and monsters.is_empty() and _born.is_empty()


func can_build(cell: int) -> bool:
	return alive and map.is_buildable(cell) and not towers.has(cell)


func add_tower(cell: int, type: String, owner: int, cost: int, kit: PlayerKit = null) -> SimTower:
	var t := SimTower.new()
	t.cell = cell
	t.type = type
	t.owner = owner
	t.invested = cost
	t.center = map.cell_center(cell)
	t.special = map.special_at(cell)
	t.kit = kit
	t.support = data.towers[type]["support"]
	towers[cell] = t
	refresh_stats(t)
	return t


## Statistiques après construction ou amélioration ; les auras du plateau sont recalculées.
func refresh_stats(t: SimTower) -> void:
	t.stats = data.tower_stats(t.type, t.level, t.special, t.kit)
	BoardAuras.refresh(self)


func remove_tower(cell: int) -> void:
	towers.erase(cell)
	BoardAuras.refresh(self)


## Plateau perdu ou abandonné : plus rien n'y bouge.
func eliminate() -> void:
	alive = false
	_queue.clear()
	projectiles.clear()
	patches.clear()
	monsters.clear()
	_born.clear()
	_by_id.clear()


## Avance la simulation de dt secondes.
## Renvoie les parts de primes à créditer : [[id joueur, or], ...]
func step(dt: float) -> Array:
	var rewards := []
	if not alive:
		return rewards
	clock += dt
	_spawn_due()
	_move_monsters(dt)
	if lives <= 0:
		eliminate()
		return rewards
	MonsterAbilities.update(self, dt)
	MonsterExtras.update(self, dt)
	MonsterEffects.update(self, dt, rewards)
	BoardPatches.update(self, dt, rewards)
	BoardCombat.fire_towers(self, dt, rewards)
	BoardCombat.move_projectiles(self, dt, rewards)
	_remove_dead()
	_age_fx(dt)
	return rewards


## Mort d'un monstre : prime partagée selon la contribution de chacun (entière au tueur si
## personne n'a contribué), majorée s'il meurt près d'un Comptoir (dont le propriétaire touche
## en plus une part du supplément), et division éventuelle en petits monstres.
func kill(m: SimMonster, killer: int, rewards: Array) -> void:
	MonsterExtras.on_death(self, m)  # tombe (relève du nécromancien)
	var counter := BoardAuras.best_at(self, m.pos, "aura_bounty")
	var gold := m.gold
	if float(counter[0]) > 0.0 and m.gold > 0:
		gold = roundi(m.gold * (1.0 + float(counter[0])))
		rewards.append([counter[1], maxi(1, roundi(m.gold * float(counter[0]) * COUNTER_CUT))])
	for share in Bounty.split(gold, m.contrib, killer):  # [joueur, or, gros monstre ?, véhicule ?] (talents)
		rewards.append(share + [BoardFeats.is_big(m), m.mechanical])
	for i in m.split_count:
		if monsters.size() + _born.size() >= MAX_MONSTERS:
			break
		_born.append(spawn(m.split_into, m.hp_mult, m.path, maxf(0.0, m.progress - 0.25 * i), false, m.modifier))


func spawn(type: String, hp_mult: float, path := -1, progress := 0.0, now := true, mod := {}) -> SimMonster:
	var def: Dictionary = data.monsters[type]
	var m := SimMonster.new()
	m.id = new_id()
	m.type = type
	m.type_index = data.monster_order.find(type)
	m.setup(def, hp_mult, reward_mult, mod)
	m.armor += armor_bonus
	if m.flying:
		m.speed *= map.flyer_speed
	if path < 0:
		path = open_paths[_spawn_turn % open_paths.size()] if not open_paths.is_empty() else _spawn_turn % map.start_count()
		_spawn_turn += 1
	m.path = path
	m.length = map.path_length(m.path, m.flying)
	m.progress = minf(progress, m.length * 0.99)
	m.pos = map.position_at(m.path, m.progress, m.flying)
	_by_id[m.id] = m
	if now:
		monsters.append(m)
	return m


func monster_by_id(monster_id: int) -> SimMonster:
	return _by_id.get(monster_id)


func add_fx(kind: int, pos: Vector2, to := Vector2.ZERO, radius := 0.0, tint := 0) -> void:
	if _fx.size() < 200:
		_fx.append({"kind": kind, "pos": pos, "to": to, "radius": radius, "tint": tint, "ttl": FX_DURATION})


func new_id() -> int:
	_next_id += 1
	return _next_id


func snapshot() -> Dictionary:
	return BoardSnapshot.of(self)


## Effet rond (rayon et teinte), les autres vont d'un point à un autre.
static func is_round_fx(kind: int) -> bool:
	return kind == Fx.RING or kind == Fx.WAVE or kind == Fx.JAM


func _spawn_due() -> void:
	var i := 0
	while i < _queue.size():
		if _queue[i]["time"] <= clock and monsters.size() < MAX_MONSTERS:
			var e: Dictionary = _queue[i]
			var paths: Array = e.get("paths", [])
			var path := -1
			if not paths.is_empty():  # entrées de la vague, à tour de rôle
				path = paths[_spawn_turn % paths.size()]
				_spawn_turn += 1
			spawn(e["type"], e["hp_mult"], path, 0.0, true, e["mod"])
			_queue.remove_at(i)
		else:
			i += 1


func _move_monsters(dt: float) -> void:
	for m in monsters:
		if not m.is_alive():
			continue
		m.move(dt)
		if m.reached_end():
			m.hp = 0.0  # le monstre quitte la carte, sans prime
			lives = maxi(0, lives - BoardSupport.leak_damage(m) - int(get_meta("leak_extra", 0)))  # Va-tout : +1
		else:
			m.pos = map.position_at(m.path, m.progress, m.flying)


func _remove_dead() -> void:
	var keep: Array[SimMonster] = []
	for m in monsters:
		if m.is_alive():
			keep.append(m)
		else:
			_by_id.erase(m.id)
	keep.append_array(_born)
	_born.clear()
	monsters = keep


func _age_fx(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for f in _fx:
		f["ttl"] -= dt
		if f["ttl"] > 0.0:
			keep.append(f)
	_fx = keep

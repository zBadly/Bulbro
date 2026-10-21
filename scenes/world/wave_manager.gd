class_name WaveManager
extends Node
## Steuert die 20 Wellen: Dauer, Gruppen-Spawns mit rotem X, Mindestabstand, Gegnerlimit, Wellenende.

signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal run_won

const CONFIG: WaveConfig = preload("res://data/config/wave_config.tres")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const WAVE_CATEGORY: String = "waves"
const ENEMY_CATEGORY: String = "enemies"
const SPECIAL_ELITE: String = "elite"
const SPECIAL_HORDE: String = "horde"
## Elites auf den frühen Sonderwellen (11/12) haben nur 75 % HP; ebenso beide Bosse bei Spannung 5.
const REDUCED_HP_WAVES: Array[int] = [11, 12]
const REDUCED_HP_FACTOR: float = 0.75
## Hordewellen: Gruppengröße x2.
const HORDE_FACTOR: float = 2.0
const SUMMON_RADIUS: float = 60.0

enum State { IDLE, WAVE, INTERMISSION, FINISHED }

## Ein angekündigter Spawn: rotes X liegt, Gegner erscheint nach Ablauf der Zeit.
class PendingSpawn:
	var data: EnemyData
	var position: Vector2
	var time_left: float
	var marker: SpawnMarker

var player: Player
var arena_rect: Rect2
## Elternknoten der Gegner (Y-sortiert).
var enemy_container: Node2D
var state: State = State.IDLE
var time_left: float = 0.0

var _waves: Array[WaveData] = []
var _wave: WaveData
var _wave_time: float = 0.0
var _next_group_time: Array[float] = []
var _pending: Array[PendingSpawn] = []
var _active: Array[Enemy] = []
var _enemy_pools: Dictionary[StringName, ObjectPool] = {}
## Elites und Bosse der aktuellen Welle.
var _bosses: Array[Enemy] = []


func start(p_player: Player, rect: Rect2, container: Node2D) -> void:
	_setup(p_player, rect, container)
	_roll_special_waves()
	start_wave(1)


## Fortgesetzter Run: steht nach Welle `wave_number` (Shop); die nächste Welle startet mit start_next_wave().
func resume_at(p_player: Player, rect: Rect2, container: Node2D, wave_number: int) -> void:
	_setup(p_player, rect, container)
	_wave = _waves[clampi(wave_number, 1, _waves.size()) - 1]
	state = State.INTERMISSION


func _setup(p_player: Player, rect: Rect2, container: Node2D) -> void:
	player = p_player
	arena_rect = rect
	enemy_container = container
	_waves.clear()
	for res: Resource in DataRegistry.get_all(WAVE_CATEGORY):
		_waves.append(res as WaveData)
	_waves.sort_custom(func(a: WaveData, b: WaveData) -> bool: return a.wave_number < b.wave_number)


func get_wave_number() -> int:
	return _wave.wave_number if _wave != null else 0


func get_wave_count() -> int:
	return _waves.size()


func active_enemy_count() -> int:
	return _active.size()


## Debug: aktuelle Welle sofort abbrechen (ohne Drops) und Welle `number` starten.
func jump_to_wave(number: int) -> void:
	for pending: PendingSpawn in _pending:
		pending.marker.release()
	_pending.clear()
	for enemy: Enemy in _active.duplicate():
		enemy.despawn()
	var projectile_pool: ObjectPool = Pools.get_pool(get_tree(), Pools.ENEMY_PROJECTILES)
	if projectile_pool != null:
		projectile_pool.release_all()
	start_wave(clampi(number, 1, _waves.size()))


## Nach Wellenende, Level-ups und Shop aufgerufen.
func start_next_wave() -> void:
	start_wave(get_wave_number() + 1)


func start_wave(number: int) -> void:
	_wave = _waves[number - 1]
	GameState.current_wave = number
	time_left = _wave.duration
	_wave_time = 0.0
	_next_group_time.clear()
	for group: SpawnGroupData in _wave.groups:
		_next_group_time.append(group.start_time)
	state = State.WAVE
	_bosses.clear()
	Events.wave_started.emit(number)
	wave_started.emit(number)
	if _wave.is_boss:
		_spawn_bosses()
	elif GameState.special_waves.get(number, "") == SPECIAL_ELITE:
		_spawn_elite()


func _physics_process(delta: float) -> void:
	match state:
		State.WAVE:
			if player.is_dead:
				return
			_wave_time += delta
			time_left = maxf(0.0, _wave.duration - _wave_time)
			if not _wave.is_boss or time_left > 0.0:
				_update_groups()
			_update_pending(delta)
			# Bosswelle endet erst mit dem Tod aller Bosse, normale Wellen mit dem Timer.
			if _wave.is_boss:
				if _bosses_defeated():
					_end_wave()
			elif time_left <= 0.0:
				_end_wave()


func _update_groups() -> void:
	for i in _wave.groups.size():
		var group: SpawnGroupData = _wave.groups[i]
		if group.end_time > 0.0 and _wave_time > group.end_time:
			continue
		if group.min_difficulty > _difficulty_level():
			continue
		while _wave_time >= _next_group_time[i]:
			_queue_group(group)
			_next_group_time[i] += group.interval


func _update_pending(delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var pending: PendingSpawn = _pending[i]
		pending.time_left -= delta
		if pending.time_left <= 0.0:
			pending.marker.release()
			_pending.remove_at(i)
			spawn_enemy(pending.data, pending.position)


func _queue_group(group: SpawnGroupData) -> void:
	var rng: RandomNumberGenerator = GameState.rng
	var count: int = _scaled_count(rng.randi_range(group.group_min, group.group_max), rng)
	if GameState.special_waves.get(get_wave_number(), "") == SPECIAL_HORDE:
		count = roundi(count * HORDE_FACTOR)
	var center: Vector2 = pick_spawn_point()
	var marker_pool: ObjectPool = Pools.get_pool(get_tree(), Pools.SPAWN_MARKERS)
	for i in count:
		var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf() * CONFIG.group_radius
		var pending: PendingSpawn = PendingSpawn.new()
		pending.data = group.enemy
		pending.position = _keep_distance(_clamp_to_spawn_area(center + offset))
		pending.time_left = CONFIG.spawn_warning_time
		pending.marker = marker_pool.acquire() as SpawnMarker
		pending.marker.show_at(pending.position)
		_pending.append(pending)


## Erzeugt sofort einen Gegner. Beim Erreichen des Limits verschwindet vorher ein zufälliger normaler Gegner.
func spawn_enemy(data: EnemyData, spawn_position: Vector2, hp_multiplier: float = 1.0) -> Enemy:
	if _active.size() >= CONFIG.max_enemies:
		_despawn_random()
	var enemy: Enemy = _get_pool(data).acquire() as Enemy
	enemy.hp_multiplier = hp_multiplier
	enemy.activate(get_wave_number(), spawn_position, player, arena_rect, GameState.rng)
	_active.append(enemy)
	return enemy


func _despawn_random() -> void:
	var candidates: Array[Enemy] = _active.filter(func(e: Enemy) -> bool: return e.data.despawnable)
	if candidates.is_empty():
		return
	candidates[GameState.rng.randi_range(0, candidates.size() - 1)].despawn()


func _end_wave() -> void:
	for pending: PendingSpawn in _pending:
		pending.marker.release()
	_pending.clear()
	for enemy: Enemy in _active.duplicate():
		enemy.despawn(true)
	var projectile_pool: ObjectPool = Pools.get_pool(get_tree(), Pools.ENEMY_PROJECTILES)
	if projectile_pool != null:
		projectile_pool.release_all()
	var number: int = _wave.wave_number
	Events.wave_ended.emit(number)
	wave_ended.emit(number)
	if number >= _waves.size():
		state = State.FINISHED
		run_won.emit()
	else:
		state = State.INTERMISSION


func _get_pool(data: EnemyData) -> ObjectPool:
	if _enemy_pools.has(data.id):
		return _enemy_pools[data.id]
	var pool: ObjectPool = ObjectPool.new()
	pool.name = "Enemies_" + String(data.id)
	pool.scene = ENEMY_SCENE
	pool.container = enemy_container
	pool.on_create = func(node: Node) -> void:
		var enemy: Enemy = node as Enemy
		enemy.setup(data)
		enemy.died.connect(_on_enemy_died)
		enemy.summon_requested.connect(_on_summon_requested)
	add_child(pool)
	pool.prewarm(CONFIG.enemy_pool_size)
	_enemy_pools[data.id] = pool
	return pool


func _on_enemy_died(enemy: Enemy) -> void:
	_active.erase(enemy)


func _on_summon_requested(data: EnemyData, count: int, origin: Vector2) -> void:
	if state != State.WAVE:
		return
	var rng: RandomNumberGenerator = GameState.rng
	for i in count:
		var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.0) * SUMMON_RADIUS
		spawn_enemy(data, _clamp_to_spawn_area(origin + offset))


func _difficulty_level() -> int:
	return GameState.difficulty.level if GameState.difficulty != null else 0


## Bestimmt nach Spannung die Elite-/Hordewellen dieses Runs (GDD 2): je Wellenpaar eine zufällige Welle.
func _roll_special_waves() -> void:
	GameState.special_waves.clear()
	var difficulty: DifficultyData = GameState.difficulty
	if difficulty == null:
		return
	var rng: RandomNumberGenerator = GameState.rng
	var pairs: Array[Vector2i] = difficulty.special_wave_pairs
	for i in pairs.size():
		var wave_number: int = pairs[i].x if rng.randf() < 0.5 else pairs[i].y
		var is_last: bool = i == pairs.size() - 1
		var elite: bool = (is_last and difficulty.last_special_is_elite) or rng.randf() >= difficulty.horde_chance
		GameState.special_waves[wave_number] = SPECIAL_ELITE if elite else SPECIAL_HORDE


func _enemies_where(predicate: Callable) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for res: Resource in DataRegistry.get_all(ENEMY_CATEGORY):
		if predicate.call(res as EnemyData):
			result.append(res as EnemyData)
	result.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return String(a.id) < String(b.id))
	return result


func _spawn_elite() -> void:
	var elites: Array[EnemyData] = _enemies_where(func(e: EnemyData) -> bool: return e.is_elite)
	if elites.is_empty():
		return
	var data: EnemyData = elites[GameState.rng.randi_range(0, elites.size() - 1)]
	var factor: float = REDUCED_HP_FACTOR if get_wave_number() in REDUCED_HP_WAVES else 1.0
	_bosses.append(spawn_enemy(data, pick_spawn_point(), factor))


## Welle 20: ein zufälliger Boss, bei Spannung 5 beide mit reduzierten HP.
func _spawn_bosses() -> void:
	var bosses: Array[EnemyData] = _enemies_where(func(e: EnemyData) -> bool: return e.is_boss)
	if bosses.is_empty():
		return
	var difficulty: DifficultyData = GameState.difficulty
	if difficulty != null and difficulty.double_boss:
		for data: EnemyData in bosses:
			_bosses.append(spawn_enemy(data, pick_spawn_point(), REDUCED_HP_FACTOR))
	else:
		_bosses.append(spawn_enemy(bosses[GameState.rng.randi_range(0, bosses.size() - 1)], pick_spawn_point()))


func _bosses_defeated() -> bool:
	for boss: Enemy in _bosses:
		if boss.is_alive():
			return false
	return true


## Gegner-Stat (Halogenstrahler +25 %): Gruppengröße skalieren, Rest per Zufall aufrunden.
func _scaled_count(count: int, rng: RandomNumberGenerator) -> int:
	var scaled: float = count * maxf(0.0, 1.0 + player.stats.get_stat(Stats.ENEMIES_PCT) / CombatMath.PERCENT)
	var whole: int = floori(scaled)
	return whole + (1 if rng.randf() < scaled - whole else 0)


func pick_spawn_point() -> Vector2:
	var rng: RandomNumberGenerator = GameState.rng
	var area: Rect2 = arena_rect.grow(-CONFIG.spawn_margin)
	for i in CONFIG.spawn_position_attempts:
		var point: Vector2 = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if point.distance_to(player.global_position) >= CONFIG.min_player_distance:
			return point
	return _keep_distance(area.get_center())


func _keep_distance(point: Vector2) -> Vector2:
	var from_player: Vector2 = point - player.global_position
	if from_player.length() >= CONFIG.min_player_distance:
		return point
	var direction: Vector2 = from_player.normalized() if not from_player.is_zero_approx() else Vector2.RIGHT
	var pushed: Vector2 = _clamp_to_spawn_area(player.global_position + direction * CONFIG.min_player_distance)
	if pushed.distance_to(player.global_position) < CONFIG.min_player_distance:
		pushed = _clamp_to_spawn_area(player.global_position - direction * CONFIG.min_player_distance)
	return pushed


func _clamp_to_spawn_area(point: Vector2) -> Vector2:
	var area: Rect2 = arena_rect.grow(-CONFIG.spawn_margin)
	return point.clamp(area.position, area.end)

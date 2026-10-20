class_name WaveManager
extends Node
## Steuert die 20 Wellen: Dauer, Gruppen-Spawns mit rotem X, Mindestabstand, Gegnerlimit, Wellenende.

signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal run_won

const CONFIG: WaveConfig = preload("res://data/config/wave_config.tres")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const WAVE_CATEGORY: String = "waves"

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
var _intermission_left: float = 0.0


func start(p_player: Player, rect: Rect2, container: Node2D) -> void:
	player = p_player
	arena_rect = rect
	enemy_container = container
	_waves.clear()
	for res: Resource in DataRegistry.get_all(WAVE_CATEGORY):
		_waves.append(res as WaveData)
	_waves.sort_custom(func(a: WaveData, b: WaveData) -> bool: return a.wave_number < b.wave_number)
	start_wave(1)


func get_wave_number() -> int:
	return _wave.wave_number if _wave != null else 0


func get_wave_count() -> int:
	return _waves.size()


func active_enemy_count() -> int:
	return _active.size()


func start_wave(number: int) -> void:
	_wave = _waves[number - 1]
	GameState.current_wave = number
	time_left = _wave.duration
	_wave_time = 0.0
	_next_group_time.clear()
	for group: SpawnGroupData in _wave.groups:
		_next_group_time.append(group.start_time)
	state = State.WAVE
	Events.wave_started.emit(number)
	wave_started.emit(number)


func _physics_process(delta: float) -> void:
	match state:
		State.WAVE:
			if player.is_dead:
				return
			_wave_time += delta
			time_left = maxf(0.0, _wave.duration - _wave_time)
			_update_groups()
			_update_pending(delta)
			if time_left <= 0.0:
				_end_wave()
		State.INTERMISSION:
			_intermission_left -= delta
			if _intermission_left <= 0.0:
				start_wave(_wave.wave_number + 1)


func _update_groups() -> void:
	for i in _wave.groups.size():
		var group: SpawnGroupData = _wave.groups[i]
		if group.end_time > 0.0 and _wave_time > group.end_time:
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
	var count: int = rng.randi_range(group.group_min, group.group_max)
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
func spawn_enemy(data: EnemyData, spawn_position: Vector2) -> Enemy:
	if _active.size() >= CONFIG.max_enemies:
		_despawn_random()
	var enemy: Enemy = _get_pool(data).acquire() as Enemy
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
		enemy.despawn()
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
		_intermission_left = CONFIG.intermission_time


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
	add_child(pool)
	pool.prewarm(CONFIG.enemy_pool_size)
	_enemy_pools[data.id] = pool
	return pool


func _on_enemy_died(enemy: Enemy) -> void:
	_active.erase(enemy)


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

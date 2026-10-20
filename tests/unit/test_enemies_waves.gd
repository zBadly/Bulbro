extends GutTest
## Tests für Gegnerwerte, Wellendaten und WaveManager-Regeln (GDD 2 und 11).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const MARKER_SCENE: PackedScene = preload("res://scenes/world/spawn_marker.tscn")
const WAVES: WaveConfig = preload("res://data/config/wave_config.tres")

var _player: Player
var _manager: WaveManager
var _container: Node2D
var _killed: Array[EnemyData] = []


func before_each() -> void:
	_killed.clear()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2.ZERO
	_container = Node2D.new()
	add_child_autofree(_container)
	var markers: ObjectPool = ObjectPool.new()
	markers.scene = MARKER_SCENE
	markers.group_name = Pools.SPAWN_MARKERS
	add_child_autofree(markers)
	_manager = WaveManager.new()
	add_child_autofree(_manager)
	Events.enemy_killed.connect(_on_killed)


func after_each() -> void:
	Events.enemy_killed.disconnect(_on_killed)


func _on_killed(data: EnemyData, _pos: Vector2, _info: DamageInfo) -> void:
	_killed.append(data)


func _start() -> void:
	_manager.start(_player, Rect2(-1000, -650, 2000, 1300), _container)


func test_enemy_stats_grow_linearly_after_wave_one() -> void:
	var shade: EnemyData = load("res://data/enemies/schattenling.tres")
	assert_eq(shade.hp_for_wave(1), 3.0)
	assert_eq(shade.hp_for_wave(5), 3.0 + 4 * 2.0)
	assert_almost_eq(shade.damage_for_wave(11), 1.0 + 10 * 0.6, 0.001)


func test_wave_durations_follow_gdd() -> void:
	var waves: Array[Resource] = DataRegistry.get_all("waves")
	assert_eq(waves.size(), 20)
	var by_number: Dictionary[int, float] = {}
	for res: Resource in waves:
		by_number[(res as WaveData).wave_number] = (res as WaveData).duration
	assert_eq(by_number[1], 20.0)
	assert_eq(by_number[2], 25.0)
	assert_eq(by_number[9], 60.0)
	assert_eq(by_number[15], 60.0)
	assert_eq(by_number[20], 90.0)


func test_new_enemy_types_appear_from_their_wave() -> void:
	var wave_1: WaveData = load("res://data/waves/wave_01.tres")
	var wave_4: WaveData = load("res://data/waves/wave_04.tres")
	assert_eq(wave_1.groups.size(), 1, "Welle 1 nur Schattenlinge")
	assert_eq(wave_4.groups.size(), 4, "ab Welle 4 alle vier Typen")


func test_spawns_keep_min_distance_to_player() -> void:
	_start()
	for i in 50:
		var point: Vector2 = _manager.call("_keep_distance", _manager.pick_spawn_point())
		assert_true(point.distance_to(_player.global_position) >= WAVES.min_player_distance - 0.01)


func test_enemy_limit_despawns_without_drop() -> void:
	_start()
	var shade: EnemyData = load("res://data/enemies/schattenling.tres")
	for i in WAVES.max_enemies + 5:
		_manager.spawn_enemy(shade, Vector2(500, 300))
	assert_eq(_manager.active_enemy_count(), WAVES.max_enemies)
	assert_eq(_killed.size(), 0, "Despawn erzeugt keine Drops")


func test_killing_enemy_emits_drop_event() -> void:
	_start()
	var shade: EnemyData = load("res://data/enemies/schattenling.tres")
	var enemy: Enemy = _manager.spawn_enemy(shade, Vector2(500, 300))
	enemy.take_damage(DamageInfo.create(999, false, 0.0, null))
	assert_false(enemy.is_alive())
	assert_eq(_killed.size(), 1)
	assert_eq(_manager.active_enemy_count(), 0)


func test_groups_are_announced_by_markers_before_spawning() -> void:
	_start()
	await wait_seconds(1.0)
	assert_eq(_manager.active_enemy_count(), 0, "nach 1 s erst rote X")
	await wait_seconds(1.0)
	assert_gt(_manager.active_enemy_count(), 0, "nach Warnzeit sind Gegner da")


func test_wave_end_clears_enemies() -> void:
	_start()
	_manager.spawn_enemy(load("res://data/enemies/schattenling.tres"), Vector2(500, 300))
	_manager.call("_end_wave")
	assert_eq(_manager.active_enemy_count(), 0)
	assert_eq(_manager.state, WaveManager.State.INTERMISSION)

extends GutTest
## Tests für neue Gegnerverhalten, Phasen, Angriffsmuster, Sonderwellen und Bosswelle (GDD 2 und 11).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const MARKER_SCENE: PackedScene = preload("res://scenes/world/spawn_marker.tscn")
const ENEMY_PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/enemy_projectile.tscn")
const ARENA_RECT: Rect2 = Rect2(-1000, -650, 2000, 1300)

var _player: Player
var _manager: WaveManager
var _projectiles: ObjectPool


func before_each() -> void:
	GameState.difficulty = null
	GameState.start_run(13)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.debug_invulnerable = true
	var container: Node2D = Node2D.new()
	add_child_autofree(container)
	for pair: Array in [[MARKER_SCENE, Pools.SPAWN_MARKERS], [ENEMY_PROJECTILE_SCENE, Pools.ENEMY_PROJECTILES]]:
		var pool: ObjectPool = ObjectPool.new()
		pool.scene = pair[0]
		pool.group_name = pair[1]
		add_child_autofree(pool)
		if pair[1] == Pools.ENEMY_PROJECTILES:
			_projectiles = pool
	_manager = WaveManager.new()
	add_child_autofree(_manager)
	_manager.start(_player, ARENA_RECT, container)


func after_each() -> void:
	GameState.difficulty = null


func _enemy(id: String, at: Vector2 = Vector2(500, 300), hp_multiplier: float = 1.0) -> Enemy:
	return _manager.spawn_enemy(load("res://data/enemies/%s.tres" % id), at, hp_multiplier)


func _hit(enemy: Enemy, amount: int) -> void:
	enemy.take_damage(DamageInfo.create(amount, false, 0.0, null))


func test_all_enemy_types_exist() -> void:
	var elites: int = 0
	var bosses: int = 0
	for res: Resource in DataRegistry.get_all("enemies"):
		var e: EnemyData = res as EnemyData
		elites += 1 if e.is_elite else 0
		bosses += 1 if e.is_boss else 0
		if e.is_elite or e.is_boss:
			assert_false(e.despawnable, String(e.id))
	assert_eq(DataRegistry.get_all("enemies").size(), 17)
	assert_eq(elites, 3)
	assert_eq(bosses, 2)


func test_elite_hp_and_reduced_early_hp() -> void:
	GameState.current_wave = 11
	_manager.start_wave(11)
	var golem: Enemy = _enemy("kolbengolem", Vector2(500, 300), WaveManager.REDUCED_HP_FACTOR)
	assert_almost_eq(golem.max_hp, (1.0 + 750.0 * 10) * 0.75, 0.01)


func test_phase_changes_at_hp_threshold() -> void:
	_manager.start_wave(11)
	var golem: Enemy = _enemy("kolbengolem")
	var behavior: PhasedBehavior = golem.get_children().filter(func(c: Node) -> bool: return c is PhasedBehavior)[0]
	assert_eq(behavior.phase_index, 0)
	_hit(golem, roundi(golem.max_hp * 0.45))
	await wait_physics_frames(2)
	assert_eq(behavior.phase_index, 1, "unter 60 % HP")


func test_phase_changes_after_time() -> void:
	var weaver: Enemy = _enemy("schattenweber")
	var behavior: PhasedBehavior = weaver.get_children().filter(func(c: Node) -> bool: return c is PhasedBehavior)[0]
	behavior.set("_phase_time", 24.9)
	await wait_physics_frames(10)
	assert_eq(behavior.phase_index, 1, "nach 25 s")


func test_radial_burst_fires_ring() -> void:
	var golem: Enemy = _enemy("kolbengolem")
	var burst: RadialBurstAttack = RadialBurstAttack.new()
	burst.count = 8
	burst.projectile_speed = 100.0
	burst.projectile_range = 300.0
	burst.projectile_texture = load("res://art/fx/boss_orb.svg")
	var before: int = _projectiles.active_count()
	burst.execute(golem, 0)
	assert_eq(_projectiles.active_count() - before, 8)


func test_zone_attack_detonates_after_warning() -> void:
	var boss: Enemy = _enemy("finsternis")
	_player.collision_layer = 0
	var zone: ZoneAttack = ZoneAttack.new()
	zone.zone_count = 2
	zone.zone_radius = 50.0
	zone.spread = 100.0
	zone.warning_time = 0.3
	zone.burst = RadialBurstAttack.new()
	zone.burst.count = 6
	zone.burst.projectile_speed = 50.0
	zone.burst.projectile_range = 100.0
	zone.burst.projectile_texture = load("res://art/fx/boss_orb.svg")
	var before: int = _projectiles.active_count()
	zone.execute(boss, 0)
	assert_eq(_projectiles.active_count(), before, "erst Vorwarnung")
	await wait_seconds(0.5)
	assert_gte(_projectiles.active_count() - before, 12)


func test_brood_sac_releases_three_shooters() -> void:
	var sac: Enemy = _enemy("brutsack")
	var before: int = _manager.active_enemy_count()
	_hit(sac, 9999)
	assert_eq(_manager.active_enemy_count(), before - 1 + 3)


func test_healer_heals_nearby_enemy() -> void:
	var wounded: Enemy = _enemy("schattenklotz", Vector2(600, 300))
	var healer: Enemy = _enemy("flackerer", Vector2(650, 300))
	_hit(wounded, 10)
	var hp_before: float = wounded.hp
	healer.get_children().filter(func(c: Node) -> bool: return c is HealerBehavior)[0].call("_heal_allies")
	assert_gt(wounded.hp, hp_before)


func test_amplifier_buffs_with_outline() -> void:
	var target: Enemy = _enemy("schattenling", Vector2(600, 300))
	var buffer: Enemy = _enemy("verstaerker", Vector2(650, 300))
	var hp: float = target.max_hp
	buffer.get_children().filter(func(c: Node) -> bool: return c is BufferBehavior)[0].call("_buff_nearest")
	assert_true(target.is_buffed)
	assert_almost_eq(target.max_hp, hp * 2.5, 0.01)


func test_hounder_accelerates() -> void:
	var hounder: Enemy = _enemy("hetzer")
	var behavior: AccelerateBehavior = hounder.get_children().filter(func(c: Node) -> bool: return c is AccelerateBehavior)[0]
	var slow: float = behavior.get_velocity(0.0).length()
	var fast: float = behavior.get_velocity(5.0).length()
	assert_gt(fast, slow)


func test_special_waves_by_difficulty() -> void:
	GameState.difficulty = load("res://data/difficulties/spannung_0.tres")
	_manager.call("_roll_special_waves")
	assert_eq(GameState.special_waves.size(), 0)
	GameState.difficulty = load("res://data/difficulties/spannung_4.tres")
	for i in 20:
		_manager.call("_roll_special_waves")
		assert_eq(GameState.special_waves.size(), 3)
		var last: int = GameState.special_waves.keys().max()
		assert_true(last in [17, 18])
		assert_eq(GameState.special_waves[last], WaveManager.SPECIAL_ELITE, "letzte immer Elite")


func test_flickerer_needs_tension_one() -> void:
	var wave: WaveData = load("res://data/waves/wave_10.tres")
	var found: bool = false
	for g: SpawnGroupData in wave.groups:
		if g.enemy.id == &"flackerer":
			found = true
			assert_eq(g.min_difficulty, 1)
	assert_true(found)


func test_boss_wave_ends_only_when_boss_dies() -> void:
	_manager.start_wave(20)
	var bosses: Array = _manager.get("_bosses")
	assert_eq(bosses.size(), 1)
	_manager.set("_wave_time", 95.0)
	await wait_physics_frames(3)
	assert_eq(_manager.state, WaveManager.State.WAVE, "Timer abgelaufen, Boss lebt")
	_hit(bosses[0], 999999)
	await wait_physics_frames(3)
	assert_eq(_manager.state, WaveManager.State.FINISHED)


func test_tension_five_spawns_both_bosses_reduced() -> void:
	GameState.difficulty = load("res://data/difficulties/spannung_5.tres")
	_manager.start_wave(20)
	var bosses: Array = _manager.get("_bosses")
	assert_eq(bosses.size(), 2)
	assert_almost_eq((bosses[0] as Enemy).max_hp, 29000.0 * 1.4 * 0.75, 1.0)


func test_elite_drops_legendary_crate_for_tier_four() -> void:
	assert_true((load("res://data/enemies/russmutter.tres") as EnemyData).legendary_crate)
	GameState.add_crate(true)
	assert_eq(GameState.pending_legendary_crates, 1)
	var screen: CrateScreen = CrateScreen.new()
	screen.player = _player
	add_child_autofree(screen)
	screen.open()
	assert_eq((screen.get("_item") as ItemData).tier, 4)

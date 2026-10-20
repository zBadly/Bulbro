extends GutTest
## Tests für das Effektsystem: Trigger, Aktionen, Zustand pro Exemplar, Beschreibungen.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/enemies/training_dummy.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/pickup.tscn")

var _player: Player
var _system: EffectSystem


func before_each() -> void:
	GameState.start_run(3)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_system = EffectSystem.new()
	add_child_autofree(_system)
	_system.player = _player


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	add_child_autofree(dummy)
	dummy.global_position = at
	return dummy


func _damage_action(count: int, base: float) -> DamageRandomEnemiesAction:
	var action: DamageRandomEnemiesAction = DamageRandomEnemiesAction.new()
	action.count = count
	action.base_damage = base
	action.scalings = {Stats.ELEMENTAL_DMG: 0.5}
	return action


func test_on_kill_effect_damages_random_enemy() -> void:
	var dummy: TrainingDummy = _dummy(Vector2(300, 0))
	var effect: OnKillEffect = OnKillEffect.new()
	effect.chance = 1.0
	effect.action = _damage_action(1, 3.0)
	effect.apply(_player)
	_player.stats.add_modifier(StatModifier.create(Stats.ELEMENTAL_DMG, 4.0))
	Events.enemy_killed.emit(null, Vector2.ZERO, null)
	assert_eq(dummy.total_damage, 5, "3 + 50 % von Strom 4")


func test_on_hit_taken_effect_triggers() -> void:
	var dummy: TrainingDummy = _dummy(Vector2(300, 0))
	var effect: OnHitTakenEffect = OnHitTakenEffect.new()
	effect.chance = 1.0
	effect.action = _damage_action(3, 10.0)
	effect.apply(_player)
	_player.take_hit(1.0)
	assert_eq(dummy.total_damage, 10)


func test_timed_spawn_effect_keeps_state_per_copy() -> void:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = PICKUP_SCENE
	pool.group_name = Pools.PICKUPS
	add_child_autofree(pool)
	var effect: TimedSpawnEffect = TimedSpawnEffect.new()
	effect.interval = 15.0
	var spawn: SpawnPickupAction = SpawnPickupAction.new()
	spawn.kind = Pickup.Kind.BATTERY
	effect.action = spawn
	effect.apply(_player)
	effect.apply(_player)
	var ctx: EffectContext = EffectContext.create(_player)
	_player.triggers[0].effect.on_wave_tick(ctx, _player.triggers[0], 16.0)
	assert_eq(pool.active_count(), 1, "nur das erste Exemplar hat ausgelöst")
	assert_almost_eq(_player.triggers[1].timer, 0.0, 0.001)


func test_explosion_hits_only_inside_radius() -> void:
	var near: TrainingDummy = _dummy(Vector2(40, 36))
	var far: TrainingDummy = _dummy(Vector2(400, 36))
	Hits.explode(get_tree(), _player, Vector2.ZERO, 75.0, DamageInfo.create(10, false, 0.0, null))
	assert_eq(near.total_damage, 10)
	assert_eq(far.total_damage, 0)


func test_explosion_size_stat_grows_radius() -> void:
	var target: TrainingDummy = _dummy(Vector2(100, 36))
	_player.stats.add_modifier(StatModifier.create(Stats.EXPLOSION_SIZE_PCT, 50.0))
	Hits.explode(get_tree(), _player, Vector2.ZERO, 75.0, DamageInfo.create(10, false, 0.0, null))
	assert_eq(target.total_damage, 10)


func test_neutral_targets_excluded_from_random_picks() -> void:
	_dummy(Vector2(300, 0))
	for target: Damageable in Hits.random_enemies(get_tree(), 5, RandomNumberGenerator.new()):
		assert_false(target.is_neutral())


func test_effect_descriptions_are_translated() -> void:
	var effect: OnKillEffect = OnKillEffect.new()
	effect.chance = 0.25
	effect.action = _damage_action(1, 3.0)
	var text: String = effect.describe()[0]
	assert_true(text.contains("25"), text)
	assert_false(text.contains("TRIGGER_"), "Übersetzung fehlt: " + text)

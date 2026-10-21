extends GutTest
## Verbündete (Schattengeister des Irrlichts): eigenes und globales Limit, kein Gegnerlimit, keine Zielwahl durch Waffen.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ALLY_SCENE: PackedScene = preload("res://scenes/allies/ally.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/projectile.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const ALLY_LAYER: int = 1 << 7

var _player: Player
var _pool: ObjectPool
var _ctx: EffectContext


func before_each() -> void:
	GameState.start_run(31)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_pool = ObjectPool.new()
	_pool.scene = ALLY_SCENE
	_pool.group_name = Pools.ALLIES
	add_child_autofree(_pool)
	_ctx = EffectContext.create(_player)


func _effect(max_allies: int, lifetime: float = 10.0) -> ReanimateEffect:
	var effect: ReanimateEffect = ReanimateEffect.new()
	effect.interval = 3.0
	effect.min_souls = 5
	effect.max_souls = 100
	effect.lifetime = lifetime
	effect.max_allies = max_allies
	effect.base_damage = 5.0
	effect.scalings = {Stats.ELEMENTAL_DMG: 1.0}
	effect.souls_per_step = 20
	effect.bonus_per_step = 1.0
	effect.apply(_player)
	return effect


func _tick(effect: ReanimateEffect, seconds: float) -> void:
	var entry: TriggerEntry = _entry(effect)
	var steps: int = roundi(seconds / 0.5)
	for i in steps:
		effect.on_wave_tick(_ctx, entry, 0.5)


func _entry(effect: ReanimateEffect) -> TriggerEntry:
	for entry: TriggerEntry in _player.triggers:
		if entry.effect == effect:
			return entry
	return null


func _fill_souls(count: int) -> void:
	GameState.souls.add(count, SCHATTENLING, Vector2(300, 0))


func test_no_summon_below_threshold() -> void:
	var effect: ReanimateEffect = _effect(8)
	_fill_souls(4)
	_tick(effect, 9.0)
	assert_eq(Ally.active_count(get_tree()), 0)


func test_summons_every_interval_up_to_own_limit() -> void:
	var effect: ReanimateEffect = _effect(8)
	_fill_souls(5)
	_tick(effect, 3.0)
	assert_eq(Ally.active_count(get_tree()), 1, "nach 3 s der erste Geist")
	_tick(effect, 60.0)
	assert_eq(effect.active_allies(_entry(effect)).size(), 8, "höchstens 8 gleichzeitig")
	assert_eq(Ally.active_count(get_tree()), 8)


func test_global_ally_limit() -> void:
	_fill_souls(5)
	var effects: Array[ReanimateEffect] = [_effect(8), _effect(8), _effect(8)]
	for i in 12:
		for effect: ReanimateEffect in effects:
			_tick(effect, 3.0)
	assert_eq(Ally.active_count(get_tree()), STATUS.ally_global_max)


func test_ally_damage_grows_with_souls() -> void:
	var effect: ReanimateEffect = _effect(8)
	_player.stats.add_modifier(StatModifier.create(Stats.ELEMENTAL_DMG, 4.0))
	_fill_souls(45)
	_tick(effect, 3.0)
	var ally: Ally = effect.active_allies(_entry(effect))[0]
	assert_eq(ally.damage, 11, "5 + 100 % Strom (4) + 2 (45 Seelen = 2 volle Schritte)")
	assert_eq(ally.data, SCHATTENLING, "Aussehen des zuletzt getöteten Gegnertyps")


func test_allies_are_not_targets_and_not_enemies() -> void:
	var effect: ReanimateEffect = _effect(8)
	_fill_souls(5)
	_tick(effect, 3.0)
	var ally: Ally = effect.active_allies(_entry(effect))[0]
	assert_false(ally.is_in_group(Damageable.GROUP), "Waffen suchen Ziele nur in der Gegnergruppe")
	assert_eq(Hits.alive_targets(get_tree()).size(), 0)
	assert_eq(ally.collision_layer, ALLY_LAYER, "eigene Ebene allies")
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	add_child_autofree(projectile)
	assert_eq(projectile.collision_mask & ALLY_LAYER, 0, "Spielerprojektile treffen keine Verbündeten")


func test_allies_do_not_count_toward_enemy_limit() -> void:
	var manager: WaveManager = WaveManager.new()
	add_child_autofree(manager)
	var effect: ReanimateEffect = _effect(8)
	_fill_souls(5)
	_tick(effect, 24.0)
	assert_eq(Ally.active_count(get_tree()), 8)
	assert_eq(manager.active_enemy_count(), 0)


func test_allies_expire_and_are_dismissed_at_wave_end() -> void:
	var effect: ReanimateEffect = _effect(8, 0.2)
	_fill_souls(5)
	_tick(effect, 3.0)
	assert_eq(Ally.active_count(get_tree()), 1)
	await wait_seconds(0.5)
	assert_eq(Ally.active_count(get_tree()), 0, "nach der Lebenszeit verschwunden")
	var long_effect: ReanimateEffect = _effect(8)
	_tick(long_effect, 6.0)
	assert_eq(Ally.active_count(get_tree()), 2)
	long_effect.on_wave_ended(_ctx, _entry(long_effect))
	assert_eq(Ally.active_count(get_tree()), 0)
	assert_eq(_pool.active_count(), 0, "zurück im Pool")


func test_ally_hits_enemies_on_contact() -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	var data: EnemyData = SCHATTENLING.duplicate()
	data.base_hp = 1000.0
	data.speed_min = 0.0
	data.speed_max = 0.0
	enemy.setup(data)
	enemy.activate(1, Vector2(600, 0), _player, Rect2(), _player.rng)
	var effect: ReanimateEffect = _effect(8)
	GameState.souls.add(5, SCHATTENLING, Vector2(560, 0))
	_tick(effect, 3.0)
	await wait_seconds(1.2)
	assert_lt(enemy.hp, 1000.0, "Kontaktschaden des Geistes")

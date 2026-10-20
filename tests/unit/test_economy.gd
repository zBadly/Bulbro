extends GutTest
## Tests für XP, Drops, Beutel und Aufladung (GDD Abschnitte 5 und 6).

const EPS: float = 0.0001
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/pickup.tscn")
const DROPS: DropConfig = preload("res://data/config/drop_config.tres")


func before_each() -> void:
	GameState.start_run(42)


# XP-Formel
func test_xp_for_level_formula() -> void:
	assert_eq(Economy.xp_for_level(0), 9.0)
	assert_eq(Economy.xp_for_level(1), 16.0)
	assert_eq(Economy.xp_for_level(7), 100.0)


func test_xp_gain_bonus() -> void:
	assert_almost_eq(Economy.xp_gain(4.0, 25.0), 5.0, EPS)
	assert_eq(Economy.xp_gain(4.0, -200.0), 0.0)


func test_level_ups_are_counted_and_carry_over() -> void:
	watch_signals(Events)
	GameState.add_xp(9.0 + 16.0 + 3.0)
	assert_eq(GameState.level, 2)
	assert_eq(GameState.pending_level_ups, 2)
	assert_almost_eq(GameState.xp, 3.0, EPS)
	assert_signal_emit_count(Events, "level_up", 2)


func test_level_up_gives_max_hp() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	GameState.add_xp(9.0)
	assert_eq(player.get_max_hp(), 10.0 + player.config.max_hp_per_level)


# Kartonchance
func test_crate_chance_base() -> void:
	assert_almost_eq(Economy.crate_chance(0.3, 0.0, 0), 0.3, EPS)


func test_crate_chance_luck() -> void:
	assert_almost_eq(Economy.crate_chance(0.3, 100.0, 0), 0.6, EPS)
	assert_eq(Economy.crate_chance(0.3, -100.0, 0), 0.0)


func test_crate_chance_drops_with_crates_this_wave() -> void:
	assert_almost_eq(Economy.crate_chance(0.3, 0.0, 2), 0.1, EPS)


# Batterien
func test_battery_chance_luck() -> void:
	assert_almost_eq(Economy.battery_chance(0.02, 100.0), 0.04, EPS)
	assert_eq(Economy.battery_chance(0.02, -100.0), 0.0)


# Aufladung
func test_harvesting_growth_rounds_up() -> void:
	assert_eq(Economy.harvesting_growth(8.0), 1)
	assert_eq(Economy.harvesting_growth(20.0), 1)
	assert_eq(Economy.harvesting_growth(21.0), 2)
	assert_eq(Economy.harvesting_growth(100.0), 5)


func test_harvesting_only_grows_when_positive() -> void:
	assert_eq(Economy.harvesting_growth(0.0), 0)
	assert_eq(Economy.harvesting_growth(-10.0), 0)


func test_wave_end_pays_harvesting_and_grows_it() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.stats.add_modifier(StatModifier.create(Stats.HARVESTING, 8.0))
	var drops: DropManager = DropManager.new()
	drops.player = player
	add_child_autofree(drops)
	Events.wave_ended.emit(1)
	assert_eq(GameState.sparks, 8)
	assert_eq(player.stats.get_stat(Stats.HARVESTING), 9.0)


# Beutel
func test_bag_adds_one_per_collected_spark() -> void:
	GameState.add_to_bag(2)
	assert_eq(GameState.collect_spark(1, 0.0), 2)
	assert_eq(GameState.collect_spark(1, 0.0), 2)
	assert_eq(GameState.collect_spark(1, 0.0), 1, "Beutel leer")
	assert_eq(GameState.sparks, 5)
	assert_eq(GameState.bag, 0)


func test_wave_end_moves_leftover_sparks_to_bag() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = PICKUP_SCENE
	pool.group_name = Pools.PICKUPS
	add_child_autofree(pool)
	var drops: DropManager = DropManager.new()
	drops.player = player
	add_child_autofree(drops)
	var far: Vector2 = Vector2(5000, 5000)
	(pool.acquire() as Pickup).drop(Pickup.Kind.SPARK, 1, far, far, player)
	(pool.acquire() as Pickup).drop(Pickup.Kind.SPARK, 2, far, far, player)
	(pool.acquire() as Pickup).drop(Pickup.Kind.CRATE, 1, far, far, player)
	Events.wave_ended.emit(1)
	assert_eq(GameState.bag, 3)
	assert_eq(GameState.pending_crates, 1, "Kartons werden am Wellenende eingesammelt")
	assert_eq(pool.active_count(), 0)


# Kristall
func test_crystal_breaks_after_at_most_max_hits() -> void:
	var max_hp: float = 10.0 + 5.0 * 9
	var hits: int = 0
	var hp: float = max_hp
	while hp > 0.0:
		hp -= Economy.crystal_hit_damage(1.0, max_hp, DROPS.crystal_max_hits)
		hits += 1
	assert_eq(hits, DROPS.crystal_max_hits)


func test_thief_drops_crate_and_eight_sparks() -> void:
	assert_eq(DROPS.thief.sparks, 8)
	assert_true(DROPS.thief.guaranteed_crate)
	assert_false(DROPS.thief.despawnable)

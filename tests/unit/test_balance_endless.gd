extends GutTest
## Tests für das Balancing-Modell und den Endlos-Modus (Phase 13).

const ENDLESS: EndlessConfig = preload("res://data/config/endless_config.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const MARKER_SCENE: PackedScene = preload("res://scenes/world/spawn_marker.tscn")


func before_each() -> void:
	GameState.difficulty = null
	GameState.start_run(5)


func _weapons() -> Dictionary:
	var result: Dictionary = {}
	for res: Resource in DataRegistry.get_all("weapons"):
		result[String((res as WeaponData).id)] = res
	return result


# --- Balancing-Modell ---
func test_wave_load_grows_and_respects_tension() -> void:
	var early: Dictionary = BalanceModel.wave_load(load("res://data/waves/wave_03.tres"), load("res://data/difficulties/spannung_0.tres"))
	var late: Dictionary = BalanceModel.wave_load(load("res://data/waves/wave_15.tres"), load("res://data/difficulties/spannung_0.tres"))
	var late_hard: Dictionary = BalanceModel.wave_load(load("res://data/waves/wave_15.tres"), load("res://data/difficulties/spannung_5.tres"))
	assert_gt(late["hp"], early["hp"])
	assert_gt(late_hard["hp"], late["hp"])
	assert_almost_eq(late["required_dps"], late["hp"] / 60.0, 0.01)


func test_build_dps_grows_with_waves() -> void:
	var weapons: Dictionary = _weapons()
	for build: String in BalanceModel.BUILDS:
		var first: float = BalanceModel.build_dps(BalanceModel.BUILDS[build], 1, weapons)
		var last: float = BalanceModel.build_dps(BalanceModel.BUILDS[build], 19, weapons)
		assert_gt(first, 0.0, build)
		assert_gt(last, first * 10.0, build)


func test_rating_and_interval_suggestion() -> void:
	assert_eq(BalanceModel.rating(0.5), "zu schwer")
	assert_eq(BalanceModel.rating(1.5), "ok")
	assert_eq(BalanceModel.rating(4.0), "zu leicht")
	assert_gt(BalanceModel.interval_factor(0.5), 1.0, "zu schwer -> längere Intervalle")
	assert_lt(BalanceModel.interval_factor(4.0), 1.0, "zu leicht -> kürzere Intervalle")
	assert_eq(BalanceModel.interval_factor(100.0), BalanceModel.MIN_INTERVAL_FACTOR)


# --- Endlos-Modus ---
func test_endless_level_counts_waves_after_victory() -> void:
	assert_eq(GameState.endless_level(), 0, "vor dem Endlos-Modus neutral")
	GameState.endless = true
	GameState.endless_start_wave = 20
	GameState.current_wave = 22
	assert_eq(GameState.endless_level(), 2)


func test_endless_waves_use_template() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var markers: ObjectPool = ObjectPool.new()
	markers.scene = MARKER_SCENE
	markers.group_name = Pools.SPAWN_MARKERS
	add_child_autofree(markers)
	var manager: WaveManager = WaveManager.new()
	add_child_autofree(manager)
	var container: Node2D = Node2D.new()
	add_child_autofree(container)
	manager.resume_at(player, Rect2(-1000, -650, 2000, 1300), container, 20)
	GameState.endless = true
	GameState.endless_start_wave = 20
	manager.start_next_wave()
	assert_eq(manager.get_wave_number(), 21)
	assert_eq(manager.time_left, ENDLESS.wave_duration)
	assert_eq(GameState.current_wave, 21)
	manager.call("_end_wave")
	assert_eq(manager.state, WaveManager.State.INTERMISSION, "Endloswellen führen weiter zum Shop")


func test_endless_enemies_are_stronger() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	add_child_autofree(enemy)
	enemy.setup(load("res://data/enemies/schattenling.tres"))
	enemy.activate(21, Vector2(500, 0), player, Rect2(), player.rng)
	var normal: float = enemy.max_hp
	GameState.endless = true
	GameState.endless_start_wave = 20
	GameState.current_wave = 21
	enemy.activate(21, Vector2(500, 0), player, Rect2(), player.rng)
	assert_almost_eq(enemy.max_hp, normal * (1.0 + ENDLESS.hp_growth), 0.01)


func test_run_is_reported_only_once() -> void:
	SaveManager.reset()
	GameState.total_sparks_collected = 100
	Unlocks.evaluate_run_end(true)
	GameState.endless = true
	GameState.total_sparks_collected = 150
	Unlocks.evaluate_run_end(false)
	assert_eq(SaveManager.get_stat(SaveManager.STAT_RUNS), 1)
	assert_eq(SaveManager.get_total_sparks(), 150)
	SaveManager.reset()

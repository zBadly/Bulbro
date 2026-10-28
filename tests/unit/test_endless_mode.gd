extends GutTest
## Endlos-Modus (Phase 15, Paket 6): Regeln aus EndlessConfig, Bosswellen mit Zyklus-Bonus, Sonderwellen,
## Belohnung, Banner-Zähler und Bestwert je Charakter (nicht in Admin-Runs).

const ENDLESS: EndlessConfig = preload("res://data/config/endless_config.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const MARKER_SCENE: PackedScene = preload("res://scenes/world/spawn_marker.tscn")
const ARENA_SCENE: PackedScene = preload("res://scenes/world/arena.tscn")
const TEST_PATH: String = "user://test_endless_mode.json"
const REGULAR_WAVES: int = 20
const SETTLE_FRAMES: int = 10
const MAX_KILL_FRAMES: int = 600
const ARENA_RECT: Rect2 = Rect2(-1000, -650, 2000, 1300)


func before_each() -> void:
	SaveManager.use_path(TEST_PATH)
	SaveManager.reset()
	GameState.character = null
	GameState.starting_weapon = null
	GameState.difficulty = null
	GameState.start_run(7)


func after_each() -> void:
	get_tree().paused = false
	GameState.character = null
	GameState.starting_weapon = null
	GameState.difficulty = null
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	SaveManager.use_path("user://test_save.json")
	SaveManager.reset()


func _manager_after(wave_number: int) -> WaveManager:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.debug_invulnerable = true
	var markers: ObjectPool = ObjectPool.new()
	markers.scene = MARKER_SCENE
	markers.group_name = Pools.SPAWN_MARKERS
	add_child_autofree(markers)
	var manager: WaveManager = WaveManager.new()
	add_child_autofree(manager)
	var container: Node2D = Node2D.new()
	add_child_autofree(container)
	manager.resume_at(player, ARENA_RECT, container, mini(wave_number, REGULAR_WAVES))
	GameState.endless = true
	GameState.endless_start_wave = REGULAR_WAVES
	return manager


# --- Regeln ---

func test_growth_factors_compound_and_cap() -> void:
	assert_eq(EndlessRules.hp_factor(0), 1.0, "Stufe 0 neutral")
	assert_almost_eq(EndlessRules.hp_factor(2), pow(1.0 + ENDLESS.hp_growth, 2), 0.0001)
	assert_almost_eq(EndlessRules.damage_factor(3), pow(1.0 + ENDLESS.damage_growth, 3), 0.0001)
	assert_almost_eq(EndlessRules.speed_factor(500), 1.0 + ENDLESS.speed_max, 0.0001, "Tempo gedeckelt")
	assert_almost_eq(EndlessRules.density_factor(500), 1.0 + ENDLESS.density_max, 0.0001, "Dichte gedeckelt")


func test_harvest_gets_weaker_down_to_minimum() -> void:
	assert_eq(EndlessRules.harvest_factor(0), 1.0, "außerhalb des Endlos-Modus volle Aufladung")
	assert_almost_eq(EndlessRules.harvest_factor(1), ENDLESS.harvest_start, 0.0001)
	assert_almost_eq(EndlessRules.harvest_factor(2), ENDLESS.harvest_start - ENDLESS.harvest_decay, 0.0001)
	assert_lt(EndlessRules.harvest_factor(5), EndlessRules.harvest_factor(4))
	assert_almost_eq(EndlessRules.harvest_factor(1000), ENDLESS.harvest_min, 0.0001)


func test_boss_and_special_levels() -> void:
	var cycle: int = ENDLESS.boss_cycle_waves
	assert_true(EndlessRules.is_boss_level(cycle), "Welle 30")
	assert_true(EndlessRules.is_boss_level(cycle * 3), "Welle 50")
	assert_false(EndlessRules.is_boss_level(cycle - 1))
	assert_false(EndlessRules.is_boss_level(0))
	assert_eq(EndlessRules.boss_cycle(cycle * 2), 2)
	assert_true(EndlessRules.is_special_level(ENDLESS.special_wave_offset), "Welle 25")
	assert_true(EndlessRules.is_special_level(cycle + ENDLESS.special_wave_offset), "Welle 35")
	assert_false(EndlessRules.is_special_level(cycle))


func test_cycle_bonus_is_linear() -> void:
	assert_eq(EndlessRules.boss_hp_bonus(0), 1.0)
	assert_almost_eq(EndlessRules.boss_hp_bonus(1), 1.0 + ENDLESS.boss_cycle_hp_bonus, 0.0001)
	assert_almost_eq(EndlessRules.boss_hp_bonus(3), 1.0 + 3.0 * ENDLESS.boss_cycle_hp_bonus, 0.0001)
	assert_almost_eq(EndlessRules.boss_damage_bonus(2), 1.0 + 2.0 * ENDLESS.boss_cycle_damage_bonus, 0.0001)


# --- Wellen ---

func test_endless_wave_uses_density() -> void:
	var manager: WaveManager = _manager_after(REGULAR_WAVES)
	manager.start_wave(REGULAR_WAVES + 4)
	assert_almost_eq(float(manager.get("_density")), EndlessRules.density_factor(4), 0.0001)


func test_specials_are_rolled_for_the_next_block() -> void:
	var manager: WaveManager = _manager_after(REGULAR_WAVES)
	manager.start_next_wave()
	var special: int = REGULAR_WAVES + ENDLESS.special_wave_offset
	assert_true(GameState.special_waves.has(special), "Welle 25 ist Elite oder Horde")
	assert_true(GameState.special_waves[special] in [WaveManager.SPECIAL_ELITE, WaveManager.SPECIAL_HORDE])
	assert_false(GameState.special_waves.has(special + ENDLESS.boss_cycle_waves), "nächster Block noch offen")


func test_endless_elite_uses_elite_hp_factor() -> void:
	var manager: WaveManager = _manager_after(REGULAR_WAVES)
	var special: int = REGULAR_WAVES + ENDLESS.special_wave_offset
	GameState.special_waves[special] = WaveManager.SPECIAL_ELITE
	manager.start_wave(special)
	var elites: Array[Enemy] = []
	elites.assign(manager.get("_bosses"))
	assert_eq(elites.size(), 1, "Elite-Welle bringt einen Elite")
	assert_true(elites[0].data.is_elite)
	assert_almost_eq(elites[0].hp_multiplier, ENDLESS.elite_hp_factor, 0.0001)


func test_endless_horde_uses_horde_factor() -> void:
	var manager: WaveManager = _manager_after(REGULAR_WAVES)
	var special: int = REGULAR_WAVES + ENDLESS.special_wave_offset
	GameState.special_waves[special] = WaveManager.SPECIAL_HORDE
	manager.start_wave(special)
	manager.clear_enemies()
	var group: SpawnGroupData = SpawnGroupData.new()
	group.enemy = load("res://data/enemies/schattenling.tres")
	group.group_min = 4
	group.group_max = 4
	manager.call("_queue_group", group)
	var pending: Array = manager.get("_pending")
	assert_eq(pending.size(), roundi(4 * ENDLESS.horde_factor), "Gruppengröße x horde_factor")


func test_endless_boss_wave_spawns_all_bosses_with_cycle_bonus() -> void:
	var boss_wave: int = REGULAR_WAVES + ENDLESS.boss_cycle_waves
	var manager: WaveManager = _manager_after(REGULAR_WAVES)
	watch_signals(Events)
	watch_signals(manager)
	manager.start_wave(boss_wave)
	var bosses: Array[Enemy] = []
	bosses.assign(manager.get("_bosses"))
	assert_eq(bosses.size(), 2, "beide Bosse gleichzeitig")
	var level: int = ENDLESS.boss_cycle_waves
	for boss: Enemy in bosses:
		assert_true(boss.data.is_boss)
		var expected_hp: float = boss.data.hp_for_wave(boss_wave) * EndlessRules.hp_factor(level) * EndlessRules.boss_hp_bonus(1)
		assert_almost_eq(boss.max_hp, expected_hp, 0.5, "volle HP + Zyklus-Bonus")
		var expected_damage: float = boss.data.damage_for_wave(boss_wave) * EndlessRules.damage_factor(level) * EndlessRules.boss_damage_bonus(1)
		assert_almost_eq(boss.damage, expected_damage, 0.01)
	for boss: Enemy in bosses:
		boss.die()
	await wait_physics_frames(2)
	assert_eq(manager.state, WaveManager.State.INTERMISSION, "danach normal weiter zum Shop")
	assert_signal_not_emitted(manager, "run_won")
	assert_signal_emitted_with_parameters(Events, "endless_bosses_defeated", [1])
	assert_eq(GameState.run_stats.boss_cycles, 1)


func test_boss_wave_lasts_until_bosses_are_dead() -> void:
	var manager: WaveManager = _manager_after(REGULAR_WAVES)
	manager.start_wave(REGULAR_WAVES + ENDLESS.boss_cycle_waves)
	manager.set("_wave_time", 10000.0)
	await wait_physics_frames(2)
	assert_eq(manager.state, WaveManager.State.WAVE, "Timer beendet die Bosswelle nicht")


func test_regular_boss_spawn_unchanged() -> void:
	GameState.difficulty = load("res://data/difficulties/spannung_0.tres")
	var manager: WaveManager = _manager_after(REGULAR_WAVES)
	GameState.endless = false
	GameState.endless_start_wave = 0
	manager.start_wave(REGULAR_WAVES)
	var bosses: Array[Enemy] = []
	bosses.assign(manager.get("_bosses"))
	assert_eq(bosses.size(), 1, "Welle 20 auf Spannung 0: ein Boss")
	assert_eq(bosses[0].damage_multiplier, 1.0)


# --- Bestwert ---

func test_endless_best_keeps_maximum_and_is_saved() -> void:
	assert_eq(SaveManager.get_endless_best(&"kerze"), 0)
	SaveManager.record_endless_best(&"kerze", 7)
	SaveManager.record_endless_best(&"kerze", 4)
	assert_eq(SaveManager.get_endless_best(&"kerze"), 7)
	SaveManager.save_game()
	SaveManager.reset()
	SaveManager.load_game()
	assert_eq(SaveManager.get_endless_best(&"kerze"), 7, "über Speichern/Laden erhalten")


func test_run_history_contains_boss_cycles() -> void:
	GameState.character = load("res://data/characters/standardbirne.tres")
	GameState.run_stats.boss_cycles = 2
	var entry: Dictionary = RunHistory.make_entry(true)
	assert_eq(entry["boss_cycles"], 2)
	var restored: RunStats = RunStats.from_dict(GameState.run_stats.to_dict())
	assert_eq(restored.boss_cycles, 2, "Fortsetzen behält den Zähler")


# --- Arena ---

func _arena() -> Arena:
	GameState.character = load("res://data/characters/standardbirne.tres")
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	arena.player.debug_invulnerable = true
	return arena


func _kill_until_intermission(arena: Arena) -> void:
	var frames: int = 0
	while arena.wave_manager.state == WaveManager.State.WAVE and frames < MAX_KILL_FRAMES:
		for enemy: Enemy in arena.wave_manager._active.duplicate():
			if enemy.is_alive():
				enemy.die()
		await get_tree().physics_frame
		frames += 1


func test_arena_endless_boss_wave_rewards_and_banner() -> void:
	var arena: Arena = await _arena()
	var boss_wave: int = REGULAR_WAVES + ENDLESS.boss_cycle_waves
	arena.wave_manager.admin_jump_to_wave(boss_wave)
	await get_tree().process_frame
	var hud: Hud = arena.get_node("Hud") as Hud
	assert_eq((hud.get("_wave_label") as Label).text, tr("HUD_WAVE_ENDLESS") % [ENDLESS.boss_cycle_waves, boss_wave])
	assert_eq(SaveManager.get_endless_best(&"standardbirne"), ENDLESS.boss_cycle_waves, "Bestwert beim Erreichen")
	await _kill_until_intermission(arena)
	assert_eq(arena.wave_manager.state, WaveManager.State.INTERMISSION)
	assert_false(arena.get_node("GameOver").visible, "kein Siegbildschirm")
	assert_eq(GameState.pending_legendary_crates, 2 * ENDLESS.boss_legendary_crates, "je Boss ein legendärer Karton")
	var banner: Label = hud.get("_banner") as Label
	assert_true(banner.visible)
	assert_eq(banner.text, tr("ENDLESS_BOSSES_DEFEATED") % 1)
	assert_eq(GameState.run_stats.boss_cycles, 1)


func test_admin_run_does_not_record_endless_best() -> void:
	var arena: Arena = await _arena()
	GameState.admin.used = true
	arena.wave_manager.admin_jump_to_wave(REGULAR_WAVES + 3)
	await get_tree().process_frame
	assert_eq(SaveManager.get_endless_best(&"standardbirne"), 0)

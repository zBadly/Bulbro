extends GutTest
## Admin-Modus (Phase 15/3): Admin-Runs zählen nicht, Merker übersteht Fortsetzen, Admin-Funktionen wirken.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const MARKER_SCENE: PackedScene = preload("res://scenes/world/spawn_marker.tscn")
const ARENA_SCENE: PackedScene = preload("res://scenes/world/arena.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const WAVES: WaveConfig = preload("res://data/config/wave_config.tres")
const SETTLE_FRAMES: int = 10


func before_each() -> void:
	SaveManager.reset()
	GameState.character = null
	GameState.starting_weapon = null
	GameState.difficulty = null
	GameState.start_run(81)


func after_each() -> void:
	get_tree().paused = false
	Engine.time_scale = AdminState.NORMAL_SPEED
	GameState.start_run(82)
	SaveManager.reset()


func _player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.rng = RandomNumberGenerator.new()
	add_child_autofree(player)
	player.apply_character(load("res://data/characters/standardbirne.tres"))
	return player


func _enemy(hp: float, player: Player) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	var data: EnemyData = SCHATTENLING.duplicate()
	data.base_hp = hp
	enemy.setup(data)
	enemy.activate(1, Vector2(500, 0), player, Rect2(), player.rng)
	enemy.set_physics_process(false)
	return enemy


# --- Nichts zählt ---

func test_admin_option_is_off_by_default() -> void:
	assert_false(AdminState.is_enabled())
	SaveManager.set_option(SaveManager.ADMIN_MODE_KEY, true)
	assert_true(AdminState.is_enabled())


func test_admin_run_counts_nothing() -> void:
	GameState.character = load("res://data/characters/standardbirne.tres")
	GameState.admin.used = true
	GameState.total_sparks_collected = 5000
	GameState.run_stats.enemies_killed = 600
	GameState.run_stats.primitive_only = true
	SaveManager.save_run({"wave": 3})
	assert_eq(Unlocks.check(false, false).size(), 0, "keine Freischaltung während der Welle")
	assert_eq(SaveManager.get_challenge_best(&"unlock_irrlicht"), 0.0, "kein Bestwert")
	GameState.end_run(true)
	assert_eq(Unlocks.evaluate_run_end(true).size(), 0)
	for stat: String in [SaveManager.STAT_RUNS, SaveManager.STAT_KILLS, SaveManager.STAT_TOTAL_SPARKS, SaveManager.STAT_WINS]:
		assert_eq(SaveManager.get_stat(stat), 0, "Statistik unverändert: " + stat)
	assert_eq(SaveManager.get_wins(&"standardbirne"), 0, "kein Sieg")
	assert_false(SaveManager.is_character_unlocked(&"kerze"), "keine Siegbedingung")
	assert_false(SaveManager.is_character_unlocked(&"smartbulb"))
	assert_false(SaveManager.has_run(), "Fortsetzen-Stand wird trotzdem verworfen")


func test_normal_run_still_counts() -> void:
	GameState.character = load("res://data/characters/standardbirne.tres")
	GameState.run_stats.enemies_killed = 10
	GameState.end_run(false)
	Unlocks.evaluate_run_end(false)
	assert_eq(SaveManager.get_stat(SaveManager.STAT_RUNS), 1)
	assert_eq(SaveManager.get_stat(SaveManager.STAT_KILLS), 10)


func test_admin_flag_survives_resume() -> void:
	GameState.character = load("res://data/characters/standardbirne.tres")
	var player: Player = _player()
	GameState.admin.used = true
	var data: Dictionary = JSON.parse_string(JSON.stringify(RunSave.capture(player)))
	GameState.start_run(83)
	assert_false(GameState.admin.used, "neuer Run beginnt sauber")
	RunSave.restore_state(data)
	assert_true(GameState.admin.used, "Beenden und Fortsetzen löscht den Merker nicht")


# --- Admin-Funktionen ---

func test_damage_boost_and_infinite_hp() -> void:
	var player: Player = _player()
	var enemy: Enemy = _enemy(1000.0, player)
	GameState.admin.damage_factor = AdminState.DAMAGE_BOOST
	enemy.take_damage(DamageInfo.create(5, false, 0.0, null))
	assert_almost_eq(enemy.hp, 950.0, 0.01, "Schaden x10")
	GameState.admin.infinite_hp = true
	var hp: float = player.current_hp
	var hits: Array[int] = [0]
	player.damaged.connect(func(_amount: int) -> void: hits[0] += 1)
	player.take_hit(5.0)
	assert_eq(player.current_hp, hp, "Unendlich HP: keine HP verloren")
	assert_eq(hits[0], 1, "Treffer kommt trotzdem an")


func test_set_level_adjusts_max_hp_bonus() -> void:
	var player: Player = _player()
	var base_hp: float = player.get_max_hp()
	player.admin_set_level(5)
	assert_eq(GameState.level, 5)
	assert_almost_eq(player.get_max_hp(), base_hp + 5 * player.config.max_hp_per_level, 0.01)
	player.admin_set_level(2)
	assert_almost_eq(player.get_max_hp(), base_hp + 2 * player.config.max_hp_per_level, 0.01)


func test_shop_free_and_free_reroll() -> void:
	var player: Player = _player()
	var screen: ShopScreen = ShopScreen.new()
	add_child_autofree(screen)
	screen.player = player
	screen.set("_ctx", ShopContext.from_run(player))
	var offer: ShopOffer = ShopOffer.new()
	offer.price = 40
	assert_eq(screen.call("_offer_price", offer), 40)
	assert_gt(screen.call("_reroll_price"), 0)
	GameState.admin.shop_free = true
	GameState.admin.free_reroll = true
	assert_eq(screen.call("_offer_price", offer), 0)
	assert_eq(screen.call("_reroll_price"), 0)


func test_place_offer_puts_locked_item_into_shop() -> void:
	var player: Player = _player()
	var ctx: ShopContext = ShopContext.from_run(player)
	GameState.shop.open_shop(ctx)
	var item: ItemData = load("res://data/items/kernreaktor.tres")
	GameState.shop.place_offer(2, item, null, 1, ctx)
	assert_eq(GameState.shop.offers[2].item, item)
	assert_true(GameState.shop.offers[2].locked, "bleibt bis zum Kauf")
	var weapon: WeaponData = load("res://data/weapons/prisma.tres")
	GameState.shop.place_offer(0, null, weapon, 3, ctx)
	assert_eq(GameState.shop.offers[0].weapon, weapon)
	assert_eq(GameState.shop.offers[0].tier, 3)


func test_spawn_bosses_clear_and_endless_wave() -> void:
	var player: Player = _player()
	var markers: ObjectPool = ObjectPool.new()
	markers.scene = MARKER_SCENE
	markers.group_name = Pools.SPAWN_MARKERS
	add_child_autofree(markers)
	var manager: WaveManager = WaveManager.new()
	add_child_autofree(manager)
	var container: Node2D = Node2D.new()
	add_child_autofree(container)
	manager.resume_at(player, Rect2(-1000, -650, 2000, 1300), container, 3)
	manager.admin_jump_to_wave(4)
	manager.spawn_enemy(load("res://data/enemies/dimmer.tres"), Vector2(400, 0))
	manager.spawn_enemy(load("res://data/enemies/kolbengolem.tres"), Vector2(-400, 0))
	manager.spawn_enemy(SCHATTENLING, Vector2(0, 400))
	assert_eq(manager.active_enemy_count(), 3, "Boss, Elite und normaler Gegner")
	manager.clear_enemies()
	assert_eq(manager.active_enemy_count(), 0)
	manager.admin_jump_to_wave(23)
	assert_true(GameState.endless, "Welle über 20 = Endlos")
	assert_eq(manager.get_wave_number(), 23)
	assert_eq(manager.time_left, WAVES.endless_wave_duration)
	manager.admin_jump_to_wave(5)
	assert_false(GameState.endless, "zurück zu regulären Wellen")
	GameState.admin.time_frozen = true
	var before: float = manager.time_left
	await wait_physics_frames(5)
	assert_eq(manager.time_left, before, "Wellenzeit steht")


func test_admin_menu_marks_run_only_on_action() -> void:
	SaveManager.set_option(SaveManager.ADMIN_MODE_KEY, true)
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var menu: AdminMenu = arena.get_node("AdminMenu")
	menu.toggle()
	assert_true(menu.visible)
	assert_true(get_tree().paused, "Spiel pausiert")
	assert_false(GameState.admin.used, "Öffnen allein markiert nichts")
	menu.act(func() -> void: GameState.sparks = 999)
	assert_true(GameState.admin.used)
	menu.toggle()
	assert_false(get_tree().paused)


func test_game_speed_survives_hit_stop() -> void:
	var arena: Arena = ARENA_SCENE.instantiate()
	add_child_autofree(arena)
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	GameState.admin.game_speed = 2.0
	arena.call("_apply_game_speed")
	assert_eq(Engine.time_scale, 2.0)
	arena.hit_stop()
	assert_lt(Engine.time_scale, 1.0, "Hit-Stop")
	await get_tree().create_timer(0.2, true, false, true).timeout
	assert_eq(Engine.time_scale, 2.0, "zurück auf Admin-Geschwindigkeit")

class_name Arena
extends Node2D
## Spielszene eines Runs: Arena mit Boden, Rand und Kamera, Spieler, Wellen, HUD und Endbildschirm.

const LIGHTING_SECTION: String = "options"
const LIGHTING_KEY: String = "lighting"
const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const WAVES: WaveConfig = preload("res://data/config/wave_config.tres")
const WEAPON_CATEGORY: String = "weapons"
const ENEMY_CATEGORY: String = "enemies"
const DROPS: DropConfig = preload("res://data/config/drop_config.tres")

@export var config: ArenaConfig

@onready var _floor: Sprite2D = $Floor
@onready var _darkness: CanvasModulate = $Darkness
@onready var _camera: Camera2D = $Camera
@onready var _entities: Node2D = $Entities
@onready var player: Player = $Entities/Player
@onready var wave_manager: WaveManager = $WaveManager
@onready var _drop_manager: DropManager = $DropManager
@onready var _effect_system: EffectSystem = $EffectSystem
@onready var _neutral_spawner: NeutralSpawner = $NeutralSpawner
@onready var _hud: Hud = $Hud
@onready var _game_over: GameOverScreen = $GameOver
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _crate_screen: CrateScreen = $CrateScreen
@onready var _level_up_screen: LevelUpScreen = $LevelUpScreen
@onready var _shop_screen: ShopScreen = $ShopScreen
@onready var _projectile_pool: ObjectPool = $Pools/PlayerProjectiles
@onready var _damage_number_pool: ObjectPool = $Pools/DamageNumbers
@onready var _enemy_projectile_pool: ObjectPool = $Pools/EnemyProjectiles
@onready var _spawn_marker_pool: ObjectPool = $Pools/SpawnMarkers
@onready var _pickup_pool: ObjectPool = $Pools/Pickups

var _debug_weapon_index: int = 0


func _ready() -> void:
	GameState.start_run()
	_projectile_pool.prewarm(COMBAT.projectile_pool_size)
	_damage_number_pool.prewarm(COMBAT.damage_number_pool_size)
	_enemy_projectile_pool.prewarm(WAVES.enemy_projectile_pool_size)
	_spawn_marker_pool.prewarm(WAVES.spawn_marker_pool_size)
	_pickup_pool.prewarm(DROPS.pickup_pool_size)

	var rect: Rect2 = config.get_rect()
	_floor.region_rect = Rect2(Vector2.ZERO, config.size)
	_floor.position = rect.get_center()
	player.arena_bounds = rect
	for weapon: WeaponData in player.config.starting_weapons:
		player.weapon_slots.add_weapon(weapon)

	var lighting: bool = SaveManager.get_value(LIGHTING_SECTION, LIGHTING_KEY, true)
	_darkness.color = config.darkness_color
	_darkness.visible = lighting
	_setup_camera(rect)
	queue_redraw()

	_hud.bind(player, wave_manager)
	player.died.connect(_on_player_died)
	wave_manager.run_won.connect(_on_run_won)
	wave_manager.wave_ended.connect(_on_wave_ended)
	Events.run_phase_changed.connect(_on_phase_changed)
	for screen: FlowScreen in [_crate_screen, _level_up_screen, _shop_screen]:
		screen.player = player
	_drop_manager.player = player
	_effect_system.player = player
	_neutral_spawner.wave_manager = wave_manager
	_neutral_spawner.player = player
	_neutral_spawner.container = _entities
	wave_manager.start(player, rect, _entities)


func _process(_delta: float) -> void:
	_camera.global_position = player.global_position


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_add_weapon"):
		_debug_add_weapon()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_spawn_enemies"):
		_debug_spawn_enemies()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(config.get_rect(), config.border_color, false, config.border_width)


func _setup_camera(rect: Rect2) -> void:
	_camera.zoom = Vector2.ONE * config.camera_zoom
	_camera.position_smoothing_speed = config.camera_smoothing_speed
	_camera.limit_left = floori(rect.position.x - config.camera_margin)
	_camera.limit_top = floori(rect.position.y - config.camera_margin)
	_camera.limit_right = ceili(rect.end.x + config.camera_margin)
	_camera.limit_bottom = ceili(rect.end.y + config.camera_margin)
	_camera.global_position = player.global_position
	_camera.reset_smoothing()


## Nach dem Wellenende kurz warten (Banner, Pop), dann Spiel anhalten und Kartons/Level-ups/Shop abarbeiten.
func _on_wave_ended(wave_number: int) -> void:
	if wave_number >= wave_manager.get_wave_count():
		return
	GameState.set_phase(GameState.Phase.POST_WAVE)
	await get_tree().create_timer(WAVES.intermission_time).timeout
	if player.is_dead:
		return
	get_tree().paused = true
	GameState.advance_post_wave()


func _on_phase_changed(phase: int) -> void:
	for screen: FlowScreen in [_crate_screen, _level_up_screen, _shop_screen]:
		screen.close()
	match phase:
		GameState.Phase.CRATES:
			_crate_screen.open()
		GameState.Phase.LEVEL_UP:
			_level_up_screen.open()
		GameState.Phase.SHOP:
			_shop_screen.open()
		GameState.Phase.WAVE:
			get_tree().paused = false
			wave_manager.start_next_wave()


func _on_player_died() -> void:
	_pause_menu.enabled = false
	GameState.end_run(false)
	await get_tree().create_timer(WAVES.game_over_delay).timeout
	_game_over.show_result(false, wave_manager.get_wave_number())


func _on_run_won() -> void:
	_pause_menu.enabled = false
	GameState.end_run(true)
	_game_over.show_result(true, wave_manager.get_wave_number())


## Debug (F4): fügt reihum die nächste Waffe aus res://data/weapons hinzu.
func _debug_add_weapon() -> void:
	var weapons: Array[Resource] = DataRegistry.get_all(WEAPON_CATEGORY)
	if weapons.is_empty():
		return
	weapons.sort_custom(func(a: Resource, b: Resource) -> bool: return String((a as WeaponData).id) < String((b as WeaponData).id))
	var data: WeaponData = weapons[_debug_weapon_index % weapons.size()] as WeaponData
	_debug_weapon_index += 1
	player.weapon_slots.add_weapon(data)


## Debug (F6): füllt die Arena bis zum Gegnerlimit (Performance-Test).
func _debug_spawn_enemies() -> void:
	var enemies: Array[Resource] = DataRegistry.get_all(ENEMY_CATEGORY).filter(
		func(r: Resource) -> bool: return (r as EnemyData).despawnable)
	if enemies.is_empty():
		return
	var rng: RandomNumberGenerator = GameState.rng
	for i in WAVES.max_enemies - wave_manager.active_enemy_count():
		var data: EnemyData = enemies[rng.randi_range(0, enemies.size() - 1)] as EnemyData
		wave_manager.spawn_enemy(data, wave_manager.pick_spawn_point())

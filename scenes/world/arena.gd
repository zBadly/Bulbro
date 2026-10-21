class_name Arena
extends Node2D
## Spielszene eines Runs: Arena mit Boden, Rand und Kamera, Spieler, Wellen, HUD und Endbildschirm.

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const WAVES: WaveConfig = preload("res://data/config/wave_config.tres")
const ENEMY_CATEGORY: String = "enemies"
const DROPS: DropConfig = preload("res://data/config/drop_config.tres")
const STRUCTURE_SCENE: PackedScene = preload("res://scenes/structures/structure.tscn")
const ALLY_SCENE: PackedScene = preload("res://scenes/allies/ally.tscn")
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const SPLAT_POOL_SIZE: int = 60
## Wie oft während einer Welle Freischaltbedingungen geprüft werden (Sekunden).
const CHALLENGE_CHECK_INTERVAL: float = 1.0
## Screenshake (Trauma-Modell) und Hit-Stop: reine Effekt-Werte.
const SHAKE_MAX_OFFSET: float = 14.0
const SHAKE_DECAY: float = 1.8
const HIT_STOP_TIME: float = 0.03
const HIT_STOP_SCALE: float = 0.05
const HIT_STOP_COOLDOWN: float = 0.15

@export var config: ArenaConfig

@onready var _floor: Sprite2D = $Floor
@onready var _darkness: CanvasModulate = $Darkness
@onready var _camera: Camera2D = $Camera
@onready var _entities: Node2D = $Entities
@onready var player: Player = $Entities/Player
@onready var wave_manager: WaveManager = $WaveManager
@onready var _drop_manager: DropManager = $DropManager
@onready var _effect_system: EffectSystem = $EffectSystem
@onready var _juice_hooks: JuiceHooks = $JuiceHooks
@onready var _splat_pool: ObjectPool = $Pools/Splats
@onready var _neutral_spawner: NeutralSpawner = $NeutralSpawner
@onready var _hud: Hud = $Hud
@onready var _game_over: GameOverScreen = $GameOver
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _debug_menu: DebugMenu = $DebugMenu
@onready var _crate_screen: CrateScreen = $CrateScreen
@onready var _level_up_screen: LevelUpScreen = $LevelUpScreen
@onready var _shop_screen: ShopScreen = $ShopScreen
@onready var _projectile_pool: ObjectPool = $Pools/PlayerProjectiles
@onready var _damage_number_pool: ObjectPool = $Pools/DamageNumbers
@onready var _enemy_projectile_pool: ObjectPool = $Pools/EnemyProjectiles
@onready var _spawn_marker_pool: ObjectPool = $Pools/SpawnMarkers
@onready var _pickup_pool: ObjectPool = $Pools/Pickups

var _structures: Array[Structure] = []
var _ally_pool: ObjectPool
var _trauma: float = 0.0
var _screenshake: bool = true
var _hit_stop_ready_at: float = 0.0


func _ready() -> void:
	var resume: Dictionary = GameState.resume_data
	GameState.resume_data = {}
	if resume.is_empty():
		GameState.start_run()
	else:
		RunSave.restore_state(resume)
	add_to_group(Fx.JUICE_HOST_GROUP)
	_screenshake = SaveManager.get_option(SaveManager.SCREENSHAKE_KEY, true)
	_splat_pool.container = $Floor
	_splat_pool.prewarm(SPLAT_POOL_SIZE)
	AudioManager.play_music()
	_projectile_pool.prewarm(COMBAT.projectile_pool_size)
	_damage_number_pool.prewarm(COMBAT.damage_number_pool_size)
	_enemy_projectile_pool.prewarm(WAVES.enemy_projectile_pool_size)
	_spawn_marker_pool.prewarm(WAVES.spawn_marker_pool_size)
	_pickup_pool.prewarm(DROPS.pickup_pool_size)
	_ally_pool = ObjectPool.new()
	_ally_pool.name = "Allies"
	_ally_pool.scene = ALLY_SCENE
	_ally_pool.group_name = Pools.ALLIES
	_ally_pool.container = _entities
	$Pools.add_child(_ally_pool)
	_ally_pool.prewarm(STATUS.ally_pool_size)

	var rect: Rect2 = config.get_rect()
	_floor.region_rect = Rect2(Vector2.ZERO, config.size)
	_floor.position = rect.get_center()
	player.arena_bounds = rect
	if resume.is_empty():
		player.apply_character(GameState.character)
		if GameState.starting_weapon != null:
			player.weapon_slots.add_weapon(GameState.starting_weapon)
	else:
		RunSave.apply_to_player(resume, player)

	var lighting: bool = SaveManager.get_option(SaveManager.LIGHTING_KEY, true)
	_darkness.color = config.darkness_color
	_darkness.visible = lighting
	_setup_camera(rect)
	queue_redraw()

	_hud.bind(player, wave_manager)
	player.died.connect(_on_player_died)
	_pause_menu.give_up_requested.connect(player.kill)
	wave_manager.run_won.connect(_on_run_won)
	_game_over.endless_requested.connect(_continue_endless)
	wave_manager.wave_ended.connect(_on_wave_ended)
	wave_manager.wave_started.connect(_on_wave_started)
	Events.run_phase_changed.connect(_on_phase_changed)
	Events.options_changed.connect(_apply_options)
	Events.structure_requested.connect(_build_structure)
	for screen: FlowScreen in [_crate_screen, _level_up_screen, _shop_screen]:
		screen.player = player
	_debug_menu.player = player
	_debug_menu.wave_manager = wave_manager
	_drop_manager.player = player
	_effect_system.player = player
	_juice_hooks.player = player
	_neutral_spawner.wave_manager = wave_manager
	_neutral_spawner.player = player
	_neutral_spawner.container = _entities
	add_child(UnlockToast.new())
	var challenge_timer: Timer = Timer.new()
	challenge_timer.wait_time = CHALLENGE_CHECK_INTERVAL
	challenge_timer.autostart = true
	challenge_timer.timeout.connect(_check_challenges)
	add_child(challenge_timer)
	if resume.is_empty():
		wave_manager.start(player, rect, _entities)
	else:
		wave_manager.resume_at(player, rect, _entities, GameState.current_wave)
		get_tree().paused = true
		GameState.set_phase(GameState.Phase.SHOP)


## Optionen aus dem Pausemenü sofort übernehmen (Licht, Bildschirmwackeln, manuelles Zielen).
func _apply_options() -> void:
	_darkness.visible = SaveManager.get_option(SaveManager.LIGHTING_KEY, true)
	_screenshake = SaveManager.get_option(SaveManager.SCREENSHAKE_KEY, true)
	player.manual_aim = SaveManager.get_option(SaveManager.MANUAL_AIM_KEY, false)


## Freischaltungen während der Welle (z. B. 3 Lampentürme) sofort melden; Siege werden am Run-Ende geprüft.
func _check_challenges() -> void:
	if GameState.phase == GameState.Phase.WAVE and not player.is_dead:
		Unlocks.check(false, false)


func _process(delta: float) -> void:
	_camera.global_position = player.global_position
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - SHAKE_DECAY * delta)
		var strength: float = _trauma * _trauma * SHAKE_MAX_OFFSET
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
	else:
		_camera.offset = Vector2.ZERO


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Bildschirmwackeln: Trauma addiert sich, Ausschlag wächst quadratisch und klingt ab.
func add_trauma(amount: float) -> void:
	if _screenshake:
		_trauma = minf(1.0, _trauma + amount)


## Hit-Stop: Spielzeit für wenige Millisekunden fast anhalten. Mit Abklingzeit, damit Krit-Serien nicht ruckeln.
func hit_stop() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _hit_stop_ready_at or Engine.time_scale < 1.0 or get_tree().paused:
		return
	_hit_stop_ready_at = now + HIT_STOP_COOLDOWN
	Engine.time_scale = HIT_STOP_SCALE
	get_tree().create_timer(HIT_STOP_TIME, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_spawn_enemies"):
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


## Zu Beginn jeder Welle baut jede Waffe mit Struktur (Schraubenzieher) einen Lampenturm in der Nähe.
func _on_wave_started(_wave_number: int) -> void:
	_clear_structures()
	var rng: RandomNumberGenerator = GameState.rng
	for weapon: Weapon in player.weapon_slots.get_weapons():
		if weapon.data.structure == null:
			continue
		var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 1.0) * COMBAT.structure_spawn_radius
		_build_structure(weapon.data.structure, weapon.tier, player.global_position + offset)


## Baut eine Struktur (Waffen zu Wellenbeginn, Effekte über Events.structure_requested).
## Bei `max_count` verschwindet die älteste gleicher Art; nur Türme zählen für die Freischaltungen.
func _build_structure(data: StructureData, tier: int, at: Vector2) -> void:
	_structures = _structures.filter(func(s: Structure) -> bool: return is_instance_valid(s) and not s.is_queued_for_deletion())
	if data.max_count > 0:
		var same: Array[Structure] = _structures.filter(func(s: Structure) -> bool: return s.data == data)
		if same.size() >= data.max_count:
			same[0].queue_free()
			_structures.erase(same[0])
	var area: Rect2 = config.get_rect().grow(-COMBAT.structure_spawn_radius * 0.5)
	var structure: Structure = STRUCTURE_SCENE.instantiate() as Structure
	structure.setup(data, tier, player)
	structure.position = at.clamp(area.position, area.end)
	_entities.add_child.call_deferred(structure)
	_structures.append(structure)
	var turrets: int = _structures.filter(func(s: Structure) -> bool: return s.data.kind == StructureData.Kind.TURRET).size()
	GameState.max_structures = maxi(GameState.max_structures, turrets)


func _clear_structures() -> void:
	for structure: Structure in _structures:
		if is_instance_valid(structure):
			structure.queue_free()
	_structures.clear()


## Nach dem Wellenende kurz warten (Banner, Pop), dann Spiel anhalten und Kartons/Level-ups/Shop abarbeiten.
func _on_wave_ended(wave_number: int) -> void:
	_clear_structures()
	_ally_pool.release_all()
	if wave_number >= wave_manager.get_wave_count() and not GameState.endless:
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
			# Fortsetzen nach Spielabbruch: am Shop-Beginn speichern.
			SaveManager.save_run(RunSave.capture(player))
		GameState.Phase.WAVE:
			get_tree().paused = false
			wave_manager.start_next_wave()


func _on_player_died() -> void:
	_pause_menu.enabled = false
	GameState.end_run(false)
	await get_tree().create_timer(WAVES.game_over_delay).timeout
	_game_over.show_result(false, wave_manager.get_wave_number(), player)


func _on_run_won() -> void:
	_pause_menu.enabled = false
	GameState.end_run(true)
	_game_over.show_result(true, wave_manager.get_wave_number(), player)


## Nach dem Sieg weiterspielen: Kartons, Level-ups und Shop wie gewohnt, dann Endloswellen.
func _continue_endless() -> void:
	GameState.endless = true
	GameState.endless_start_wave = wave_manager.get_wave_count()
	GameState.is_run_active = true
	_pause_menu.enabled = true
	get_tree().paused = true
	GameState.advance_post_wave()


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

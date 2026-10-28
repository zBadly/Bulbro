class_name JuiceHooks
extends Node
## Ereignisbasierte Sounds, Partikel und Bodenflecken (Gegnertod, Funken, Level-up, Boss, Wellenende, Spielerschaden).

const SPLAT_GROUP: StringName = &"pool_splats"
const BOSS_WARNING_COOLDOWN: float = 1.5
const HURT_TRAUMA: float = 0.55
## Endlos-Bosse besiegt: goldener Ring um den Spieler.
const CYCLE_PULSE_RADIUS: float = 260.0
const CYCLE_PULSE_COLOR: Color = Color("#F5A623")
const CYCLE_TRAUMA: float = 0.4
const PHASES: BossPhaseConfig = preload("res://data/config/boss_phase_config.tres")
const HUD: HudConfig = preload("res://data/config/hud_config.tres")

var player: Player:
	set(value):
		player = value
		player.damaged.connect(_on_player_damaged)
		player.lethal_hit_survived.connect(_on_lethal_hit_survived)

var _last_boss_warning: float = -INF


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.spark_collected.connect(_on_spark_collected)
	Events.level_up.connect(_on_level_up)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_phase_changed.connect(_on_boss_phase_changed)
	Events.wave_ended.connect(func(_n: int) -> void: AudioManager.play(&"wave_clear"))
	Events.endless_bosses_defeated.connect(_on_endless_bosses_defeated)


func _on_enemy_killed(data: EnemyData, position: Vector2, _info: DamageInfo) -> void:
	AudioManager.play(&"enemy_death")
	var radius: float = data.collision_radius if data != null else Splat.BASE_RADIUS
	Fx.particles(get_tree(), ParticleFx.Kind.DEATH, position + Vector2(0.0, -radius))
	var pool: ObjectPool = Pools.get_pool(get_tree(), SPLAT_GROUP)
	if pool != null:
		(pool.acquire() as Splat).show_at(position, radius, randf() * TAU)


## Über eine eigene Methode verbunden, damit die Verbindung mit dieser Szene endet (sonst doppelt nach Neustart).
func _on_spark_collected() -> void:
	AudioManager.play_spark()


func _on_level_up(_level: int) -> void:
	if player == null or GameState.phase != GameState.Phase.WAVE:
		return
	AudioManager.play(&"level_up")
	Fx.particles(get_tree(), ParticleFx.Kind.LEVEL_UP, player.get_center())


## Reservebatterie: "Gerettet!" über dem Spieler, Blitz (abgeschwächt bei "Blitzeffekte reduzieren"), Ring und Ton.
func _on_lethal_hit_survived(_origin: StringName) -> void:
	var tree: SceneTree = get_tree()
	Pools.spawn_text(tree, tr("RESCUE_TEXT"), HUD.rescue_text_color, HUD.rescue_text_size, player.get_center())
	Fx.screen_flash(tree)
	Fx.pulse(tree, player.get_center(), HUD.rescue_pulse_radius, HUD.rescue_text_color)
	Fx.shake(tree, HUD.rescue_trauma)
	player.effect_flash()
	AudioManager.play(&"heal")


func _on_boss_spawned(_enemy: Enemy) -> void:
	_play_boss_warning()


## Warnton mit Abklingzeit (Doppelboss und gleichzeitige Phasenwechsel nicht doppelt).
func _play_boss_warning() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_boss_warning >= BOSS_WARNING_COOLDOWN:
		_last_boss_warning = now
		AudioManager.play(&"boss_warning")


## Phasenwechsel: Warnton und Screenshake (Elites schwächer); Fx.shake respektiert die Option "Screenshake".
func _on_boss_phase_changed(enemy: Enemy, _phase_index: int) -> void:
	_play_boss_warning()
	Fx.shake(get_tree(), PHASES.boss_trauma if enemy.data.is_boss else PHASES.elite_trauma)


func _on_endless_bosses_defeated(_cycle: int) -> void:
	if player == null:
		return
	AudioManager.play(&"level_up")
	Fx.particles(get_tree(), ParticleFx.Kind.LEVEL_UP, player.get_center())
	Fx.pulse(get_tree(), player.get_center(), CYCLE_PULSE_RADIUS, CYCLE_PULSE_COLOR)
	Fx.shake(get_tree(), CYCLE_TRAUMA)


func _on_player_damaged(_amount: int) -> void:
	AudioManager.play(&"player_hurt")
	Fx.shake(get_tree(), HURT_TRAUMA)

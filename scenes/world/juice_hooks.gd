class_name JuiceHooks
extends Node
## Ereignisbasierte Sounds, Partikel und Bodenflecken (Gegnertod, Funken, Level-up, Boss, Wellenende, Spielerschaden).

const SPLAT_GROUP: StringName = &"pool_splats"
const BOSS_WARNING_COOLDOWN: float = 1.5
const HURT_TRAUMA: float = 0.55

var player: Player:
	set(value):
		player = value
		player.damaged.connect(_on_player_damaged)

var _last_boss_warning: float = -INF


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.spark_collected.connect(_on_spark_collected)
	Events.level_up.connect(_on_level_up)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.wave_ended.connect(func(_n: int) -> void: AudioManager.play(&"wave_clear"))


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


func _on_boss_spawned(_enemy: Enemy) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_boss_warning >= BOSS_WARNING_COOLDOWN:
		_last_boss_warning = now
		AudioManager.play(&"boss_warning")


func _on_player_damaged(_amount: int) -> void:
	AudioManager.play(&"player_hurt")
	Fx.shake(get_tree(), HURT_TRAUMA)

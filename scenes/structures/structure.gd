class_name Structure
extends Node2D
## Struktur (Lampenturm): schießt auf das nächste Ziel in Reichweite. Schaden skaliert mit Technik,
## nicht mit Schaden-%; Angriffstempo mit dem Struktur-Angriffstempo-Stat. Höheres Tier = schneller.

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const NO_EXCLUDE: Dictionary[int, bool] = {}

var data: StructureData
var tier: int = 1
var player: Player

var _cooldown_left: float = 0.0

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite
@onready var _muzzle: Marker2D = $Muzzle


func setup(p_data: StructureData, p_tier: int, p_player: Player) -> void:
	data = p_data
	tier = p_tier
	player = p_player


func _ready() -> void:
	_sprite.texture = data.texture
	_sprite.offset = Vector2(0.0, -data.texture.get_height() * 0.5)
	_muzzle.position = Vector2(0.0, -data.texture.get_height() * 0.8)
	Juice.spawn_pop(_visual).finished.connect(func() -> void: Juice.idle_bob(_visual), CONNECT_ONE_SHOT)


func get_cooldown() -> float:
	var bonus: float = player.stats.get_stat(Stats.STRUCTURE_ATTACK_SPEED_PCT)
	return CombatMath.attack_cooldown(data.cooldown_for_tier(tier), bonus)


func get_damage() -> int:
	return CombatMath.weapon_damage(data.base_damage, CombatMath.scaling_bonus(data.scalings, player.stats), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if player == null or player.is_dead:
		return
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	if data.kind == StructureData.Kind.ROOT:
		_cooldown_left = STATUS.root_check_interval
		_root_enemies()
		return
	var target: Damageable = Hits.nearest_target(get_tree(), _muzzle.global_position, data.range, NO_EXCLUDE)
	if target == null:
		return
	_cooldown_left = get_cooldown()
	_fire(target)


func _fire(target: Damageable) -> void:
	var pool: ObjectPool = Pools.get_pool(get_tree(), Pools.PLAYER_PROJECTILES)
	if pool == null:
		return
	var spec: ProjectileSpec = ProjectileSpec.new()
	spec.texture = data.projectile_texture
	spec.speed = data.projectile_speed
	spec.max_range = data.range
	spec.info = DamageInfo.create(get_damage(), false, 0.0, self)
	spec.player = player
	spec.lifesteal = false
	var start: Vector2 = _muzzle.global_position
	(pool.acquire() as Projectile).launch(start, start.direction_to(target.get_hit_position()).angle(), spec)


## Ranke: hält alle Gegner im Radius fest (mit Schutzzeit danach, siehe Enemy.root).
func _root_enemies() -> void:
	for target: Damageable in Hits.alive_targets(get_tree()):
		var enemy: Enemy = target as Enemy
		if enemy != null and enemy.global_position.distance_to(global_position) <= data.root_radius:
			enemy.root(data.root_duration)

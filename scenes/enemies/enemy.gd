class_name Enemy
extends Damageable
## Gepoolter Gegner. Werte kommen aus EnemyData, die Bewegung aus einer Verhaltens-Komponente.
## Kontaktschaden per Abstandsprüfung (günstiger als Area2D bei 100 Gegnern).

signal died(enemy: Enemy)

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")

var data: EnemyData
var pool: ObjectPool
var player: Player
var arena_bounds: Rect2 = Rect2()
var rng: RandomNumberGenerator
var wave: int = 1
var max_hp: float = 0.0
var hp: float = 0.0
var damage: float = 0.0
var speed: float = 0.0

var _alive: bool = false
var _behavior: EnemyBehavior
var _contact_distance: float = 0.0

@onready var visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite
@onready var _shape: CollisionShape2D = $CollisionShape


## Einmalig nach dem Erzeugen im Pool: legt Grafik, Kollision und Verhalten fest.
func setup(p_data: EnemyData) -> void:
	data = p_data
	_sprite.texture = data.texture
	var half_height: float = data.texture.get_height() * 0.5
	_sprite.offset = Vector2(0.0, -half_height)
	hit_height = half_height
	_shape.position = Vector2(0.0, -half_height)
	(_shape.shape as CircleShape2D).radius = data.collision_radius
	_behavior = data.behavior.create_behavior()
	_behavior.enemy = self
	add_child(_behavior)


## Beim Holen aus dem Pool: setzt Werte für die Welle und spielt das Pop-in.
func activate(p_wave: int, spawn_position: Vector2, p_player: Player, bounds: Rect2, p_rng: RandomNumberGenerator) -> void:
	wave = p_wave
	player = p_player
	arena_bounds = bounds
	rng = p_rng
	global_position = spawn_position
	max_hp = data.hp_for_wave(wave)
	hp = max_hp
	damage = data.damage_for_wave(wave)
	speed = rng.randf_range(data.speed_min, data.speed_max)
	knockback_velocity = Vector2.ZERO
	_contact_distance = data.collision_radius + player.config.collision_radius
	_sprite.flip_h = false
	visual.rotation = 0.0
	_alive = true
	_behavior.reset()
	Juice.spawn_pop(visual).finished.connect(_on_spawned, CONNECT_ONE_SHOT)


func is_alive() -> bool:
	return _alive


func direction_to_player() -> Vector2:
	return global_position.direction_to(player.global_position)


func distance_to_player() -> float:
	return global_position.distance_to(player.global_position)


func take_damage(info: DamageInfo) -> void:
	if not _alive:
		return
	hp -= info.amount
	Juice.hit_flash(_sprite)
	Pools.spawn_damage_number(get_tree(), info.amount, info.is_crit, get_hit_position())
	apply_knockback(info.knockback_dir * info.knockback * COMBAT.knockback_to_speed * (1.0 - data.knockback_resistance))
	if hp <= 0.0:
		die()


## Tod durch Schaden: Drops auslösen und Tod-Animation abspielen.
func die() -> void:
	if not _alive:
		return
	_alive = false
	Events.enemy_killed.emit(data, global_position)
	died.emit(self)
	Juice.squash_pop(visual).finished.connect(_release, CONNECT_ONE_SHOT)


## Verschwinden ohne Drop: sofort (Gegnerlimit) oder mit Pop-Animation (Wellenende).
func despawn(animated: bool = false) -> void:
	if not _alive:
		return
	_alive = false
	died.emit(self)
	if animated:
		Juice.squash_pop(visual).finished.connect(_release, CONNECT_ONE_SHOT)
	else:
		_release()


func fire_projectile(direction: Vector2, projectile_speed: float, projectile_range: float, texture: Texture2D) -> void:
	var projectile_pool: ObjectPool = Pools.get_pool(get_tree(), Pools.ENEMY_PROJECTILES)
	if projectile_pool == null:
		return
	var projectile: EnemyProjectile = projectile_pool.acquire() as EnemyProjectile
	projectile.launch(get_hit_position(), direction, projectile_speed, projectile_range, damage, texture)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var move: Vector2 = _behavior.get_velocity(delta)
	velocity = move + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, COMBAT.knockback_friction * delta)
	global_position += velocity * delta
	if arena_bounds.has_area():
		var margin: Vector2 = Vector2.ONE * data.collision_radius
		global_position = global_position.clamp(arena_bounds.position + margin, arena_bounds.end - margin)
	if absf(move.x) > 0.0:
		_sprite.flip_h = move.x < 0.0
	Juice.walk_tilt(visual, move)
	if not player.is_dead and global_position.distance_to(player.global_position) < _contact_distance:
		player.take_hit(damage)


func _on_spawned() -> void:
	if _alive:
		Juice.idle_bob(visual)


func _release() -> void:
	if pool != null:
		pool.release(self)
	else:
		queue_free()

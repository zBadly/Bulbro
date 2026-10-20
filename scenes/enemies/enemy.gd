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
var _last_hit: DamageInfo
var _burn_damage: float = 0.0
var _burn_ticks_left: int = 0
var _burn_timer: float = 0.0
var _burn_source: Player

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
	_last_hit = null
	_burn_ticks_left = 0
	_sprite.modulate = Color.WHITE
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
	_last_hit = info
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
	Events.enemy_killed.emit(data, global_position, _last_hit)
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


## Überspannung: Brandschaden über Zeit. Ein stärkerer oder längerer Brand ersetzt den alten.
func apply_burn(damage_per_tick: float, ticks: int, source: Player) -> void:
	if not _alive or ticks <= 0:
		return
	_burn_damage = maxf(_burn_damage if _burn_ticks_left > 0 else 0.0, damage_per_tick)
	_burn_ticks_left = maxi(_burn_ticks_left, ticks)
	_burn_source = source
	_sprite.modulate = COMBAT.burn_tint


func is_burning() -> bool:
	return _burn_ticks_left > 0


func _update_burn(delta: float) -> void:
	if _burn_ticks_left <= 0:
		return
	var speed_pct: float = _burn_source.stats.get_stat(Stats.BURN_SPEED_PCT) if is_instance_valid(_burn_source) else 0.0
	_burn_timer += delta * maxf(0.1, 1.0 + speed_pct / CombatMath.PERCENT)
	if _burn_timer < COMBAT.burn_interval:
		return
	_burn_timer -= COMBAT.burn_interval
	_burn_ticks_left -= 1
	if _burn_ticks_left <= 0:
		_sprite.modulate = Color.WHITE
	_spread_burn()
	take_damage(DamageInfo.create(maxi(CombatMath.MIN_DAMAGE, roundi(_burn_damage)), false, 0.0, null))


## Brandausbreitung: so viele nahe, nicht brennende Gegner wie der Stat burn_spread angibt.
func _spread_burn() -> void:
	if not is_instance_valid(_burn_source):
		return
	var spread: int = roundi(_burn_source.stats.get_stat(Stats.BURN_SPREAD))
	if spread <= 0:
		return
	for target: Damageable in Hits.alive_targets(get_tree()):
		if spread <= 0:
			break
		var other: Enemy = target as Enemy
		if other == null or other == self or other.is_burning():
			continue
		if other.global_position.distance_to(global_position) <= COMBAT.burn_spread_radius:
			other.apply_burn(_burn_damage, _burn_ticks_left + 1, _burn_source)
			spread -= 1


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_update_burn(delta)
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

class_name OrbitShooterBehavior
extends EnemyBehavior
## Rußschütze: kreist um den Spieler und schießt aus kurzer Distanz.

var config: OrbitShooterData

var _angle: float = 0.0
var _direction: float = 1.0
var _fire_timer: float = 0.0


func reset() -> void:
	_angle = enemy.player.global_position.direction_to(enemy.global_position).angle()
	_direction = 1.0 if enemy.rng.randf() < 0.5 else -1.0
	_fire_timer = enemy.rng.randf_range(config.fire_interval_min, config.fire_interval_max)


func get_velocity(delta: float) -> Vector2:
	_fire_timer -= delta
	if _fire_timer <= 0.0 and enemy.distance_to_player() <= config.projectile_range:
		_fire_timer = enemy.rng.randf_range(config.fire_interval_min, config.fire_interval_max)
		enemy.fire_projectile(enemy.direction_to_player(), config.projectile_speed, config.projectile_range, config.projectile_texture)
	_angle += _direction * enemy.speed / config.orbit_radius * delta
	var target: Vector2 = enemy.player.global_position + Vector2.from_angle(_angle) * config.orbit_radius
	var to_target: Vector2 = target - enemy.global_position
	return to_target.normalized() * minf(enemy.speed, to_target.length() / maxf(delta, 0.0001))

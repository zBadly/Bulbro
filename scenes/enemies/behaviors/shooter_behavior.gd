class_name ShooterBehavior
extends EnemyBehavior
## Hält eine Wunschdistanz zum Spieler und feuert in zufälligen Abständen.

var config: ShooterData

var _fire_timer: float = 0.0


func reset() -> void:
	_fire_timer = enemy.rng.randf_range(config.fire_interval_min, config.fire_interval_max)


func get_velocity(delta: float) -> Vector2:
	var distance: float = enemy.distance_to_player()
	_fire_timer -= delta
	if _fire_timer <= 0.0 and distance <= config.projectile_range:
		_fire_timer = enemy.rng.randf_range(config.fire_interval_min, config.fire_interval_max)
		enemy.fire_projectile(enemy.direction_to_player(), config.projectile_speed, config.projectile_range, config.projectile_texture)

	if distance > config.preferred_distance + config.distance_tolerance:
		return enemy.direction_to_player() * enemy.speed
	if distance < config.preferred_distance - config.distance_tolerance:
		return -enemy.direction_to_player() * enemy.speed
	return Vector2.ZERO

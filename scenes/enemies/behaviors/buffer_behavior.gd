class_name BufferBehavior
extends EnemyBehavior
## Verstärker: hält Abstand und verstärkt regelmäßig den nächsten nicht verstärkten Gegner.

var config: BufferData

var _timer: float = 0.0


func reset() -> void:
	_timer = config.buff_interval


func get_velocity(delta: float) -> Vector2:
	_timer -= delta
	if _timer <= 0.0:
		_timer = config.buff_interval
		_buff_nearest()
	if enemy.distance_to_player() < config.keep_distance:
		return -enemy.direction_to_player() * enemy.speed
	return Vector2.ZERO


func _buff_nearest() -> void:
	var best: Enemy = null
	var best_dist: float = config.buff_radius
	for target: Damageable in Hits.alive_targets(enemy.get_tree()):
		var other: Enemy = target as Enemy
		if other == null or other == enemy or other.is_buffed or other.data.is_boss or other.data.is_elite:
			continue
		var dist: float = other.global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best = other
			best_dist = dist
	if best != null:
		Fx.lightning(enemy.get_tree(), enemy.get_hit_position(), best.get_hit_position())
		best.apply_buff(config.hp_multiplier, config.damage_multiplier, config.speed_multiplier)

class_name AccelerateBehavior
extends EnemyBehavior
## Hetzer: verfolgt den Spieler und wird jede Sekunde schneller (bis zum Maximum).

var config: AccelerateData

var _speed: float = 0.0


func reset() -> void:
	_speed = config.start_speed


func get_velocity(delta: float) -> Vector2:
	_speed = minf(config.max_speed, _speed + config.acceleration * delta)
	return enemy.direction_to_player() * _speed * enemy.speed_factor

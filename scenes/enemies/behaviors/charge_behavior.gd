class_name ChargeBehavior
extends EnemyBehavior
## Verfolgen -> Ausholen -> Sprint geradeaus -> Verfolgen.

enum State { CHASE, WINDUP, CHARGE }

var config: ChargeData

var _state: State = State.CHASE
var _timer: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO


func reset() -> void:
	_enter_chase()


func get_velocity(delta: float) -> Vector2:
	_timer -= delta
	match _state:
		State.CHASE:
			if _timer <= 0.0:
				_state = State.WINDUP
				_timer = config.windup_time
				Juice.telegraph(enemy.visual, config.windup_time)
			return enemy.direction_to_player() * enemy.speed
		State.WINDUP:
			if _timer <= 0.0:
				_state = State.CHARGE
				_timer = config.charge_time
				_charge_direction = enemy.direction_to_player()
			return Vector2.ZERO
		_:
			if _timer <= 0.0:
				_enter_chase()
			return _charge_direction * config.charge_speed


func _enter_chase() -> void:
	_state = State.CHASE
	_timer = enemy.rng.randf_range(config.interval_min, config.interval_max)

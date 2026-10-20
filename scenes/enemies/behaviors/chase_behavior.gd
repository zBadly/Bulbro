class_name ChaseBehavior
extends EnemyBehavior

var config: ChaseData


func get_velocity(_delta: float) -> Vector2:
	return enemy.direction_to_player() * enemy.speed

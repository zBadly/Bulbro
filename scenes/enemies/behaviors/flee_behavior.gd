class_name FleeBehavior
extends EnemyBehavior
## Läuft vom Spieler weg. Nahe am Rand wird die Fluchtrichtung entlang der Wand umgelenkt.

var config: FleeData


func get_velocity(_delta: float) -> Vector2:
	var away: Vector2 = -enemy.direction_to_player()
	var bounds: Rect2 = enemy.arena_bounds
	if bounds.has_area():
		var margin: float = enemy.data.collision_radius * 2.0
		var pos: Vector2 = enemy.global_position
		if (pos.x < bounds.position.x + margin and away.x < 0.0) or (pos.x > bounds.end.x - margin and away.x > 0.0):
			away.x = 0.0
		if (pos.y < bounds.position.y + margin and away.y < 0.0) or (pos.y > bounds.end.y - margin and away.y > 0.0):
			away.y = 0.0
		if away.is_zero_approx():
			away = enemy.direction_to_player().orthogonal()
	var factor: float = config.calm_speed_factor if enemy.distance_to_player() > config.calm_distance else 1.0
	return away.normalized() * enemy.speed * factor

class_name HealerBehavior
extends EnemyBehavior
## Flackerer: Abstand zum Spieler halten, bei Verbündeten bleiben, regelmäßig Gegner im Umkreis heilen.

const HEAL_COLOR: Color = Color("#7ED957")

var config: HealerData

var _timer: float = 0.0


func reset() -> void:
	_timer = config.heal_interval


func get_velocity(delta: float) -> Vector2:
	_timer -= delta
	if _timer <= 0.0:
		_timer = config.heal_interval
		_heal_allies()
	if enemy.distance_to_player() < config.keep_distance:
		return -enemy.direction_to_player() * enemy.speed
	var ally: Enemy = enemy.nearest_ally()
	if ally != null and ally.global_position.distance_to(enemy.global_position) > config.heal_radius * 0.5:
		return enemy.global_position.direction_to(ally.global_position) * enemy.speed
	return Vector2.ZERO


func _heal_allies() -> void:
	var healed: bool = false
	for target: Damageable in Hits.alive_targets(enemy.get_tree()):
		var other: Enemy = target as Enemy
		if other == null or other == enemy or other.global_position.distance_to(enemy.global_position) > config.heal_radius:
			continue
		if other.hp < other.max_hp:
			other.heal(other.max_hp * config.heal_pct / CombatMath.PERCENT)
			healed = true
	if healed:
		Fx.pulse(enemy.get_tree(), enemy.get_hit_position(), config.heal_radius, HEAL_COLOR)
